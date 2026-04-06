Import-Module "$PSScriptRoot/../../ps-modules/Util" -Force -DisableNameChecking

##################################################
# Private Functions
##################################################
function Install-FromVcpkg {
    param(
        [string]$packageAndFeatures,
        [string]$triplet
    )

    # Extract subdirectory from triplet if it contains a path separator
    # e.g., "onnxruntime/x64-windows-dynamic-release-static-deps" -> overlay-triplets="custom-triplets/onnxruntime"
    $overlayTripletsPath = "custom-triplets"
    if ($triplet -match '^(.+?)/(.+)$') {
        $tripletSubdir = $Matches[1]
        $tripletName = $Matches[2]
        $overlayTripletsPath = "custom-triplets/$tripletSubdir"
    } else {
        $tripletName = $triplet
    }

    $pkgToInstall = "${packageAndFeatures}:${tripletName}"
    Write-Message "Installing package: `"$pkgToInstall`""
    Write-Message "Using overlay-triplets path: `"$overlayTripletsPath`""
    Invoke-Expression "./$(Get-VcPkgExe) install `"$pkgToInstall`" --overlay-triplets=`"$overlayTripletsPath`" --overlay-ports=`"custom-ports`""
}

function Get-PackageNameOnly {
   param(
      [string]$packageAndFeatures
   )
   return ($packageAndFeatures -replace '\[.*$', '')
}

function Get-Triplets {
   param(
      [string]$linkType,
      [string]$buildType,
      [string[]]$customTriplets = @()
   )

   # Filter out any null/empty values that may result from JSON deserialization
   $customTriplets = @($customTriplets | Where-Object { -not [string]::IsNullOrEmpty($_) })
   if ($customTriplets.Count -gt 0) {
       return $customTriplets
   }

   if (Get-IsOnWindowsOS) {
       return @("x64-windows-$linkType-$buildType")
   } elseif (Get-IsOnLinux) {
       return @("x64-linux") # using microsoft provided release
   } elseif (Get-IsOnMacOS) {
       return @("x64-osx-$linkType-$buildType", "arm64-osx-$linkType-$buildType")
   }
   throw [System.Exception]::new("Invalid OS")
}

function Get-PreStagePath {
   return "PreStage"
}

function Get-VcPkgExe {
   if ( (Get-IsOnWindowsOS) ) {
      return "vcpkg/vcpkg.exe"
   } elseif ( (Get-IsOnMacOS) -or (Get-IsOnLinux) ) {
      return "vcpkg/vcpkg"
   }
   throw [System.Exception]::new("Invalid OS")
}

function Get-ArtifactName {
   param(
      [string]$packageName,
      [string]$packageAndFeatures,
      [string]$linkType,
      [string]$buildType,
      [string[]]$customTriplets = @()
   )

   if( $packageName -eq "") {
      $packageNameOnly = (Get-PackageNameOnly $packageAndFeatures)
      $packageName = "$packageNameOnly-$linkType"
   }

   if($customTriplets.Count -gt 0) {
       $firstTriplet = $customTriplets[0]
       # Extract just the triplet name from subdirectory paths like "onnxruntime/x64-windows-dynamic-release"
       # The subdirectory prefix is only needed for vcpkg overlay-triplets, not for artifact naming
       if ($firstTriplet -match '^.+?/(.+)$') {
           $buildName = $Matches[1]  # Use only the triplet filename (e.g., "x64-windows-dynamic-release")
       } else {
           $buildName = $firstTriplet  # No subdirectory, use as-is
       }
   } else {
       $buildName = $buildType
   }

   if ( (Get-IsOnWindowsOS) ) {
      return "$packageName-windows-$buildName"
   } elseif ( (Get-IsOnMacOS) ) {
      return "$packageName-osx-$buildName"
   } elseif ( (Get-IsOnLinux) ) {
      return "$packageName-linux-$buildName"
   }
   throw [System.Exception]::new("Invalid OS")
}

function Write-ReleaseInfoJson {
    param(
        [string] $packageName,
        [string] $version,
        [string] $pathToJsonFile
    )
    $releaseInfo = @{
        packageName = $packageName
        version = $version
    }
    $releaseInfo | ConvertTo-Json | Set-Content -Path $pathToJsonFile
}

