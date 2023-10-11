param(
    [Parameter(Mandatory=$true)][string]$PackageAndFeatures, # Name of package + optional feature flags ("foo" or "foo[feature1,feature2]")
    [Parameter(Mandatory=$true)][string]$LinkType,           # Linking type: static or dynamic
    [string]$PackageName = "",                               # The base name of the tag to be used when publishing the release (ex. "openssl-static").  If not specified, it will default to "$Package-$LinkType"
    [string]$BuildType = "release",                          # Build type: release or debug
    [string]$StagedArtifactsPath = "StagedArtifacts",        # Output path to stage these artifacts to
    [string]$VcpkgHash = "",                                 # The hash of vcpkg to checkout (if applicable)
    [switch]$ShowDebug = $false                              # Show additional debugging information
)

Import-Module "$PSScriptRoot/ps-modules/Util"

function Write-Debug { 
    param([string]$Message)
    if($ShowDebug) {
        Write-Message $Message
    }
}

function Initialize-Variables {
   $vcpkgRepo = "https://github.com/TechSmith/vcpkg.git"
   $isOnWindowsOS = Get-isOnWindowsOS
   $isOnMacOS = Get-isOnMacOS
   $packageNameOnly = $PackageAndFeatures -replace '\[.*$', ''
   if( $PackageName -eq "") {
      $PackageName = "$packageNameOnly-$LinkType"
   }
   $triplets = @()
   if ($isOnWindowsOS) {
       $osName = "Windows"
       $vcpkgExe = "./vcpkg/vcpkg.exe"
       $vcpkgCacheDir = "$env:LocalAppData\vcpkg\archives"
       $vcpkgBootstrapScript = "./bootstrap-vcpkg.bat"
       $triplets += "x64-windows-$LinkType-$BuildType"
       $preStagePath = "vcpkg/installed/$($triplets[0])"
       $artifactName = "$PackageName-windows-$BuildType"
   } elseif ($isOnMacOS) {
       $osName = "Mac"
       $vcpkgExe = "./vcpkg/vcpkg"
       $vcpkgCacheDir = "$HOME/.cache/vcpkg/archives"
       $vcpkgBootstrapScript = "./bootstrap-vcpkg.sh"
       $triplets += "x64-osx-$LinkType-$BuildType"
       $triplets += "arm64-osx-$LinkType-$BuildType"
       $preStagePath = "universal"
       $artifactName = "$PackageName-osx-$BuildType"
   }

   $vars = @{
       vcpkgRepo = $vcpkgRepo
       vcpkgRepoHash = $VcpkgHash
       vcpkgInstallDir = "./vcpkg"
       vcpkgExe = $vcpkgExe
       vcpkgCacheDir = $vcpkgCacheDir
       vcpkgBootstrapScript = $vcpkgBootstrapScript
       isOnWindowsOS = $isOnWindowsOS
       isOnMacOS = $isOnMacOS
       packageNameOnly = $packageNameOnly
       osName = $osName
       triplets = $triplets
       preStagePath = $preStagePath
       stagePath = $StagedArtifactsPath
       artifactName = $artifactName
       prebuildScript = "custom-steps/$packageNameOnly/pre-build.ps1"
       postbuildScript = "custom-steps/$packageNameOnly/post-build.ps1"
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

function Run-ScriptIfExists {
   param(
      [string]$title,
      [string]$script,
      [PSObject]$scriptArgs
   )
   if ( -not (Test-Path -Path $script -PathType Leaf) ) {
      return
   }
   Write-Banner -Level 3 -Title $title
   Write-Debug "> Executing: $script"
   Invoke-Powershell -FilePath $script -ArgumentList $scriptArgs
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

function Create-UniversalBinaryIfOnMac {
   param(
      $vcpkgInstallDir
   )
   if (-not (Get-isOnMacOS)) { return }
   Write-Banner -Level 3 -Title "Creating universal binary"
   $arm64Dir = "$vcpkgInstallDir/installed/$($triplets[0])"
   $x64Dir = "$vcpkgInstallDir/installed/$($triplets[1])"
   Write-Debug "$arm64Dir, $x64Dir ==> $preStagePath"
   ConvertTo-UniversalBinaries -arm64Dir "$arm64Dir" -x64Dir "$x64Dir" -universalDir "$preStagePath"
}

function Stage-Artifacts {
   param(
      $vcpkgExe,
      $preStagePath,
      $stagePath,
      $artifactName
   )

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
   Write-ReleaseInfoJson -PackageName $PackageName -Version $packageVersion -PathToJsonFile "$stagePath/$artifactName/$packageInfoFilename"
   
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

Write-Banner -Level 2 -Title "Starting vcpkg install for: $PackageAndFeatures"
Write-Message "Params:"
Write-Message (Get-PSObjectAsFormattedList -Object $PSBoundParameters)
$vars = Initialize-Variables

Write-Banner -Level 3 -Title "Setting up vcpkg"
Setup-VcPkg -repo $vars.vcpkgRepo -repoHash $vars.vcpkgRepoHash -installDir $vars.vcpkgInstallDir -cacheDir $vars.vcpkgCacheDir -bootstrapScript $vars.vcpkgBootstrapScript

Run-PreBuildScriptIfExists -script $vars.prebuildScript

Write-Banner -Level 3 -Title "Installing package: $PackageAndFeatures"
Install-Package -vcpkgExe $vars.vcpkgExe -package $PackageAndFeatures -triplets $vars.triplets

Create-UniversalBinaryIfOnMac

Run-PostBuildScriptIfExists -script $vars.postbuildScript -preStagePath $vars.preStagePath

Write-Banner -Level 3 -Title "Stage build artifacts"
Stage-Artifacts -vcPkgExe $vars.vcpkgExe -preStagePath $vars.preStagePath -stagePath $vars.stagePath -artifactName $vars.artifactName

Write-Message "$(NL)$(NL)Done."
