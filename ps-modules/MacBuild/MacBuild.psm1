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
    Remove-DylibSymlinks -libDir $universalLibDir
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

function Find-FirstSymlink
{
    param (
        [Parameter(Mandatory=$true)][PSObject]$file,
        [Parameter(Mandatory=$true)][array]$symlinks
    )
    foreach($symlink in $symlinks) {
        $symlinkPath = "$pwd/" + (readlink $symlink)
        if($symlinkPath -eq $file.FullName)
        {
            return $symlink
        }
    }
}

function Get-SymlinkChains {
    param (
        [Parameter(Mandatory=$true)][array]$files
    )

    $filesInDir = @()
    $symlinksInDir = @()
    foreach($file in $files) {
        if($file.Attributes -eq 'ReparsePoint') {
            $symlinksInDir += $file
        }
        else {
            $filesInDir += $file
        }
    }

    $symlinkChains = @()
    foreach($file in $filesInDir)
    {
        if(-not $symlinksInDir)
        {
            $symlinkChains += @{
                PhysicalFilename = $file
                TopOfChainFilename = $file
                Symlinks = $null
            }
            continue
        }

        $symlink = $file
        $topOfChainFilename = $file
        $symlinks = @()
        $maxSymlinkDepth = 10
        for($depth = 0; $depth -lt $maxSymlinkDepth; $depth++) {
            $topOfChainFilename = $symlink
            $symlink = Find-FirstSymlink -file $symlink -symlinks $symlinksInDir
            if(-not $symlink) {
                break
            }
            $symlinks += $symlink
        }
        $symlinkChains += @{
            PhysicalFilename = $file
            TopOfChainFilename = $topOfChainFilename
            Symlinks = $symlinks
        }
    }

    return $symlinkChains
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
    $symlinkChains = Get-SymlinkChains -files $dylibFiles
    foreach ($chain in $symlinkChains) {
        $physicalFiles += $chain.PhysicalFilename
    }
    Debug-WriteLibraryDependencies $physicalFiles

    $dependencyChanges = @()
    foreach($chain in $symlinkChains) {
        $newDependencyFilename = Split-Path $chain.TopOfChainFilename -Leaf
        $oldDependencyFilename = Split-Path $chain.PhysicalFilename -Leaf
        if(-not ($oldDependencyFilename -eq $newDependencyFilename)) {
            $dependencyChanges += @{
                New = $newDependencyFilename
                Old = $oldDependencyFilename
            }
        }
        foreach($symlink in $chain.Symlinks) {
            $oldDependencyFilename = Split-Path $symlink -Leaf
            if($oldDependencyFilename -eq $newDependencyFilename) {
                continue
            }
            $dependencyChanges += @{
                New = $newDependencyFilename
                Old = $oldDependencyFilename
            }
        }
    }

    Write-Host "Updating files..."
    foreach ($chain in $symlinkChains) {
        $newFullFilename = $chain.TopOfChainFilename
        $newFilename = Split-Path $newFullFilename -Leaf
        $physicalFullFilename = $chain.PhysicalFilename
        
        # Main file
        Write-Host "> Updating: $physicalFullFilename"
        Invoke-Expression "install_name_tool -id '@rpath/$newFilename' '$physicalFullFilename'"
        foreach($change in $dependencyChanges) {
            Invoke-Expression "install_name_tool -change '@rpath/$($change.Old)' '@rpath/$($change.New)' '$physicalFullFilename'"
        }
    }

    Debug-WriteLibraryDependencies $physicalFiles

    # Rename files & delete symlinks
    Write-Message "Renaming files & deleting symlinks..."
    foreach ($chain in $symlinkChains) {
        foreach($symlink in $chain.Symlinks) {
            $symlinkFullFilename = $symlink.FullName
            Remove-Item $symlinkFullFilename
        }
        $oldFileFullName = $chain.PhysicalFilename
        $newFileFullName = $chain.TopOfChainFilename
        if($oldFilename -eq $newFilename) {
            continue
        }
        Move-Item -Path $oldFileFullName -Destination $newFileFullName
    }

    Pop-Location
}

Export-ModuleMember -Function Create-FinalizedMacArtifacts, Remove-DylibSymlinks
Export-ModuleMember -Function Create-FinalizedMacArtifacts