function Copy-ItemWithSymlinks {
   param (
       [string]$source,
       [string]$destination
   )

   if ( -not (Test-Path -Path $destination) ) {
      New-Item -ItemType Container -Path $destination | Out-Null
   }

   $items = Get-ChildItem -LiteralPath $source
   foreach ($item in $items) {
       $relativePath = $item.FullName.Substring($source.Length + 1)
       $destPath = Join-Path -Path $destination -ChildPath $relativePath

       if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
         New-Item -ItemType SymbolicLink -Path $destPath -Target $item.Target -Force | Out-Null
       }
       else {
         if ($item.PSIsContainer) {
            Copy-ItemWithSymlinks -source $item.FullName -destination $destPath
         }
         else {
            Copy-Item -LiteralPath "$($item.FullName)" -Destination "$destPath" -Force | Out-Null
         }
       }
   }
}

##################################################
# Exported Functions
##################################################
function Get-PackageInfo
{
    param(
        [string]$packageName,
        [string]$targetPlatform
    )
    $jsonFilePath = "preconfigured-packages.json"
    Write-Message "Reading config from: `"$jsonFilePath`""
    $packagesJson = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json
    $pkg = $packagesJson.packages | Where-Object { $_.name -eq $packageName }
    if (-not $pkg) {
        Write-Message "> Package not found in $jsonFilePath."
        exit
    }

    $pkgInfo = $pkg.$targetPlatform

    # Deal with any optional properties that might not be specified in the json file
    $publishProperties = @{
      "include" = $true
      "lib" = $true
      "bin" = $true
      "share" = $true
      "tools" = $false
      "debug" = $false
    }

    if (-not ($pkgInfo.PSObject)) {
      return $null;
    }

    if (-not ($pkgInfo.PSObject.Properties["publish"])) {
      $pkgInfo | Add-Member -MemberType NoteProperty -Name "publish" -Value @{}
    }

    foreach ($property in $publishProperties.Keys) {
      if (-not $pkgInfo.publish.PSObject.Properties[$property]) {
        $pkgInfo.publish | Add-Member -MemberType NoteProperty -Name $property -Value $publishProperties[$property]
      }
    }

    return $pkg.$targetPlatform
}

function Run-WriteParamsStep {
   param(
      [string]$packageAndFeatures,
      [PSObject]$scriptArgs
   )
   Write-Banner -Level 2 -Title "Starting vcpkg install for: $packageAndFeatures"
   Write-Message "Params:"
   Write-Message (Get-PSObjectAsFormattedList -Object $scriptArgs)
}

function Run-CleanupStep {
   Write-Banner -Level 3 -Title "Cleaning files"

   Write-Message "Removing vcpkg cache..."
   if ( (Get-IsOnWindowsOS) ) {
       $vcpkgCacheDir = "$env:LocalAppData/vcpkg/archives"
   } elseif ( (Get-IsOnMacOS) -or (Get-IsOnLinux) ) {
      $vcpkgCacheDir = "$HOME/.cache/vcpkg/archives"
   }
   if (Test-Path -Path $vcpkgCacheDir -PathType Container) {
      Remove-Item -Path $vcpkgCacheDir -Recurse -Force
   }

   Write-Message "Removing vcpkg dir..."
   $vcpkgInstallDir = "./vcpkg"
   if (Test-Path -Path $vcpkgInstallDir -PathType Container) {
      Remove-Item -Path $vcpkgInstallDir -Recurse -Force
   }

   Write-Message "Removing StagedArtifacts..."
   $stagedArtifactsDir = "./StagedArtifacts"
   if (Test-Path -Path $stagedArtifactsDir -PathType Container) {
      Remove-Item -Path $stagedArtifactsDir -Recurse -Force
   }
}

function Run-SetupVcpkgStep {
   param(
      [string]$repoHash
   )

   $repo = "https://github.com/microsoft/vcpkg.git"
   $installDir = "./vcpkg"
   if ( (Get-IsOnWindowsOS) ) {
       $bootstrapScript = "./bootstrap-vcpkg.bat"
   } elseif ( (Get-IsOnMacOS) -or (Get-IsOnLinux) ) {
       $bootstrapScript = "./bootstrap-vcpkg.sh"
   }

   Write-Banner -Level 3 -Title "Setting up vcpkg"

   Write-Message "$(NL)Installing vcpkg..."
   if (-not (Test-Path -Path $installDir -PathType Container)) {
      git clone $repo
      if ($repoHash -ne "") {
          Push-Location $installDir
          git checkout $repoHash
          Pop-Location
      }
   }

   Write-Message "$(NL)Bootstrapping vcpkg..."
   Push-Location $installDir
   Invoke-Expression "$bootstrapScript"
   Pop-Location
}

function Run-PreBuildStep {
   param(
      [string]$packageAndFeatures
   )
   $packageNameOnly = (Get-PackageNameOnly $packageAndFeatures)
   Run-ScriptIfExists -title "Pre-build step" -script "custom-steps/$packageNameOnly/pre-build.ps1"
}

function Check-IsEmscriptenBuild {
   param(
      [string[]]$triplets
   )

   foreach ($triplet in $triplets) {
      if ($triplet -like "*wasm32*") {
         return $true
      }
   }
   return $false
}

function Install-Emscripten
{
   param(
      [string]$version
   )

   Write-Message "Installing emscripten..."
   $emsdkDir = "./emsdk"
   pwd
   if (Test-Path -Path $emsdkDir -PathType Container) {
      Remove-Item -Path $emsdkDir -Recurse -Force
   }

   git clone https://github.com/emscripten-core/emsdk.git
   Push-Location emsdk
   ./emsdk install $version
   ./emsdk activate $version
   $EMSDK_PY="python3"
   ./emsdk_env.ps1
   Pop-Location
}

function Run-InstallCompilerIfNecessary {
   param(
      [string[]]$triplets
   )

   if( Check-IsEmscriptenBuild -triplets $triplets ) {
      $emscriptenCompilerVersion = "3.1.58"
      Install-Emscripten -version $emscriptenCompilerVersion
   }
}

function Run-InstallPackageStep
{
   param(
      [string]$packageAndFeatures,
      [string[]]$triplets
   )
   Write-Banner -Level 3 -Title "Install package step: $packageAndFeatures"

   foreach ($triplet in $triplets) {
      Write-Message "> Installing for triplet: $triplet..."
      Install-FromVcPkg -packageAndFeatures $packageAndFeatures -triplet $triplet
      Exit-IfError $LASTEXITCODE
   }
}

function Run-PrestageAndFinalizeBuildArtifactsStep {
   param(
      [string[]]$triplets,
      [PSObject]$publishInfo
   )
   $preStagePath = (Get-PreStagePath)
   Create-EmptyDir $preStagePath
   Write-Banner -Level 3 -Title "Pre-staging artifacts"

   $libDir = "lib"
   $binDir = "bin"
   $toolsDir = "tools"

   # If we're on MacOS and we didn't specify a custom triplet, we're building a universal binary
   # If we specify a custom triplet, we can only build one architecture at a time
   $isUniversalBinary = ((Get-IsOnMacOS) -and ($triplets.Count -eq 2))

   # Get dirs to copy
   $srcToDestDirs = @{}
   if($isUniversalBinary) {
      # Strip subdirectory prefix if present (e.g., "onnxruntime/x64-osx-dynamic-release" -> "x64-osx-dynamic-release")
      # vcpkg installs to just the triplet name, not the overlay-triplets subdirectory path
      $tripletX64 = $triplets[0]
      $tripletArm64 = $triplets[1]
      if ($tripletX64 -match '^.+?/(.+)$') { $tripletX64 = $Matches[1] }
      if ($tripletArm64 -match '^.+?/(.+)$') { $tripletArm64 = $Matches[1] }
      $srcX64Dir = "./vcpkg/installed/$tripletX64"
      $srcArm64Dir = "./vcpkg/installed/$tripletArm64"
      $destArm64LibDir = "$preStagePath/arm64Lib"
      $destX64LibDir = "$preStagePath/x64Lib"
      $destArm64ToolsDir = "$preStagePath/arm64Tools"
      $destX64ToolsDir = "$preStagePath/x64Tools"
      $srcToDestDirs = @{
         "$srcArm64Dir/include" = "$preStagePath"
         "$srcArm64Dir/share" = "$preStagePath"
         "$srcArm64Dir/$libDir" = "$destArm64LibDir"
         "$srcX64Dir/$libDir" = "$destX64LibDir"
         "$srcArm64Dir/$toolsDir" = "$destArm64ToolsDir"
         "$srcX64Dir/$toolsDir" = "$destX64ToolsDir"
      }
   }
   else {
      $firstTriplet = $triplets | Select-Object -First 1
      # Strip subdirectory prefix if present (e.g., "onnxruntime/x64-windows-dynamic-release" -> "x64-windows-dynamic-release")
      # This matches the behavior in Install-FromVcpkg where vcpkg installs using only the triplet name
      if ($firstTriplet -match '^.+?/(.+)$') {
         $firstTriplet = $Matches[1]
      }
      $mainSrcDir = "./vcpkg/installed/$firstTriplet"
      $srcToDestDirs = @{
         "$mainSrcDir/include" = "$preStagePath/include"
         "$mainSrcDir/share" = "$preStagePath/share"
         "$mainSrcDir/$libDir" = "$preStagePath/lib"
         "$mainSrcDir/$binDir" = "$preStagePath/bin"
         "$mainSrcDir/$toolsDir" = "$preStagePath/tools"
         "$mainSrcDir/debug" = "$preStagePath/debug"
      }
   }

   $keysToRemove = @()
   foreach ($srcDir in $srcToDestDirs.Keys) {
     $destDir = $srcToDestDirs[$srcDir]
     $dirName = [System.IO.Path]::GetFileName($srcDir)
     if ($publishInfo.$dirName -eq $false) {
       $keysToRemove += $srcDir
     }
   }
   foreach($key in $keysToRemove) {
      $srcToDestDirs.Remove($key)
   }

   # Copy dirs
   foreach ($srcDir in $srcToDestDirs.Keys) {
     $destDir = $srcToDestDirs[$srcDir]
     if (Test-Path $srcDir) {
       Write-Message "$srcDir ==> $destDir"
       if((Get-IsOnWindowsOS)) {
         Copy-Item -Path $srcDir -Destination $destDir -Force -Recurse
       }
       elseif((Get-IsOnMacOS) -or (Get-IsOnLinux)) {
          cp -RP "$srcDir" "$destDir"
       }
     }
   }

   # Finalize artifacts (Mac-only)
   if(($isUniversalBinary) -and ((Test-Path $destArm64LibDir) -or (Test-Path $destArm64ToolsDir))) {
     if($publishInfo.lib -eq $true) {
       $destUniversalLibDir = "$preStagePath/lib"
       Create-FinalizedMacBuildArtifacts -arm64Dir "$destArm64LibDir" -x64Dir "$destX64LibDir" -universalDir "$destUniversalLibDir"
     }
     
     if($publishInfo.tools -eq $true) {
       $destUniversalToolsDir = "$preStagePath/tools"
       Create-FinalizedMacBuildArtifacts -arm64Dir "$destArm64ToolsDir" -x64Dir "$destX64ToolsDir" -universalDir "$destUniversalToolsDir" -filenameFilter @("*")
     }
   }
}

function Run-PostBuildStep {
   param(
      [string]$packageAndFeatures,
      [string]$linkType,
      [string]$buildType,
      [string[]]$triplets
   )
   $packageNameOnly = (Get-PackageNameOnly $packageAndFeatures)
   $preStagePath = (Get-PreStagePath)
   $scriptArgs = @{
      BuildArtifactsPath = ((Resolve-Path $preStagePath).Path -replace '\\', '/')
      PackageAndFeatures = ($packageAndFeatures -replace ',', '`,')
      LinkType = "$linkType"
      BuildType = "$buildType"
      ModulesRoot = "$PSScriptRoot/../../ps-modules"
      Triplets = $triplets
   }
   Run-ScriptIfExists -title "Post-build step" -script "custom-steps/$packageNameOnly/post-build.ps1" -scriptArgs $scriptArgs
   Exit-IfError $LASTEXITCODE
}

