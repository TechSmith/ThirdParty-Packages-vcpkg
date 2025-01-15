function Create-UniversalBinaries {
    param(
       [string]$arm64Dir,
       [string]$x64Dir,
       [string]$universalDir,
       [string[]]$filenameFilter = @("*.dylib", "*.a")
    )

    Write-Output "Creating universal bins: $arm64Dir..."

    $arm64Dir = [System.IO.Path]::GetFullPath($arm64Dir)
    $x64Dir = [System.IO.Path]::GetFullPath($x64Dir)
    $universalDir = [System.IO.Path]::GetFullPath($universalDir)

    New-Item -Path "$universalDir" -ItemType Directory -Force | Out-Null
        
    $items = Get-ChildItem -Path "$arm64Dir" -Include $filenameFilter -Recurse
    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($arm64Dir.Length)
        $destDir = Join-Path $universalDir (Split-Path $relativePath -Parent)
        $fileName = $item.Name
        Write-Output "> $fileName"
 
        $srcPathArm64 = $item.FullName
        $srcPathX64 = Join-Path $x64Dir $relativePath
        $destPath = Join-Path $universalDir $relativePath 
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            New-Item -Path "$destDir" -ItemType Directory -Force | Out-Null
            Invoke-Expression -Command "cp -R `"$srcPathArm64`" `"$destPath`""
        }
        elseif (-not $item.PSIsContainer) {
            New-Item -Path "$destDir" -ItemType Directory -Force | Out-Null
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
      if(-not (Test-Path($destinationPath))) 
      {
        Copy-Item -Path $_.FullName -Destination $destinationPath
      }
   }
}

function Create-FinalizedMacBuildArtifacts {
    param (
        [string]$arm64Dir,
        [string]$x64Dir,
        [string]$universalDir,
        [string[]]$filenameFilter = @("*.dylib","*.a")
    )
    Write-Banner -Level 3 -Title "Finalizing Mac artifacts"
    ConvertTo-RelativeInstallPaths -directory $arm64Dir -filenameFilter $filenameFilter
    ConvertTo-RelativeInstallPaths -directory $x64Dir -filenameFilter $filenameFilter
    Create-UniversalBinaries -arm64Dir $arm64Dir -x64Dir $x64Dir -universalDir $universalDir -filenameFilter $filenameFilter
    Copy-NonLibraryFiles -srcDir $arm64Dir -destDir $universalDir
    Remove-Item -Force -Recurse -Path $arm64Dir
    Remove-Item -Force -Recurse -Path $x64Dir
    Remove-DylibSymlinks -libDir $universalDir
    Run-CreateDysmAndStripDebugSymbols -libDir $universalDir
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
        [string]$extension,
        [string[]]$filenameFilter
    )

    $libFiles = Get-ChildItem -Path $directory -Include $filenameFilter -Recurse -File
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
