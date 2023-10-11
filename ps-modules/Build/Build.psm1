Import-Module "$PSScriptRoot/../../ps-modules/Util" -Force -DisableNameChecking

function Install-FromVcpkg {
    param(
        [string] $Package,
        [string] $Triplet,
        [string] $VcpkgExe
    )

    $pkgToInstall = "${Package}:${Triplet}"
    Write-Message "Installing package: `"$pkgToInstall`""
    Invoke-Expression "$VcpkgExe install `"$pkgToInstall`" --overlay-triplets=`"custom-triplets`" --overlay-ports=`"custom-ports`""
}

function Write-ReleaseInfoJson {
    param(
        [string] $PackageName,
        [string] $Version,
        [string] $PathToJsonFile
    )
    $releaseInfo = @{
        packageName = $PackageName
        version = $Version
    }
    $releaseInfo | ConvertTo-Json | Set-Content -Path $PathToJsonFile
}

function Get-PackageInfo
{
    param(
        [string]$PackageName
    )
    $jsonFilePath = "preconfigured-packages.json"
    Write-Message "Reading config from: `"$jsonFilePath`""
    $packagesJson = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json
    $pkg = $packagesJson.packages | Where-Object { $_.name -eq $PackageName }
    if (-not $pkg) {
        Write-Message "> Package not found in $jsonFilePath."
        exit
    }
    $IsOnWindowsOS = Get-IsOnWindowsOS
    $selectedSection = if ($IsOnWindowsOS) { "win" } else { "mac" }
    return $pkg.$selectedSection
}

function Initialize-Variables {
   param(
      [Parameter(Mandatory=$true)][string]$packageAndFeatures,
      [Parameter(Mandatory=$true)][string]$linkType,
      [string]$packageName = "",
      [string]$buildType = "release",
      [string]$stagedArtifactsPath = "StagedArtifacts",
      [string]$vcpkgHash = ""
   )

   $vcpkgRepo = "https://github.com/TechSmith/vcpkg.git"
   $isOnWindowsOS = Get-isOnWindowsOS
   $isOnMacOS = Get-isOnMacOS
   $packageNameOnly = $packageAndFeatures -replace '\[.*$', ''
   if( $packageName -eq "") {
      $packageName = "$packageNameOnly-$linkType"
   }
   $vcpkgInstallDir = "./vcpkg"
   $triplets = @()
   if ($isOnWindowsOS) {
       $osName = "Windows"
       $vcpkgExe = "./vcpkg/vcpkg.exe"
       $vcpkgCacheDir = "$env:LocalAppData/vcpkg/archives"
       $vcpkgBootstrapScript = "./bootstrap-vcpkg.bat"
       $triplets += "x64-windows-$linkType-$buildType"
       $preStagePath = "vcpkg/installed/$($triplets[0])"
       $artifactName = "$packageName-windows-$buildType"
   } elseif ($isOnMacOS) {
       $osName = "Mac"
       $vcpkgExe = "./vcpkg/vcpkg"
       $vcpkgCacheDir = "$HOME/.cache/vcpkg/archives"
       $vcpkgBootstrapScript = "./bootstrap-vcpkg.sh"
       $triplets += "x64-osx-$linkType-$buildType"
       $triplets += "arm64-osx-$linkType-$buildType"
       $preStagePath = "universal"
       $artifactName = "$packageName-osx-$buildType"
   }

   $vars = @{
       vcpkgRepo = $vcpkgRepo
       vcpkgRepoHash = $vcpkgHash
       vcpkgInstallDir = $vcpkgInstallDir
       vcpkgExe = $vcpkgExe
       vcpkgCacheDir = $vcpkgCacheDir
       vcpkgBootstrapScript = $vcpkgBootstrapScript
       isOnWindowsOS = $isOnWindowsOS
       isOnMacOS = $isOnMacOS
       packageNameOnly = $packageNameOnly
       osName = $osName
       triplets = $triplets
       preStagePath = $preStagePath
       stagePath = $stagedArtifactsPath
       artifactName = $artifactName
       prebuildScript = "custom-steps/$packageNameOnly/pre-build.ps1"
       postbuildScript = "custom-steps/$packageNameOnly/post-build.ps1"
   }
   if ($isOnMacOS) {
       $vars.macArm64Dir = "$vcpkgInstallDir/installed/$($triplets[0])"
       $vars.macX64Dir = "$vcpkgInstallDir/installed/$($triplets[1])"
   }
   Write-Debug "$(NL)Initialized vars:"
   Write-Debug (Get-PSObjectAsFormattedList -Object $vars)
   return $vars
}

function Setup-Vcpkg {
   param(
      [string]$repo,
      [string]$repoHash,
      [string]$installDir,
      [string]$cacheDir,
      [string]$bootstrapScript
   )
   Write-Banner -Level 3 -Title "Setting up vcpkg"
   Write-Message "Removing vcpkg..."
   Write-Debug "> Removing vcpkg system cache..."
   Write-Debug ">> Looking for user-specific vcpkg cache dir: $cacheDir"
   if (Test-Path -Path $cacheDir -PathType Container) {
      Write-Debug ">> Deleting dir: $cacheDir"
      Remove-Item -Path $cacheDir -Recurse -Force
   } else {
      Write-Debug ">> Directory not found: $cacheDir"
   }    
   Write-Debug "> Removing dir: vcpkg"
   if (Test-Path -Path $installDir -PathType Container) {
      Write-Debug ">> Directory found. Deleting: $installDir"
      Remove-Item -Path $installDir -Recurse -Force
   } else {
      Write-Debug ">> Directory not found: $installDir, skipping step."
   }

   Write-Message "$(NL)Installing vcpkg..."
   if (Test-Path -Path $installDir -PathType Container) {
       Write-Debug "> Directory already exists: $installDir!!!"
   }
   else
   {
       Write-Debug "> Cloning repo: $repo"
       git clone $repo
       if ($repoHash -ne "") {
           Write-Debug ">> Checking out hash: $repoHash"
           Push-Location vcpkg
           git checkout $repoHash
           Pop-Location
       }

       Write-Debug "> Bootstrapping vcpkg..."
       Push-Location $installDir
       Invoke-Expression "$bootstrapScript"
       Pop-Location
   }
}

