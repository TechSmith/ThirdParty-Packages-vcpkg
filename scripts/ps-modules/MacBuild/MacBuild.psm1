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

function Create-FinalizedMacBuildArtifacts {
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
    Remove-DylibSymlinks -libDir $universalLibDir
    Run-CreateDysmAndStripDebugSymbols -libDir $universalLibDir
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

function Get-FilesAndSymlinks {
    param (
        [Parameter(Mandatory=$true)][array]$files
    )

    $filesInDir = @()
    $symlinksInDir = @()
    # Separate symlinks from physical files
    foreach($file in $files) {
        if($file.Attributes -eq 'ReparsePoint') {
            $symlinksInDir += $file
        }
        else {
            $filesInDir += $file
        }
    }

    # Populate map with physical files
    $fileAndSymlinkInfo = @()
    foreach($file in $filesInDir) {
        $fileAndSymlinkInfo += @{
            Filename = $file
            Symlinks = $null
            NewFilename = $file
        }
    }

    # Find all symlinks for each physical file
    foreach($item in $fileAndSymlinkInfo)
    {
        $symlinks = @()
        foreach($symlink in $symlinksInDir) {
            $physicalFile = Resolve-Symlink -path $symlink
            if($physicalFile -eq $item.Filename) {
                $symlinks += $symlink
            }
        }
        $item.Symlinks = $symlinks
    }

    # Choose the shortest name for each set to be the new filename
    foreach($item in $fileAndSymlinkInfo)
    {
        $possibleFilenames = @()
        if($null -ne $item.Symlinks) {
            $possibleFilenames += $item.Symlinks
        }
        $possibleFilenames += $item.Filename
        $item.NewFilename = ($possibleFilenames | Sort-Object { (Split-Path $_ -Leaf).Length })[0]
    }

    return $fileAndSymlinkInfo
}

function Remove-DylibSymlinks {
    param (
        [Parameter(Mandatory=$true)][string]$libDir
    )

    Write-Message "Consolidating libraries and symlinks..."
    Push-Location "$libDir"

    # Enumerate files
    $physicalFiles = @()
    $dylibFiles = Get-ChildItem -Path . -Filter "*.dylib"
    if($dylibFiles.Count -eq 0) {
        Write-Message "> No .dylib files found.  Skipping step."
        Pop-Location
        return
    }
    $filesAndSymlinks = Get-FilesAndSymlinks -files $dylibFiles
    foreach ($item in $filesAndSymlinks) {
        $physicalFiles += $item.Filename
    }
    Debug-WriteLibraryDependencies $physicalFiles

    $mapOldToNewDependencies = @{}
    foreach( $item in $filesAndSymlinks ) {
        $checkDependencyFilename = Split-Path $item.Filename -Leaf
        $newDependencyFilename = Split-Path $item.NewFilename -Leaf
        if($checkDependencyFilename -ne $newDependencyFilename) {
            $mapOldToNewDependencies[$checkDependencyFilename] = $newDependencyFilename
        }
        foreach( $symlink in $item.Symlinks ) {
            $checkDependencyFilename = Split-Path $symlink -Leaf
            if($checkDependencyFilename -ne $newDependencyFilename) {
                $mapOldToNewDependencies[$checkDependencyFilename] = $newDependencyFilename
            }
        }
    }

    Write-Message "Updating files..."
    foreach ($item in $filesAndSymlinks) {
        # Main file
        Write-Message "> Updating: $($item.Filename)"
        if($null -eq $item.Symlinks) {
            continue;
        }
        $newFilename = Split-Path $item.NewFilename -Leaf
        Invoke-Expression "install_name_tool -id '@rpath/$newFilename' '$($item.Filename)'"

        foreach ($checkDependencyFilename in $mapOldToNewDependencies.Keys) {
            $newDependencyFilename = $mapOldToNewDependencies[$checkDependencyFilename]
            Invoke-Expression "install_name_tool -change '@rpath/$checkDependencyFilename' '@rpath/$newDependencyFilename' '$($item.Filename)'"
        }
    }

    Debug-WriteLibraryDependencies $physicalFiles

    Write-Message "Deleting symlinks..."
    foreach ($item in $filesAndSymlinks) {
        foreach($symlink in $item.Symlinks) {
            Write-Message "> Removing: $symlink"
            Remove-Item $symlink
        }
    }
 
    Write-Message "Renaming files..."
    foreach ($item in $filesAndSymlinks) {
        Write-Message "> Renaming: $($item.Filename) ==> $($item.NewFilename)"
        Move-Item -Path "$($item.Filename)" -Destination "$($item.NewFilename)"
    }

    Pop-Location
}

function Run-CreateDysmAndStripDebugSymbols {
    param (
        [Parameter(Mandatory=$true)][string]$libDir
    )

    Push-Location "$libDir"
    $libraries = (Get-ChildItem -Path . -Filter "*.dylib")
    foreach($library in $libraries) {
        Write-Message "> Processing: $library..."
        Write-Message ">> Running dsymutil"
        $dsymFilename = $library.Name + ".dSYM"
        dsymutil $library.Name -o $dsymFilename

        Write-Message ">> Running strip"
        strip -S $library.Name
    }
    Pop-Location
}

Export-ModuleMember -Function Create-FinalizedMacBuildArtifacts
