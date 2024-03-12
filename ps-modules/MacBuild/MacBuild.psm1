function Update-LibsToRelativePaths {
   param(
      [string]$arm64LibDir,
      [string]$x64LibDir
   )
   ConvertTo-RelativeInstallPaths -directory $arm64LibDir -extension "a"
   ConvertTo-RelativeInstallPaths -directory $arm64LibDir -extension "dylib"
   ConvertTo-RelativeInstallPaths -directory $x64LibDir -extension "a"
   ConvertTo-RelativeInstallPaths -directory $x64LibDir -extension "dylib"
}

function Create-UniversalBinaries {
   param(
      [string]$arm64LibDir,
      [string]$x64LibDir,
      [string]$universalLibDir
   )
   New-Item -Path "$universalLibDir" -ItemType Directory -Force | Out-Null
   Write-Message "Creating universal bins: $arm64LibDir..."
   $items = Get-ChildItem -Path "$arm64LibDir/*" -Include "*.dylib","*.a"
   foreach($item in $items) {
       $fileName = $item.Name
       Write-Message "> $fileName"
       $srcPathArm64 = $item.FullName
       $srcPathX64 = (Join-Path $x64LibDir $fileName)
       $destPath = (Join-Path $universalLibDir $fileName)
       
       if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
           Invoke-Expression -Command "cp -R `"$srcPathArm64`" `"$destPath`""
       }
       elseif (-not $item.PSIsContainer) {
           Invoke-Expression -Command "lipo -create -output `"$destPath`" `"$srcPathArm64`" `"$srcPathX64`""
       }
   }
}

function Copy-NonLibraryFiles {
   param(
      [string]$srcDir,
      [string]$destDir
   )
   Write-Message "Copying non-library files: $srcDir ==> $destDir..."
   $srcDir = (Convert-Path -LiteralPath $srcDir)
   $destDir = (Convert-Path -LiteralPath $destDir)

   Get-ChildItem -Path $srcDir -Recurse | Where-Object { $_.Extension -notin ('.dylib', '.a') } | ForEach-Object {
   $destinationPath = Join-Path -Path $destDir -ChildPath $_.FullName.Substring($srcDir.Length)
      Copy-Item -Path $_.FullName -Destination $destinationPath
   }
}

function Create-FinalizedMacArtifacts {
    param (
        [string]$arm64LibDir,
        [string]$x64LibDir,
        [string]$universalLibDir
    )
    Write-Banner -Level 3 -Title "Finalizing Mac artifacts"
    Write-Message "arm64LibDir: $arm64LibDir"
    Update-LibsToRelativePaths -arm64LibDir $arm64LibDir -x64LibDir $x64LibDir
    Create-UniversalBinaries -arm64LibDir $arm64LibDir -x64LibDir $x64LibDir -universalLibDir $universalLibDir
    Copy-NonLibraryFiles -srcDir $arm64LibDir -destDir $universalLibDir
    Remove-Item -Force -Recurse -Path $arm64LibDir
    Remove-Item -Force -Recurse -Path $x64LibDir
}

function Update-LibraryPath {
    param (
        [string]$libPath
    )

    if (-not (Test-Path $libPath -PathType Leaf)) {
        return
    }

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

        if ([System.IO.Path]::GetFileName($path) -eq $dylibName) {
            $changeCmd = "install_name_tool -id $newPath $libPath"
        }
        else {
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
        Set-ItemProperty -Path $filePath -Name IsReadOnly -Value $false
        Update-LibraryPath -libPath $filePath
    }
}

function Debug-WriteLibraryDependencies {
   param(
      [PSObject]$files
   )
   if (-not $global:showDebug) {
      return
   }

   foreach($mainFile in $mainFiles) {
      Write-Message "> $mainFile"
      Invoke-Expression "otool -L '$mainFile' | grep '@rpath'"
   }
}

function Remove-DylibSymlinks {
    param (
        [Parameter(Mandatory=$true)][string]$BuildArtifactsPath
    )

    Write-Message "Consolidating libraries and symlinks..."
    Push-Location "$BuildArtifactsPath/lib"

    # Enumerate files
    $mainFiles = @()
    $filesWithVersions = @()
    $dylibFiles = Get-ChildItem -Path . -Filter "*.dylib"
    foreach ($dylibFile in $dylibFiles) {
        # Check if the file name contains more than one dot
        if (-not ($dylibFile.Name -match '\..*\..*')) {
            $mainFiles += $dylibFile.Name
        }
        else {
            $filesWithVersions += $dylibFile.Name
        }
    }

    Debug-WriteLibraryDependencies $mainFiles

    $baseFilenameStartPattern = '[^a-zA-Z0-9-_]'
    foreach ($mainFile in $mainFiles) {
        # Main file
        Invoke-Expression "install_name_tool -id '@rpath/$mainFile' '$mainFile'"

        # All other files that might point to it
        foreach ($possibleDependency in $filesWithVersions) {
            $baseFilename = ($possibleDependency -split $baseFilenameStartPattern)[0]
            $newDependency = "$baseFilename.dylib"
            if ($mainFiles -contains $newDependency) {
                Invoke-Expression "install_name_tool -change '@rpath/$possibleDependency' '@rpath/$newDependency' '$mainFile'"
            }
        }
    }

    Debug-WriteLibraryDependencies $mainFiles

    $files = Get-ChildItem -File -Recurse
    foreach ($file in $files) {
        if ($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Remove-Item $file.FullName
        }
    }

    # Rename files to the "main" filename we want
    $files = Get-ChildItem -File -Recurse
    foreach ($file in $files) {
        $oldFilename = $file.Name
        $baseFilename = ($oldFilename -split $baseFilenameStartPattern)[0]
        $newFilename = "$baseFilename" + [System.IO.Path]::GetExtension($file)
        Move-Item -Path $file.Name -Destination $newFilename
    }

    Pop-Location
}

Export-ModuleMember -Function Create-FinalizedMacArtifacts, Remove-DylibSymlinks