function Run-PreBuildScriptIfExists {
   param(
      $script
   )
   Run-ScriptIfExists -title "Pre-build step" -script $script
}

function Run-PostBuildScriptIfExists {
   param(
      $script,
      $preStagePath
   )
   $scriptArgs = @{ BuildArtifactsPath = ((Resolve-Path $preStagePath).Path -replace '\\', '/') }
   Run-ScriptIfExists -title "Post-build step" -script $script -scriptArgs $scriptArgs
}

function Install-Package
{
   param(
      [string]$vcpkgExe,
      [string]$package,
      [PSObject]$triplets
   )
   Write-Banner -Level 3 -Title "Installing package: $package"
   $tripletCount = $triplets.Length
   Write-Message "Installing for $tripletCount triplet(s)..."

   $tripletNum = 1
   foreach ($triplet in $triplets) {
      Write-Message "> Installing for triplet $tripletNum/$tripletCount`: $triplet..."
      Install-FromVcPkg -Package $package -Triplet $triplet -vcpkgExe $vcpkgExe
      Exit-IfError $LASTEXITCODE
      $tripletNum++
   }
}

function Create-FinalArtifacts {
   param(
      [string]$arm64Dir,
      [string]$x64Dir,
      [string]$preStagePath
   )
   if (-not (Get-isOnMacOS)) { return } # This is only required on Mac
   Write-Banner -Level 3 -Title "Creating final Mac artifacts"
   Create-FinalMacArtifacts -arm64Dir "$arm64Dir" -x64Dir "$x64Dir" -universalDir "$preStagePath"
}

function Stage-Artifacts {
   param(
      $vcpkgExe,
      $preStagePath,
      $stagePath,
      $packageNameOnly,
      $artifactName
   )
   
   Write-Banner -Level 3 -Title "Stage build artifacts"

   Write-Debug "Creating dir: $artifactName"
   New-Item -Path $stagePath/$artifactName -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

   $dependenciesFilename = "dependencies.json"
   Write-Debug "Generating: `"$dependenciesFilename`"..."
   Write-Debug "> $stagePath/$artifactName/$dependenciesFilename"
   Invoke-Expression "$vcpkgExe list --x-json > $stagePath/$artifactName/$dependenciesFilename"

   $packageInfoFilename = "package.json"
   Write-Debug "Generating: `"$packageInfoFilename`"..."
   $dependenciesJson = Get-Content -Raw -Path "$stagePath/$artifactName/$dependenciesFilename" | ConvertFrom-Json
   $packageVersion = ($dependenciesJson.PSObject.Properties.Value | Where-Object { $_.package_name -eq $packageNameOnly } | Select-Object -First 1).version
   Write-ReleaseInfoJson -PackageName $packageNameOnly -Version $packageVersion -PathToJsonFile "$stagePath/$artifactName/$packageInfoFilename"
   
   # TODO: Add info in this file on where each package was downloaded from
   # TODO: Add license file info to the staged artifacts (ex. per-library LICENSE, COPYING, or other such files that commonly have license info in them)
   
   Write-Message "Copying: $preStagePath =`> $artifactName"
   $excludedFolders = @("tools", "share", "debug")
   Copy-Item -Path "$preStagePath/*" -Destination $stagePath/$artifactName -Force -Recurse -Exclude $excludedFolders
   
   $artifactArchive = "$artifactName.tar.gz"
   Write-Message "Compressing: `"$artifactName`" =`> `"$artifactArchive`""
   tar -czf "$stagePath/$artifactArchive" -C "$stagePath/$artifactName" .
   
   Write-Debug "Deleting: `"$artifactName`""
   Remove-Item -Path "$stagePath/$artifactName" -Recurse -Force
}

Export-ModuleMember -Function Initialize-Variables
Export-ModuleMember -Function Setup-Vcpkg
Export-ModuleMember -Function Run-PreBuildScriptIfExists
Export-ModuleMember -Function Run-PostBuildScriptIfExists
Export-ModuleMember -Function Install-Package
Export-ModuleMember -Function Create-FinalArtifacts
Export-ModuleMember -Function Stage-Artifacts
Export-ModuleMember -Function Get-PackageInfo

Export-ModuleMember -Function Write-Banner
Export-ModuleMember -Function Write-Message
Export-ModuleMember -Function NL
Export-ModuleMember -Function Get-PSObjectAsFormattedList
Export-ModuleMember -Function Get-IsOnMacOS
Export-ModuleMember -Function Get-IsOnWindowsOS

if ( (Get-IsOnMacOS) ) {
   Import-Module "$PSScriptRoot/../../ps-modules/MacBuild" -DisableNameChecking
   Export-ModuleMember -Function Remove-DylibSymlinks
}