function Run-StageBuildArtifactsStep {
   param(
      [string]$packageName,
      [string]$packageAndFeatures,
      [string]$linkType,
      [string]$buildType,
      [string[]]$customTriplets = @(),
      [string]$stagedArtifactsPath,
      [PSObject]$publishInfo,
      [bool]$deletePrestageDir = $true
   )

   Write-Banner -Level 3 -Title "Stage build artifacts"

   $stagedArtifactSubDir = "$stagedArtifactsPath/bin"
   $artifactName = "$((Get-ArtifactName -packageName $packageName -packageAndFeatures $packageAndFeatures -linkType $linkType -buildType $buildType -customTriplets $customTriplets))-bin"
   New-Item -Path $stagedArtifactSubDir/$artifactName -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

   $dependenciesFilename = "dependencies.json"
   Write-Message "Generating: `"$dependenciesFilename`"..."
   Invoke-Expression "./$(Get-VcPkgExe) list --x-json > $stagedArtifactSubDir/$artifactName/$dependenciesFilename"

   $packageInfoFilename = "package.json"
   Write-Message "Generating: `"$packageInfoFilename`"..."
   $dependenciesJson = Get-Content -Raw -Path "$stagedArtifactSubDir/$artifactName/$dependenciesFilename" | ConvertFrom-Json
   $packageNameOnly = (Get-PackageNameOnly $packageAndFeatures)
   $packageVersion = ($dependenciesJson.PSObject.Properties.Value | Where-Object { $_.package_name -eq $packageNameOnly } | Select-Object -First 1).version
   Write-ReleaseInfoJson -packageName $packageName -version $packageVersion -pathToJsonFile "$stagedArtifactSubDir/$artifactName/$packageInfoFilename"

   $preStagePath = (Get-PreStagePath)
   Write-Message "Moving files: $preStagePath =`> $artifactName"

   # Figure out which folders we should avoid copying from the PublishInfo object
   $excludedFolders = @()
   if ($null -ne $publishInfo) {
      foreach ($member in $publishInfo | Get-Member -MemberType NoteProperty) {
          $value = $publishInfo."$($member.Name)"
          if($value -eq $false) {
              $excludedFolders += $member.Name
          }
      }
   }

   if ($deletePrestageDir) {
      Get-ChildItem -Path "$preStagePath" -Exclude $excludedFolders | ForEach-Object { Move-Item -Path "$($_.FullName)" -Destination "$stagedArtifactSubDir/$artifactName" }
      Remove-Item -Path $preStagePath -Recurse | Out-Null
   }
   else {
      Get-ChildItem -Path "$preStagePath" -Exclude $excludedFolders | ForEach-Object { Copy-Item -Path "$($_.FullName)" -Destination "$stagedArtifactSubDir/$artifactName" }
   }

   $artifactArchive = "$artifactName.tar.gz"
   Write-Message "Creating final artifact: `"$artifactArchive`""
   tar -czf "$stagedArtifactSubDir/$artifactArchive" -C "$stagedArtifactSubDir/$artifactName" .
   Remove-Item -Path "$stagedArtifactSubDir/$artifactName" -Recurse -Force
}

function Run-StageSourceArtifactsStep {
   param(
      [string]$packageName,
      [string]$packageAndFeatures,
      [string]$linkType,
      [string]$buildType,
      [string[]]$customTriplets = @(),
      [string]$stagedArtifactsPath
   )

   Write-Banner -Level 3 -Title "Stage source code artifacts"

   $sourceCodeRootDir = "./vcpkg/buildtrees/"
   $artifactName = "$((Get-ArtifactName -packageName $packageName -packageAndFeatures $packageAndFeatures -linkType $linkType -buildType $buildType -customTriplets $customTriplets))-src"
   $stagedArtifactSubDir = "$stagedArtifactsPath/src"
   $artifactPath = "$stagedArtifactSubDir/$artifactName"

   Write-Message "Copying: $sourceCodeRootDir ==> $artifactPath"
   if (-not (Test-Path -Path $artifactPath)) {
       New-Item -ItemType Directory -Path $artifactPath | Out-Null
   }
   $buildTreesSubDirs = Get-ChildItem -LiteralPath $sourceCodeRootDir -Directory
   foreach ($buildTreesSubDir in $buildTreesSubDirs) {
       $srcDir = Join-Path -Path $buildTreesSubDir.FullName -ChildPath "src"
       if (Test-Path -Path $srcDir) {
           $destDir = Join-Path -Path $artifactPath -ChildPath $buildTreesSubDir.Name
           Write-Message "$srcDir ==> $destDir"
           if (-not (Test-Path -Path $destDir)) {
               New-Item -ItemType Directory -Path $destDir | Out-Null
           }
           Copy-ItemWithSymlinks -source "$srcDir" -destination "$destDir"
       }
   }

   $artifactArchive = "$artifactName.tar.gz"
   Write-Message "Creating final artifact: `"$artifactArchive`""
   tar -czf "$stagedArtifactSubDir/$artifactArchive" -C "$stagedArtifactSubDir/$artifactName" .
   Remove-Item -Path "$stagedArtifactSubDir/$artifactName" -Recurse -Force
}

