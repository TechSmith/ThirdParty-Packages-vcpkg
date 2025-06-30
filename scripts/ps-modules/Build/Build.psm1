Import-Module "$PSScriptRoot/../../ps-modules/Util" -Force -DisableNameChecking

##################################################
# Private Functions
##################################################
function Install-FromVcpkg {
    param(
        [string]$portAndFeatures,
        [string]$triplet
    )

    $pkgToInstall = "${portAndFeatures}:${triplet}"
    Write-Message "Installing package: `"$pkgToInstall`""
    Invoke-Expression "./$(Get-VcPkgExe) install `"$pkgToInstall`" --overlay-triplets=`"custom-triplets`" --overlay-ports=`"custom-ports`""
}

function Get-PortNameOnly {
   param(
      [string]$portAndFeatures
   )
   return ($portAndFeatures -replace '\[.*$', '')
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
      return "vcpkg/vcpkg.exe"
   } elseif ( (Get-IsOnMacOS) -or (Get-IsOnLinux) ) {
      return "vcpkg/vcpkg"
   }
   throw [System.Exception]::new("Invalid OS")
}

function Get-ArtifactName {
   param(
      [string]$packageName,
      [string]$portAndFeatures,
      [string]$linkType,
      [string]$buildType,
      [string]$customTriplet
   )

   if( $packageName -eq "") {
      $packageNameOnly = (Get-PortNameOnly $portAndFeatures)
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

function Get-VcpkgPortVersion {
    param(
        [Parameter(Mandatory=$true)][string]$portName,
        [string]$overlayPortsPath
    )

    try {
        # Build the arguments for the vcpkg command
        $vcpkgArgs = @("search", $PortName)
        if (-not [string]::IsNullOrEmpty($overlayPortsPath)) {
            $vcpkgArgs += "--overlay-ports=$overlayPortsPath"
        }

        # Execute vcpkg search and capture the output, including any errors
        Write-Host "> vcpkg.exe on the next line..."
        Write-Host $(Get-VcPkgExe)
        $searchOutput = & $(Get-VcPkgExe) $vcpkgArgs 2>&1

        # Escape the port name to handle special regex characters safely.
        $escapedPortName = [regex]::Escape($portName)

        # Find the line that exactly matches the port name at the beginning.
        # This avoids partial matches (e.g., searching "cli" and matching "clipp").
        # We also check that the object is a string to avoid errors on ErrorRecord objects.
        $portLine = $searchOutput | Where-Object { $_ -is [string] -and $_.TrimStart() -match "^$escapedPortName\s+" }

        if ($portLine) {
            # The output is space-delimited. Split the line by one or more whitespace characters.
            $parts = $portLine.Trim() -split '\s+'

            # The version is the second part of the output.
            # Example: "10.0.0#1"
            $versionWithHash = $parts[1]

            # Strip off the hash and anything after it by splitting on '#' and taking the first part.
            $version = $versionWithHash.Split('#')[0]

            return $version
        } else {
            Write-Warning "Port '$portName' not found."
            return $null
        }
    }
    catch {
        Write-Error "An error occurred while running 'vcpkg search'. Make sure vcpkg is in your PATH."
        Write-Error $_.Exception.Message
        return $null
    }
}

function Run-WriteParamsStep {
   param(
      [string]$portAndFeatures,
      [PSObject]$scriptArgs
   )
   Write-Banner -Level 2 -Title "Starting vcpkg install for: $portAndFeatures"
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
      [string]$portAndFeatures
   )
   $packageNameOnly = (Get-PortNameOnly $portAndFeatures)
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
      [string]$portAndFeatures,
      [string[]]$triplets
   )
   Write-Banner -Level 3 -Title "Install package step: $portAndFeatures"

   foreach ($triplet in $triplets) {
      Write-Message "> Installing for triplet: $triplet..."
      Install-FromVcPkg -portAndFeatures $portAndFeatures -triplet $triplet
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
      $srcX64Dir = "./vcpkg/installed/$($triplets[0])"
      $srcArm64Dir = "./vcpkg/installed/$($triplets[1])"
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
      [string]$portAndFeatures,
      [string]$linkType,
      [string]$buildType,
      [string[]]$triplets,
      [string]$buildNumber
   )
   $packageNameOnly = (Get-PortNameOnly $portAndFeatures)
   $preStagePath = (Get-PreStagePath)
   $scriptArgs = @{
      BuildArtifactsPath = ((Resolve-Path $preStagePath).Path -replace '\\', '/')
      PortAndFeatures = ($portAndFeatures -replace ',', '`,')
      LinkType = "$linkType"
      BuildType = "$buildType"
      ModulesRoot = "$PSScriptRoot/../../ps-modules"
      Triplets = $triplets
      BuildNumber = $buildNumber
   }
   Run-ScriptIfExists -title "Post-build step" -script "custom-steps/$packageNameOnly/post-build.ps1" -scriptArgs $scriptArgs
   Exit-IfError $LASTEXITCODE
}

