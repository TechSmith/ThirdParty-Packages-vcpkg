Import-Module "$PSScriptRoot/../../ps-modules/Util"

function ConvertTo-RelativeInstallPaths([string]$directory, [string]$extension) {
    Get-ChildItem -Path $directory -Filter "*.$extension" | ForEach-Object {
        $filePath = $_.FullName
        $fileName = $_.Name
        Write-Host "> Processing: $fileName"
        Set-ItemProperty -Path $filePath -Name IsReadOnly -Value $false
        & python3 makeInstallPathsRelative.py @rpath $filePath
    }
}

function ConvertTo-UniversalBinaries([string]$arm64Dir, [string]$x64Dir, [string]$universalDir) {
    Write-Host "Creating universal dir and copying headers..."
    if (Test-Path -Path $universalDir -PathType Container) {
       Remove-Item -Path "$universalDir" -Recurse -Force | Out-Null
    }
    New-Item -Path "$universalDir" -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$x64Dir\include" -Destination "$universalDir\include" -Recurse | Out-Null # Assume arm64 and x86_64 are identical

    Write-Host "Making install paths relative..."
    ConvertTo-RelativeInstallPaths "$arm64Dir" "a"
    ConvertTo-RelativeInstallPaths "$arm64Dir" "dylib"
    ConvertTo-RelativeInstallPaths "$x64Dir" "a"
    ConvertTo-RelativeInstallPaths "$x64Dir" "dylib"

    Write-Host "Making binaries universal..."
    $ARM64_LIB_DIR = Join-Path $arm64Dir "lib"
    $X64_LIB_DIR = Join-Path $x64Dir "lib"
    $UNIVERSAL_LIB_DIR = Join-Path $universalDir "lib"
    New-Item -Path "$UNIVERSAL_LIB_DIR" -ItemType Directory -Force | Out-Null

    Write-Host "Looking in: $ARM64_LIB_DIR"
    Get-ChildItem -Path "$ARM64_LIB_DIR\*.*" -Include *.a, *.dylib | ForEach-Object {
        $item = $_
        $fileName = $item.Name
        $srcPathArm64 = $item.FullName
        $srcPathX64 = (Join-Path $X64_LIB_DIR $fileName)
        $destPath = (Join-Path $UNIVERSAL_LIB_DIR $fileName)
        
        Write-Host "destPath: $destPath, srcPathArm64: $srcPathArm64, srcPathX64: $srcPathX64"

        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Host "> Processing: $fileName - Copying symlink"
            #Copy-Item -LiteralPath $srcPathArm64 -Destination $destPath -Force -Recurse
            Invoke-Expression -Command "cp -R `"$srcPathArm64`" `"$destPath`""
        }
        elseif (-not $item.PSIsContainer) {
            Write-Host "> Processing: $filename - Running lipo"
            Invoke-Expression -Command "lipo -create -output `"$destPath`" `"$srcPathArm64`" `"$srcPathX64`""
        }
    }
}

function Update-LibraryPath {
    param (
        [string]$newPathSubStr,
        [string]$libPath
    )

    Write-Host "Updating library path for: $libPath..."
    if (-not (Test-Path $libPath -PathType Leaf)) {
        Write-Host "> File '$libPath' does not exist."
        return
    }

    $otoolCmd = "otool -L $libPath"
    $p = Invoke-Expression -Command $otoolCmd

    Process-OtoolOutput -Output $p -NewPathSubStr $newPathSubStr -StaticLibPath $libPath

    Write-Host "********** FINAL RESULT*************"
    Invoke-Expression -Command $otoolCmd
}

