function Make-InstallPathsRelative([string]$directory, [string]$extension) {
    Get-ChildItem -Path $directory -Filter "*.$extension" | ForEach-Object {
        $filePath = $_.FullName
        $fileName = $_.Name
        Write-Host "> Processing: $fileName"
        Set-ItemProperty -Path $filePath -Name IsReadOnly -Value $false
        & python3 makeInstallPathsRelative.py @rpath $filePath
    }
}

function ConvertTo-UniversalBinaries([string]$arm64Dir, [string]$x86_64Dir, [string]$universalDir) {
    Write-Host "Creating universal dir and copying headers..."
    if (Test-Path -Path $universalDir -PathType Container) {
       Remove-Item -Path "$universalDir" -Recurse -Force | Out-Null
    }
    New-Item -Path "$universalDir" -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$x86_64Dir\include" -Destination "$universalDir\include" -Recurse | Out-Null # Assume arm64 and x86_64 are identical

    Write-Host "Making install paths relative..."
    Make-InstallPathsRelative "$arm64Dir" "a"
    Make-InstallPathsRelative "$arm64Dir" "dylib"
    Make-InstallPathsRelative "$x86_64Dir" "a"
    Make-InstallPathsRelative "$x86_64Dir" "dylib"

    Write-Host "Making binaries universal..."
    $ARM64_LIB_DIR = Join-Path $arm64Dir "lib"
    $X86_64_LIB_DIR = Join-Path $x86_64Dir "lib"
    $UNIVERSAL_LIB_DIR = Join-Path $universalDir "lib"
    Get-ChildItem -Path $ARM64_LIB_DIR -Include *.a, *.dylib | ForEach-Object {
        $filePath = $_.FullName
        $fileName = $_.Name
        Write-Host "> Processing: $fileName"
        if (Test-Path -PathType Container -Path $filePath) {
            Write-Host ">> Skipping directory"
        } elseif (Test-Path -PathType SymbolicLink -Path $filePath) {
            Write-Host ">> Copying symlink"
            Copy-Item -Path $filePath -Destination (Join-Path $UNIVERSAL_LIB_DIR $fileName) -Force
        } else {
            Write-Host ">> Running lipo"
            lipo -create -output (Join-Path $UNIVERSAL_LIB_DIR $fileName) (Join-Path $ARM64_LIB_DIR $fileName) (Join-Path $X86_64_LIB_DIR $fileName)
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

# Export public functions to make them accessible to other scripts
Export-ModuleMember -Function ConvertTo-UniversalBinaries
Export-ModuleMember -Function Update-LibraryPath