function Resolve-Symlink {
   param (
       [string]$path
   )

   $currentPath = Get-Item -Path $path
   while ($currentPath.PSIsContainer -eq $false -and $null -ne $currentPath.LinkType) {
       $currentPath = Get-Item -Path $currentPath.Target
   }
   return $currentPath.FullName
}

function Apply-VcpkgPortPatch {
    <#
    .SYNOPSIS
    Applies a patch file to a vcpkg port.
    
    .DESCRIPTION
    Applies a git patch to a vcpkg port's files (typically portfile.cmake).
    Useful for making TechSmith-specific modifications without maintaining
    full custom port overlays.
    
    .PARAMETER PortName
    The name of the vcpkg port to patch (e.g., "pango")
    
    .PARAMETER PatchFile
    Path to the patch file to apply
    
    .PARAMETER WorkingDirectory
    Optional. The directory to run git apply from. Defaults to the port directory.
    
    .EXAMPLE
    Apply-VcpkgPortPatch -PortName "pango" -PatchFile "$PSScriptRoot/add-objc-support.patch"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$PortName,
        
        [Parameter(Mandatory=$true)]
        [string]$PatchFile,
        
        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = $null
    )
    
    $vcpkgPortDir = "$PSScriptRoot/../../../vcpkg/ports/$PortName"
    
    if (-not (Test-Path $vcpkgPortDir)) {
        Write-Message "> vcpkg port directory not found: $vcpkgPortDir" -Warning
        return $false
    }
    
    if (-not (Test-Path $PatchFile)) {
        Write-Message "> Patch file not found: $PatchFile" -Warning
        return $false
    }
    
    $workDir = if ($WorkingDirectory) { $WorkingDirectory } else { $vcpkgPortDir }
    
    Write-Message "> Applying patch to $PortName port: $(Split-Path -Leaf $PatchFile)"
    
    Push-Location $workDir
    try {
        $output = git apply --unidiff-zero --inaccurate-eof --ignore-space-change --ignore-whitespace --whitespace=nowarn "$PatchFile" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Message "> Patch applied successfully"
            return $true
        } else {
            # Check if patch is already applied
            $checkOutput = git apply --reverse --check --ignore-whitespace "$PatchFile" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Message "> Patch appears to be already applied (skipping)"
                return $true
            } else {
                Write-Message "> FAILED to apply patch to $PortName port" -Error
                Write-Message "> Git apply exit code: $LASTEXITCODE" -Error
                Write-Message "> Git apply output: $output" -Error
                Write-Message "> Patch file: $PatchFile" -Error
                Write-Message "> Working directory: $workDir" -Error
                return $false
            }
        }
    } finally {
        Pop-Location
    }
}

