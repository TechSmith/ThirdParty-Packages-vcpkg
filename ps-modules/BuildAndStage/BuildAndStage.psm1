Import-Module "$PSScriptRoot/../../ps-modules/Util" -DisableNameChecking

function Write-Debug { 
    param(
       [string]$message,
       [switch]$showDebug = $false
    )
    if($showDebug) {
        Write-Message $message
    }
}

function Initialize-Variables {
   param(
      [Parameter(Mandatory=$true)][string]$packageAndFeatures,
      [Parameter(Mandatory=$true)][string]$linkType,
      [string]$packageName = "",
      [string]$buildType = "release",
      [string]$stagedArtifactsPath = "StagedArtifacts",
      [string]$vcpkgHash = "",
      [switch]$showDebug = $false
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
       $vcpkgCacheDir = "$env:LocalAppData\vcpkg\archives"
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
   Write-Debug -showDebug:$showDebug -message "$(NL)Initialized vars:"
   Write-Debug -showDebug:$showDebug -message (Get-PSObjectAsFormattedList -Object $vars)
   return $vars
}

function Setup-Vcpkg {
   param(
      [string]$repo,
      [string]$repoHash,
      [string]$installDir,
      [string]$cacheDir,
      [string]$bootstrapScript,
      [switch]$showDebug = $false
   )
   Write-Banner -Level 3 -Title "Setting up vcpkg"
   Write-Message "Removing vcpkg..."
   Write-Debug -showDebug:$showDebug -message "> Removing vcpkg system cache..."
   Write-Debug -showDebug:$showDebug -message ">> Looking for user-specific vcpkg cache dir: $cacheDir"
   if (Test-Path -Path $cacheDir -PathType Container) {
      Write-Debug -showDebug:$showDebug -message ">> Deleting dir: $cacheDir"
      Remove-Item -Path $cacheDir -Recurse -Force
   } else {
      Write-Debug -showDebug:$showDebug -message ">> Directory not found: $cacheDir"
   }    
   Write-Debug -showDebug:$showDebug -message "> Removing dir: vcpkg"
   if (Test-Path -Path $installDir -PathType Container) {
      Write-Debug -showDebug:$showDebug -message ">> Directory found. Deleting: $installDir"
      Remove-Item -Path $installDir -Recurse -Force
   } else {
      Write-Debug -showDebug:$showDebug -message ">> Directory not found: $installDir, skipping step."
   }

   Write-Message "$(NL)Installing vcpkg..."
   if (Test-Path -Path $installDir -PathType Container) {
       Write-Debug -showDebug:$showDebug -message "> Directory already exists: $installDir!!!"
   }
   else
   {
       Write-Debug -showDebug:$showDebug -message "> Cloning repo: $repo"
       git clone $repo
       if ($repoHash -ne "") {
           Write-Debug -showDebug:$showDebug -message ">> Checking out hash: $repoHash"
           Push-Location vcpkg
           git checkout $repoHash
           Pop-Location
       }

       Write-Debug -showDebug:$showDebug -message "> Bootstrapping vcpkg..."
       Push-Location $installDir
       Invoke-Expression "$bootstrapScript"
       Pop-Location
   }
}

function Run-ScriptIfExists {
   param(
      [string]$title,
      [string]$script,
      [PSObject]$scriptArgs,
      [switch]$showDebug = $false
   )
   if ( -not (Test-Path -Path $script -PathType Leaf) ) {
      return
   }
   Write-Banner -Level 3 -Title $title
   Write-Debug -showDebug:$showDebug -message "> Executing: $script"
   Invoke-Powershell -FilePath $script -ArgumentList $scriptArgs
}

function Run-PreBuildScriptIfExists {
   param(
      $script,
      [switch]$showDebug = $false
   )
   Run-ScriptIfExists -title "Pre-build step" -script $script
}

function Run-PostBuildScriptIfExists {
   param(
      $script,
      $preStagePath,
      [switch]$showDebug = $false
   )
   $scriptArgs = @{ BuildArtifactsPath = ((Resolve-Path $preStagePath).Path -replace '\\', '/') }
   Run-ScriptIfExists -title "Post-build step" -script $script -scriptArgs $scriptArgs
}

function Install-Package
{
   param(
      [string]$vcpkgExe,
      [string]$package,
      [PSObject]$triplets,
      [switch]$showDebug = $false
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

function ConvertTo-UniversalBinaryIfOnMac {
   param(
      [string]$vcpkgInstallDir,
      [string]$preStagePath,
      [string]$arm64Dir,
      [string]$x64Dir,
      [switch]$showDebug = $false
   )
   if (-not (Get-isOnMacOS)) { return }
   Write-Banner -Level 3 -Title "Creating universal binary"
   Write-Debug -showDebug:$showDebug -message "$arm64Dir, $x64Dir ==> $preStagePath"
   ConvertTo-UniversalBinaries -arm64Dir "$arm64Dir" -x64Dir "$x64Dir" -universalDir "$preStagePath"
}

function Stage-Artifacts {
   param(
      $vcpkgExe,
      $preStagePath,
      $stagePath,
      $artifactName,
      [switch]$showDebug = $false
   )
   
   Write-Banner -Level 3 -Title "Stage build artifacts"

   Write-Debug -showDebug:$showDebug -message "Creating dir: $artifactName"
   New-Item -Path $stagePath/$artifactName -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

   $dependenciesFilename = "dependencies.json"
   Write-Debug -showDebug:$showDebug -message "Generating: `"$dependenciesFilename`"..."
   Write-Debug -showDebug:$showDebug -message "> $stagePath/$artifactName/$dependenciesFilename"
   Invoke-Expression "$vcpkgExe list --x-json > $stagePath/$artifactName/$dependenciesFilename"

   $packageInfoFilename = "package.json"
   Write-Debug -showDebug:$showDebug -message "Generating: `"$packageInfoFilename`"..."
   $dependenciesJson = Get-Content -Raw -Path "$stagePath/$artifactName/$dependenciesFilename" | ConvertFrom-Json
   $packageVersion = ($dependenciesJson.PSObject.Properties.Value | Where-Object { $_.package_name -eq $packageNameOnly } | Select-Object -First 1).version
   Write-ReleaseInfoJson -PackageName $packageName -Version $packageVersion -PathToJsonFile "$stagePath/$artifactName/$packageInfoFilename"
   
   # TODO: Add info in this file on where each package was downloaded from
   # TODO: Add license file info to the staged artifacts (ex. per-library LICENSE, COPYING, or other such files that commonly have license info in them)
   
   Write-Message "Copying: $preStagePath =`> $artifactName"
   $excludedFolders = @("tools", "share", "debug")
   Copy-Item -Path "$preStagePath/*" -Destination $stagePath/$artifactName -Force -Recurse -Exclude $excludedFolders
   
   $artifactArchive = "$artifactName.tar.gz"
   Write-Message "Compressing: `"$artifactName`" =`> `"$artifactArchive`""
   tar -czf "$stagePath/$artifactArchive" -C "$stagePath/$artifactName" .
   
   Write-Debug -showDebug:$showDebug -message "Deleting: `"$artifactName`""
   Remove-Item -Path "$stagePath/$artifactName" -Recurse -Force
}

Export-ModuleMember -Function Initialize-Variables
Export-ModuleMember -Function Setup-Vcpkg
Export-ModuleMember -Function Run-PreBuildScriptIfExists
Export-ModuleMember -Function Run-PostBuildScriptIfExists
Export-ModuleMember -Function Install-Package
Export-ModuleMember -Function ConvertTo-UniversalBinaryIfOnMac
Export-ModuleMember -Function Stage-Artifacts

Export-ModuleMember -Function Write-Banner
Export-ModuleMember -Function Write-Message
Export-ModuleMember -Function NL
Export-ModuleMember -Function Get-PSObjectAsFormattedList