function Run-StageBuildArtifactsStep {
   param(
      [string]$packageName,
      [string]$portAndFeatures,
      [string]$linkType,
      [string]$buildType,
      [string]$customTriplet,
      [string]$stagedArtifactsPath,
      [PSObject]$publishInfo,
      [bool]$deletePrestageDir = $true
   )

   Write-Banner -Level 3 -Title "Stage build artifacts"

   $stagedArtifactSubDir = "$stagedArtifactsPath/bin"
   $artifactName = "$((Get-ArtifactName -packageName $packageName -portAndFeatures $portAndFeatures -linkType $linkType -buildType $buildType -customTriplet $customTriplet))-bin"
   New-Item -Path $stagedArtifactSubDir/$artifactName -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

   $dependenciesFilename = "dependencies.json"
   Write-Message "Generating: `"$dependenciesFilename`"..."
   Invoke-Expression "./$(Get-VcPkgExe) list --x-json > $stagedArtifactSubDir/$artifactName/$dependenciesFilename"

   $packageInfoFilename = "package.json"
   Write-Message "Generating: `"$packageInfoFilename`"..."
   $dependenciesJson = Get-Content -Raw -Path "$stagedArtifactSubDir/$artifactName/$dependenciesFilename" | ConvertFrom-Json
   $packageNameOnly = (Get-PortNameOnly $portAndFeatures)
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
      [string]$portAndFeatures,
      [string]$linkType,
      [string]$buildType,
      [string]$customTriplet,
      [string]$stagedArtifactsPath
   )

   Write-Banner -Level 3 -Title "Stage source code artifacts"

   $sourceCodeRootDir = "./vcpkg/buildtrees/"
   $artifactName = "$((Get-ArtifactName -packageName $packageName -portAndFeatures $portAndFeatures -linkType $linkType -buildType $buildType -customTriplet $customTriplet))-src"
   $stagedArtifactSubDir = "$stagedArtifactsPath/src"
   $artifactPath = "$stagedArtifactSubDir/$artifactName"

   Write-Message "Copying: $sourceCodeRootDir ==> $artifactPath"
   if (-not (Test-Path -Path $artifactPath)) {
       New-Item -ItemType Directory -Path $artifactPath | Out-Null
   }
   $buildTreesSubDirs = Get-ChildItem -Path $sourceCodeRootDir -Directory
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

Export-ModuleMember -Function Get-PackageInfo, Run-WriteParamsStep, Run-SetupVcpkgStep, Run-PreBuildStep, Run-InstallCompilerIfNecessary, Run-InstallPackageStep, Run-PrestageAndFinalizeBuildArtifactsStep, Run-PostBuildStep, Run-StageBuildArtifactsStep, Run-StageSourceArtifactsStep, Run-CleanupStep, Get-Triplets
Export-ModuleMember -Function NL, Write-Banner, Write-Message, Check-IsEmscriptenBuild, Get-PSObjectAsFormattedList, Get-IsOnMacOS, Get-IsOnWindowsOS, Get-IsOnLinux, Get-OSType, Get-PortNameOnly, Get-VcPkgExe, Get-VcpkgPortVersion, Resolve-Symlink

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