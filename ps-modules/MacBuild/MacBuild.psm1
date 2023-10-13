function Create-UniversalDir {
    param(
       $universalDir
    )
    if (Test-Path -Path $universalDir -PathType Container) {
       Remove-Item -Path "$universalDir" -Recurse -Force | Out-Null
    }
    New-Item -Path "$universalDir" -ItemType Directory -Force | Out-Null
}

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
   $universalLibDir = (Join-Path $universalDir "lib")
   New-Item -Path "$universalLibDir" -ItemType Directory -Force | Out-Null

   $items = Get-ChildItem -Path "$arm64LibDir/*" -Include "*.dylib","*.a"
   foreach($item in $items) {
       $fileName = $item.Name
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

function Create-FinalMacArtifacts {
    param (
        [string]$arm64Dir,
        [string]$x64Dir,
        [string]$universalDir
    )
    Write-Message "$arm64Dir, $x64Dir ==> $universalDir"
    
    Create-UniversalDir $universalDir
    Copy-Item -Path "$x64Dir/include" -Destination "$universalDir/include" -Recurse | Out-Null # Assume arm64 and x86_64 are identical

    $arm64LibDir = (Join-Path $arm64Dir "lib")
    $x64LibDir = (Join-Path $x64Dir "lib")
    Update-LibsToRelativePaths -arm64LibDir $arm64LibDir -x64LibDir $x64LibDir
    Create-UniversalBinaries -arm64LibDir $arm64LibDir -x64LibDir $x64LibDir -universalDir $universalDir
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

    foreach ($mainFile in $mainFiles) {
        # Main file
        Invoke-Expression "install_name_tool -id '@rpath/$mainFile' '$mainFile'"

        # All other files that might point to it
        foreach ($possible_current_dependency in $filesWithVersions) {
            $base_filename = ($possible_current_dependency -split '[^a-zA-Z0-9]')[0] # Discard anything after the first non-alphanumeric character
            $new_dependency = "$base_filename.dylib"
            if ($mainFiles -contains $new_dependency) {
                Invoke-Expression "install_name_tool -change '@rpath/$possible_current_dependency' '@rpath/$new_dependency' '$mainFile'"
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
        $base_filename = ($oldFilename -split '[^a-zA-Z0-9]')[0] # Discard anything after the first non-alphanumeric character
        $newFilename = "$base_filename" + [System.IO.Path]::GetExtension($file)
        Move-Item -Path $file.Name -Destination $newFilename
    }

    Pop-Location
}

Export-ModuleMember -Function Create-FinalMacArtifacts, Remove-DylibSymlinks