function Process-OtoolOutput {
    param (
        [string]$Output,
        [string]$NewPathSubStr,
        [string]$StaticLibPath
    )

    $lines = $Output.Split([Environment]::NewLine)

    foreach ($line in $lines) {
        if (-not $line.StartsWith("	")) {
            continue
        }

        $path = $line.Substring(1, $line.IndexOf('(') - 1).Trim()
        $dirname = [System.IO.Path]::GetDirectoryName($path)

        if ($dirname -match "/usr/lib" -or $dirname -match "/System") {
            continue
        }

        $oldPathLoc = $path.IndexOf($dirname)

        if ($oldPathLoc -eq -1) {
            continue
        }

        $newPath = $path.Replace($dirname, $NewPathSubStr)
        $dylibName = [System.IO.Path]::GetFileName($StaticLibPath)

        Write-Host ($path + "-" + $dylibName)

        if ([System.IO.Path]::GetFileName($path) -eq $dylibName) {
            Write-Host "CHANGING ID"
            $changeCmd = "install_name_tool -id $newPath $StaticLibPath"
        }
        else {
            Write-Host "CHANGING PATH"
            $changeCmd = "install_name_tool -change $path $newPath $StaticLibPath"
        }

        Invoke-Expression -Command $changeCmd
    }
}

Function Remove-DylibSymlinks {
    param (
        [Parameter(Mandatory=$true)][string]$BuildArtifactsPath
    )

    Push-Location "$BuildArtifactsPath/lib"

    # Enumerate files
    $main_files = @()
    $files_with_versions = @()
    $dylib_files = Get-ChildItem -Path . -Filter "*.dylib"
    foreach ($dylib_file in $dylib_files) {
        # Check if the file name contains more than one dot
        if (-not ($dylib_file.Name -match '\..*\..*')) {
            $main_files += $dylib_file.Name
        }
        else {
            $files_with_versions += $dylib_file.Name
        }
    }

    Write-Host ""
    Write-Host ""
    Write-Host "Dynamic library dependencies before changes..."
    foreach($main_file in $main_files) {
        Write-Host "> $main_file"
        Invoke-Expression "otool -L '$main_file' | grep '@rpath'"
    }

    Write-Host ""
    Write-Host ""
    Write-Host "Updating paths to dynamic dependencies..."
    foreach ($main_file in $main_files) {
        # Main file
        Write-Host ("> $main_file")
        Invoke-Expression "install_name_tool -id '@rpath/$main_file' '$main_file'"

        # All other files that might point to it
        foreach ($possible_current_dependency in $files_with_versions) {
            $base_filename = ($possible_current_dependency -split '[^a-zA-Z0-9]')[0] # Discard anything after the first non-alphanumeric character
            $new_dependency = "$base_filename.dylib"
            if ($main_files -contains $new_dependency) {
                Invoke-Expression "install_name_tool -change '@rpath/$possible_current_dependency' '@rpath/$new_dependency' '$main_file'"
            } else {
                Write-Host (">> Matching main file not found for: $possible_current_dependency!!!")
            }
        }
    }

    Write-Host ""
    Write-Host ""
    Write-Host "Dynamic library dependenies after changes..."
    foreach($main_file in $main_files) {
        Write-Host "> $main_file"
        Invoke-Expression "otool -L '$main_file' | grep '@rpath'"
    }

    Write-Host ""
    Write-Host ""
    Write-Host "Removing unused symlinks..."
    $files = Get-ChildItem -File -Recurse
    foreach ($file in $files) {
        if ($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Host "Removing symlink: $($file.FullName)"
            Remove-Item $file.FullName
        }
    }

    # Rename files to the "main" filename we want
    Write-Host ""
    Write-Host ""
    Write-Host "Renaming files..."
    $files = Get-ChildItem -File -Recurse
    foreach ($file in $files) {
        $old_filename = $file.Name
        $base_filename = ($old_filename -split '[^a-zA-Z0-9]')[0] # Discard anything after the first non-alphanumeric character
        $new_filename = "$base_filename" + [System.IO.Path]::GetExtension($file)
        Write-Host "$old_filename ==> $new_filename"
        Move-Item -Path $file.Name -Destination $new_filename
    }

    Pop-Location


}

Export-ModuleMember -Function ConvertTo-UniversalBinaries
Export-ModuleMember -Function Update-LibraryPath
Export-ModuleMember -Function Remove-DylibSymlinks
