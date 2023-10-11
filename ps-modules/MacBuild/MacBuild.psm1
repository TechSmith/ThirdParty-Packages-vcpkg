function ConvertTo-UniversalBinaries {
    param (
        [string]$arm64Dir,
        [string]$x64Dir,
        [string]$universalDir
    )

    Write-Message "Creating universal dir and copying headers..."
    if (Test-Path -Path $universalDir -PathType Container) {
       Remove-Item -Path "$universalDir" -Recurse -Force | Out-Null
    }
    New-Item -Path "$universalDir" -ItemType Directory -Force | Out-Null
    $arm64LibDir = Join-Path $arm64Dir "lib"
    $x64LibDir = Join-Path $x64Dir "lib"
    Copy-Item -Path "$x64Dir\include" -Destination "$universalDir\include" -Recurse | Out-Null # Assume arm64 and x86_64 are identical

    Write-Message "Making install paths relative..."
    ConvertTo-RelativeInstallPaths -directory $arm64LibDir -extension "a"
    ConvertTo-RelativeInstallPaths -directory $arm64LibDir -extension "dylib"
    ConvertTo-RelativeInstallPaths -directory $x64LibDir -extension "a"
    ConvertTo-RelativeInstallPaths -directory $x64LibDir -extension "dylib"

    Write-Message "Making binaries universal..."
    $universalLibDir = Join-Path $universalDir "lib"
    New-Item -Path "$universalLibDir" -ItemType Directory -Force | Out-Null

    Write-Message "Looking in: $arm64LibDir"
    $items = Get-ChildItem -Path "$arm64LibDir/*" -Include "*.dylib","*.a"
    foreach($item in $items) {
        $fileName = $item.Name
        $srcPathArm64 = $item.FullName
        $srcPathX64 = (Join-Path $x64LibDir $fileName)
        $destPath = (Join-Path $universalLibDir $fileName)
        
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Message "> Processing: $fileName - Copying symlink"
            #Copy-Item -LiteralPath $srcPathArm64 -Destination $destPath -Force -Recurse
            Invoke-Expression -Command "cp -R `"$srcPathArm64`" `"$destPath`""
        }
        elseif (-not $item.PSIsContainer) {
            Write-Message "> Processing: $filename - Running lipo"
            Invoke-Expression -Command "lipo -create -output `"$destPath`" `"$srcPathArm64`" `"$srcPathX64`""
        }
    }
}

function Update-LibraryPath {
    param (
        [string]$libPath
    )

    Write-Message ">> Update-LibraryPath..."

    if (-not (Test-Path $libPath -PathType Leaf)) {
        Write-Message ">> File '$libPath' does not exist."
        return
    }

    Write-Message ">> Updating library path for: $libPath..."
    $otoolCmd = "otool -L $libPath"
    $otoolOutput = Invoke-Expression -Command $otoolCmd
    $lines = $otoolOutput.Split([Environment]::NewLine)
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

        $newPath = $path.Replace($dirname, "@rpath")
        $dylibName = [System.IO.Path]::GetFileName($libPath)

        Write-Message ($path + "-" + $dylibName)

        if ([System.IO.Path]::GetFileName($path) -eq $dylibName) {
            Write-Message ">>> Changing ID"
            $changeCmd = "install_name_tool -id $newPath $libPath"
        }
        else {
            Write-Message ">>> Changing path"
            $changeCmd = "install_name_tool -change $path $newPath $libPath"
        }

        Invoke-Expression -Command $changeCmd
    }
}

function ConvertTo-RelativeInstallPaths {
    param (
        [string]$directory,
        [string]$extension
    )

    $libFiles = Get-ChildItem -Path $directory -Filter "*.$extension"
    foreach ($libFile in $libFiles) {
        $filePath = $libFile.FullName
        $fileName = $libFile.Name
        Write-Message ">> Processing: $fileName"
        Set-ItemProperty -Path $filePath -Name IsReadOnly -Value $false
        Update-LibraryPath -libPath $filePath
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

    Write-Message "$(NL)Dynamic library dependencies before changes..."
    foreach($main_file in $main_files) {
        Write-Message "> $main_file"
        Invoke-Expression "otool -L '$main_file' | grep '@rpath'"
    }

    Write-Message "$(NL)Updating paths to dynamic dependencies..."
    foreach ($main_file in $main_files) {
        # Main file
        Write-Message ("> $main_file")
        Invoke-Expression "install_name_tool -id '@rpath/$main_file' '$main_file'"

        # All other files that might point to it
        foreach ($possible_current_dependency in $files_with_versions) {
            $base_filename = ($possible_current_dependency -split '[^a-zA-Z0-9]')[0] # Discard anything after the first non-alphanumeric character
            $new_dependency = "$base_filename.dylib"
            if ($main_files -contains $new_dependency) {
                Invoke-Expression "install_name_tool -change '@rpath/$possible_current_dependency' '@rpath/$new_dependency' '$main_file'"
            } else {
                Write-Message (">> Matching main file not found for: $possible_current_dependency!!!")
            }
        }
    }

    Write-Message "$(NL)Dynamic library dependenies after changes..."
    foreach($main_file in $main_files) {
        Write-Message "> $main_file"
        Invoke-Expression "otool -L '$main_file' | grep '@rpath'"
    }

    Write-Message "$(NL)Removing unused symlinks..."
    $files = Get-ChildItem -File -Recurse
    foreach ($file in $files) {
        if ($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Message "Removing symlink: $($file.FullName)"
            Remove-Item $file.FullName
        }
    }

    # Rename files to the "main" filename we want
    Write-Message "$(NL)Renaming files..."
    $files = Get-ChildItem -File -Recurse
    foreach ($file in $files) {
        $old_filename = $file.Name
        $base_filename = ($old_filename -split '[^a-zA-Z0-9]')[0] # Discard anything after the first non-alphanumeric character
        $new_filename = "$base_filename" + [System.IO.Path]::GetExtension($file)
        Write-Message "$old_filename ==> $new_filename"
        Move-Item -Path $file.Name -Destination $new_filename
    }

    Pop-Location
}

Export-ModuleMember -Function ConvertTo-UniversalBinaries
Export-ModuleMember -Function Remove-DylibSymlinks
