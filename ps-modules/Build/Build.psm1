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
      [string]$buildType
   )
   if (Get-IsOnWindowsOS) {
       return @("x64-windows-$linkType-$buildType")
   } elseif (Get-IsOnMacOS) {
       return @("x64-osx-$linkType-$buildType", "arm64-osx-$linkType-$buildType")
   }
   throw [System.Exception]::new("Invalid OS")
}

function Get-PreStagePath {
   param(
      [string]$linkType,
      [string]$buildType
   )
   if ( (Get-IsOnWindowsOS) ) {
      $firstTriplet = (Get-Triplets -linkType $linkType -buildType $buildType) | Select-Object -First 1
      return "vcpkg/installed/$firstTriplet"
   } elseif ( (Get-IsOnMacOS) ) {
      return "universal"
   }
   throw [System.Exception]::new("Invalid OS")
}

function Get-VcPkgExe {
   if ( (Get-IsOnWindowsOS) ) {
      return "./vcpkg/vcpkg.exe"
   } elseif ( (Get-IsOnMacOS) ) {
      return "./vcpkg/vcpkg"
   }
   throw [System.Exception]::new("Invalid OS")
}

function Get-ArtifactName {
   param(
      [string]$packageName,
      [string]$packageAndFeatures,
      [string]$linkType,
      [string]$buildType
   )

   if( $packageName -eq "") {
      $packageNameOnly = (Get-PackageNameOnly $packageAndFeatures)
      $packageName = "$packageNameOnly-$linkType"
   }
   if ( (Get-IsOnWindowsOS) ) {
      return "$packageName-windows-$buildType"
   } elseif ( (Get-IsOnMacOS) ) {
      return "$packageName-osx-$buildType"
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

##################################################
# Exported Functions
##################################################
function Get-PackageInfo
{
    param(
        [string]$packageName
    )
    $jsonFilePath = "preconfigured-packages.json"
    Write-Message "Reading config from: `"$jsonFilePath`""
    $packagesJson = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json
    $pkg = $packagesJson.packages | Where-Object { $_.name -eq $packageName }
    if (-not $pkg) {
        Write-Message "> Package not found in $jsonFilePath."
        exit
    }
    $selectedSection = if ((Get-IsOnWindowsOS)) { "win" } else { "mac" }
    return $pkg.$selectedSection
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

function Run-SetupVcpkgStep {
   param(
      [string]$repoHash
   )

   $repo = "https://github.com/TechSmith/vcpkg.git"
   $installDir = "./vcpkg"
   if ( (Get-IsOnWindowsOS) ) {
       $bootstrapScript = "./bootstrap-vcpkg.bat"
       $cacheDir = "$env:LocalAppData/vcpkg/archives"
   } elseif ( (Get-IsOnMacOS) ) {
       $bootstrapScript = "./bootstrap-vcpkg.sh"
       $cacheDir = "$HOME/.cache/vcpkg/archives"
   }

   Write-Banner -Level 3 -Title "Setting up vcpkg"
   Write-Message "Removing vcpkg..."
   if (Test-Path -Path $cacheDir -PathType Container) {
      Remove-Item -Path $cacheDir -Recurse -Force
   }
   if (Test-Path -Path $installDir -PathType Container) {
      Remove-Item -Path $installDir -Recurse -Force
   }

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

function Run-InstallPackageStep
{
   param(
      [string]$packageAndFeatures,
      [string]$linkType,
      [string]$buildType
   )
   Write-Banner -Level 3 -Title "Install package step: $packageAndFeatures"
   $triplets = (Get-Triplets -linkType $linkType -buildType $buildType)
   foreach ($triplet in $triplets) {
      Write-Message "> Installing for triplet: $triplet..."
      Install-FromVcPkg -packageAndFeatures $packageAndFeatures -triplet $triplet
      Exit-IfError $LASTEXITCODE
   }
}

function Run-FinalizeArtifactsStep {
   param(
      [string]$linkType,
      [string]$buildType
   )
   if (-not (Get-IsOnMacOS)) { return } # This is only required on Mac
   
   Write-Banner -Level 3 -Title "Creating final Mac artifacts"
   $triplets = (Get-Triplets -linkType $linkType -buildType $buildType)
   $arm64Dir = "./vcpkg/installed/$($triplets[0])"
   $x64Dir = "./vcpkg/installed/$($triplets[1])"
   $preStagePath = (Get-PreStagePath -linkType $linkType -buildType $buildType)
   Create-FinalMacArtifacts -arm64Dir "$arm64Dir" -x64Dir "$x64Dir" -universalDir "$preStagePath"
}

function Run-PostBuildStep {
   param(
      [string]$packageAndFeatures,
      [string]$linkType,
      [string]$buildType
   )
   $packageNameOnly = (Get-PackageNameOnly $packageAndFeatures)
   $preStagePath = (Get-PreStagePath -linkType $linkType -buildType $buildType)
   $scriptArgs = @{ BuildArtifactsPath = ((Resolve-Path $preStagePath).Path -replace '\\', '/') }
   Run-ScriptIfExists -title "Post-build step" -script "custom-steps/$packageNameOnly/post-build.ps1" -scriptArgs $scriptArgs
}

function Run-StageArtifactsStep {
   param(
      $packageName,
      $packageAndFeatures,
      $linkType,
      $buildType,
      $stagedArtifactsPath
   )
   
   Write-Banner -Level 3 -Title "Stage build artifacts"

   $artifactName = (Get-ArtifactName -packageName $packageName -packageAndFeatures $packageAndFeatures -linkType $linkType -buildType $buildType)
   New-Item -Path $stagedArtifactsPath/$artifactName -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

   $dependenciesFilename = "dependencies.json"
   Write-Message "Generating: `"$dependenciesFilename`"..."
   Invoke-Expression "$(Get-VcPkgExe) list --x-json > $stagedArtifactsPath/$artifactName/$dependenciesFilename"

   $packageInfoFilename = "package.json"
   Write-Message "Generating: `"$packageInfoFilename`"..."
   $dependenciesJson = Get-Content -Raw -Path "$stagedArtifactsPath/$artifactName/$dependenciesFilename" | ConvertFrom-Json
   $packageNameOnly = (Get-PackageNameOnly $packageAndFeatures)
   $packageVersion = ($dependenciesJson.PSObject.Properties.Value | Where-Object { $_.package_name -eq $packageNameOnly } | Select-Object -First 1).version
   Write-ReleaseInfoJson -packageName $packageName -version $packageVersion -pathToJsonFile "$stagedArtifactsPath/$artifactName/$packageInfoFilename"
   
   # TODO: Add info in this file on where each package was downloaded from
   # TODO: Add license file info to the staged artifacts (ex. per-library LICENSE, COPYING, or other such files that commonly have license info in them)
   
   $preStagePath = (Get-PreStagePath -linkType $linkType -buildType $buildType)
   Write-Message "Copying files: $preStagePath =`> $artifactName"
   $excludedFolders = @("tools", "share", "debug")
   Copy-Item -Path "$preStagePath/*" -Destination $stagedArtifactsPath/$artifactName -Force -Recurse -Exclude $excludedFolders
   
   $artifactArchive = "$artifactName.tar.gz"
   Write-Message "Creating final artifact: `"$artifactArchive`""
   tar -czf "$stagedArtifactsPath/$artifactArchive" -C "$stagedArtifactsPath/$artifactName" .
   Remove-Item -Path "$stagedArtifactsPath/$artifactName" -Recurse -Force
}

Export-ModuleMember -Function Get-PackageInfo, Run-WriteParamsStep, Run-SetupVcpkgStep, Run-PreBuildStep, Run-InstallPackageStep, Run-FinalizeArtifactsStep, Run-PostBuildStep, Run-StageArtifactsStep
Export-ModuleMember -Function NL, Write-Banner, Write-Message, Get-PSObjectAsFormattedList, Get-IsOnMacOS, Get-IsOnWindowsOS

if ( (Get-IsOnMacOS) ) {
   Import-Module "$PSScriptRoot/../../ps-modules/MacBuild" -DisableNameChecking -Force
   Export-ModuleMember -Function Remove-DylibSymlinks
} elseif ( (Get-IsOnWindowsOS) ) {
   Import-Module "$PSScriptRoot/../../ps-modules/WinBuild" -DisableNameChecking -Force
   Export-ModuleMember -Function Update-VersionInfoForDlls
} 
