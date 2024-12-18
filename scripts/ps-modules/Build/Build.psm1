Import-Module "$PSScriptRoot/../../ps-modules/Util" -Force -DisableNameChecking

##################################################
# Private Functions
##################################################
function Install-FromVcpkg {
    param(
        [string]$packageAndFeatures,
        [string]$triplet
    )

    $pkgToInstall = "${packageAndFeatures}:${triplet}"
    Write-Message "Installing package: `"$pkgToInstall`""
    Invoke-Expression "$(Get-VcPkgExe) install `"$pkgToInstall`" --overlay-triplets=`"custom-triplets`" --overlay-ports=`"custom-ports`""
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
      [string]$customTriplet
   )

   if ( -not [string]::IsNullOrEmpty($customTriplet) ) {
       return @($customTriplet)
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
      return "./vcpkg/vcpkg.exe"
   } elseif ( (Get-IsOnMacOS) -or (Get-IsOnLinux) ) {
      return "./vcpkg/vcpkg"
   }
   throw [System.Exception]::new("Invalid OS")
}

function Get-ArtifactName {
   param(
      [string]$packageName,
      [string]$packageAndFeatures,
      [string]$linkType,
      [string]$buildType,
      [string]$customTriplet
   )

   if( $packageName -eq "") {
      $packageNameOnly = (Get-PackageNameOnly $packageAndFeatures)
      $packageName = "$packageNameOnly-$linkType"
   }

   if($null -ne $customTriplet) {
       $buildName = $customTriplet
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

   $items = Get-ChildItem -Path $source
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
            Copy-Item -Path "$($item.FullName)" -Destination "$destPath" -Force | Out-Null
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

function Check-RequiresEmscripten {
   param(
      [array]$triplets
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

   if( Check-RequiresEmscripten -triplets $triplets ) {
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
   $isUniversalBinary = ((Get-IsOnMacOS) -and ($customTriplet -eq ""))

   # Get dirs to copy
   $srcToDestDirs = @{}
   if($isUniversalBinary) {
      $srcArm64Dir = "./vcpkg/installed/$($triplets[0])"
      $srcX64Dir = "./vcpkg/installed/$($triplets[1])"
      $destArm64LibDir = "$preStagePath/arm64Lib"
      $destX64LibDir = "$preStagePath/x64Lib"
      $srcToDestDirs = @{
         "$srcArm64Dir/include" = "$preStagePath"
         "$srcArm64Dir/share" = "$preStagePath"
         "$srcArm64Dir/$libDir" = "$destArm64LibDir"
         "$srcX64Dir/$libDir" = "$destX64LibDir"
      }
   }
   else {
      $firstTriplet = $triplets | Select-Object -First 1
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
   if(($isUniversalBinary) -and (Test-Path $destArm64LibDir)) {
     $destUniversalLibDir = "$preStagePath/lib"
     Create-FinalizedMacBuildArtifacts -arm64LibDir "$destArm64LibDir" -x64LibDir "$destX64LibDir" -universalLibDir "$destUniversalLibDir"
   }
}

function Run-PostBuildStep {
   param(
      [string]$packageAndFeatures,
      [string]$linkType,
      [string]$buildType
   )
   $packageNameOnly = (Get-PackageNameOnly $packageAndFeatures)
   $preStagePath = (Get-PreStagePath)
   $scriptArgs = @{
      BuildArtifactsPath = ((Resolve-Path $preStagePath).Path -replace '\\', '/')
      PackageAndFeatures = ($packageAndFeatures -replace ',', '`,')
      LinkType = "$linkType"
      BuildType = "$buildType"
      ModulesRoot = "$PSScriptRoot/../../ps-modules"
   }
   Run-ScriptIfExists -title "Post-build step" -script "custom-steps/$packageNameOnly/post-build.ps1" -scriptArgs $scriptArgs
}

function Run-StageBuildArtifactsStep {
   param(
      [string]$packageName,
      [string]$packageAndFeatures,
      [string]$linkType,
      [string]$buildType,
      [string]$customTriplet,
      [string]$stagedArtifactsPath,
      [PSObject]$publishInfo
   )

   Write-Banner -Level 3 -Title "Stage build artifacts"

   $stagedArtifactSubDir = "$stagedArtifactsPath/bin"
   $artifactName = "$((Get-ArtifactName -packageName $packageName -packageAndFeatures $packageAndFeatures -linkType $linkType -buildType $buildType -customTriplet $customTriplet))-bin"
   New-Item -Path $stagedArtifactSubDir/$artifactName -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

   $dependenciesFilename = "dependencies.json"
   Write-Message "Generating: `"$dependenciesFilename`"..."
   Invoke-Expression "$(Get-VcPkgExe) list --x-json > $stagedArtifactSubDir/$artifactName/$dependenciesFilename"

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

   Get-ChildItem -Path "$preStagePath" -Exclude $excludedFolders | ForEach-Object { Move-Item -Path "$($_.FullName)" -Destination "$stagedArtifactSubDir/$artifactName" }
   Remove-Item -Path $preStagePath -Recurse | Out-Null

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
      [string]$customTriplet,
      [string]$stagedArtifactsPath
   )

   Write-Banner -Level 3 -Title "Stage source code artifacts"

   $sourceCodeRootDir = "./vcpkg/buildtrees/"
   $artifactName = "$((Get-ArtifactName -packageName $packageName -packageAndFeatures $packageAndFeatures -linkType $linkType -buildType $buildType -customTriplet $customTriplet))-src"
   $stagedArtifactSubDir = "$stagedArtifactsPath/src"
   $artifactPath = "$stagedArtifactSubDir/$artifactName"

   Write-Host "Copying: $sourceCodeRootDir ==> $artifactPath"
   if (-not (Test-Path -Path $artifactPath)) {
       New-Item -ItemType Directory -Path $artifactPath | Out-Null
   }
   $buildTreesSubDirs = Get-ChildItem -Path $sourceCodeRootDir -Directory
   foreach ($buildTreesSubDir in $buildTreesSubDirs) {
       $srcDir = Join-Path -Path $buildTreesSubDir.FullName -ChildPath "src"
       if (Test-Path -Path $srcDir) {
           $destDir = Join-Path -Path $artifactPath -ChildPath $buildTreesSubDir.Name
           Write-Host "$srcDir ==> $destDir"
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

Export-ModuleMember -Function Get-PackageInfo, Run-WriteParamsStep, Run-SetupVcpkgStep, Run-PreBuildStep, Run-InstallCompilerIfNecessary, Run-InstallPackageStep, Run-PrestageAndFinalizeBuildArtifactsStep, Run-PostBuildStep, Run-StageBuildArtifactsStep, Run-StageSourceArtifactsStep, Run-CleanupStep, Get-Triplets
Export-ModuleMember -Function NL, Write-Banner, Write-Message, Get-PSObjectAsFormattedList, Get-IsOnMacOS, Get-IsOnWindowsOS, Get-IsOnLinux, Get-OSType, Resolve-Symlink

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