Export-ModuleMember -Function Get-PackageInfo, Run-WriteParamsStep, Run-SetupVcpkgStep, Run-PreBuildStep, Run-InstallCompilerIfNecessary, Run-InstallPackageStep, Run-PrestageAndFinalizeBuildArtifactsStep, Run-PostBuildStep, Run-StageBuildArtifactsStep, Run-StageSourceArtifactsStep, Run-CleanupStep, Get-Triplets
Export-ModuleMember -Function NL, Write-Banner, Write-Message, Check-IsEmscriptenBuild, Get-PSObjectAsFormattedList, Get-IsOnMacOS, Get-IsOnWindowsOS, Get-IsOnLinux, Get-OSType, Get-VcPkgExe, Resolve-Symlink, Apply-VcpkgPortPatch

if ( (Get-IsOnMacOS) ) {
   Import-Module "$PSScriptRoot/../../ps-modules/MacBuild" -DisableNameChecking -Force
   Export-ModuleMember -Function Remove-DylibSymlinks
} elseif ( (Get-IsOnWindowsOS) ) {
   Import-Module "$PSScriptRoot/../../ps-modules/WinBuild" -DisableNameChecking -Force
   Export-ModuleMember -Function Update-VersionInfoForDlls
}

function Create-EmptyDir {
    param(
       $dir
    )
    if (Test-Path -Path $dir -PathType Container) {
       Remove-Item -Path "$dir" -Recurse -Force | Out-Null
    }
    New-Item -Path "$dir" -ItemType Directory -Force | Out-Null
}