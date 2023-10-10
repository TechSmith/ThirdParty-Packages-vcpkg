param(
    [Parameter(Mandatory=$true)][string]$PackageAndFeatures, # Name of package + optional feature flags ("foo" or "foo[feature1,feature2]")
    [Parameter(Mandatory=$true)][string]$LinkType,           # Linking type: static or dynamic
    [string]$BuildType = "release",                          # Build type: release or debug
    [string]$StagedArtifactsPath = "StagedArtifacts",        # Output path to stage these artifacts to
    [string]$ReleaseTagBaseName = "",                        # The base name of the tag to be used when publishing the release (ex. "openssl-static").  If not specified, it will default to "$Package-$LinkType"
    [string]$PackageDisplayName = "",                        # The human-readable name of the package (ex. "openssl (static)").  If not specified, it will default to "$Package-$LinkType"
    [string]$VcpkgHash = "",                                 # The hash of vcpkg to checkout (if applicable)
    [switch]$ShowDebug = $false                              # Show additional debugging information
)

Import-Module "$PSScriptRoot/ps-modules/Util"

Write-Banner -Level 2 -Title "Starting vcpkg install for: $PackageAndFeatures"
$allParams = @{
    PackageAndFeatures = $PackageAndFeatures
    LinkType = $LinkType
    BuildType = $BuildType
    StagedArtifactsPath = $StagedArtifactsPath
    ReleaseTagBaseName = $ReleaseTagBaseName
    PackageName = $PackageDisplayName
    VcpkgHash = $VcpkgHash
    ShowDebug = $ShowDebug
}
Write-Message "Parameters:"
foreach ($paramName in $allParams.Keys) {
    $paramValue = $allParams[$paramName]
    Write-Message "- $paramName`: $paramValue"
}

Write-Banner -Level 3 -Title "Initializing"
$vcpkgRepo = "https://github.com/TechSmith/vcpkg.git"
$IsOnWindowsOS = Get-IsOnWindowsOS
$IsOnMacOS = Get-IsOnMacOS

$packageNameOnly = $PackageAndFeatures -replace '\[.*$', ''
if( $ReleaseTagBaseName -eq "") {
   $ReleaseTagBaseName = "$packageNameOnly-$LinkType"
}
if( $PackageDisplayName -eq "") {
   $PackageDisplayName = "$packageNameOnly-$LinkType"
}

$osName = ""
$vcpkgExe = ""
$vcpkgCacheDir = ""
$vcpkgBootstrapScript = ""
$preStagePath = ""
$triplets = @()
if ($IsOnWindowsOS) {
   $osName = "Windows"
   $vcpkgExe = "./vcpkg/vcpkg.exe"
   $vcpkgCacheDir = "$env:LocalAppData\vcpkg\archives"
   $vcpkgBootstrapScript = "./bootstrap-vcpkg.bat"
   $triplets += "x64-windows-$LinkType-$BuildType"
   $preStagePath = "vcpkg/installed/$($triplets[0])"
   $artifactSubfolder = "$ReleaseTagBaseName-windows-$BuildType"
} elseif ($IsOnMacOS) {
   $osName = "Mac"
   $vcpkgExe = "./vcpkg/vcpkg"
   $vcpkgCacheDir = "$HOME/.cache/vcpkg/archives"
   $vcpkgBootstrapScript = "./bootstrap-vcpkg.sh"
   $triplets += "x64-osx-$LinkType-$BuildType"
   $triplets += "arm64-osx-$LinkType-$BuildType"
   $preStagePath = "universal"
   $artifactSubfolder = "$ReleaseTagBaseName-osx-$BuildType"
}
$artifactArchive = "$artifactSubfolder.tar.gz"

$initParams = @{
   vcpkgRepo = $vcpkgRepo
   IsOnWindowsOS = $IsOnWindowsOS
   IsOnMacOS = $IsOnMacOS
   packageNameOnly = $packageNameOnly
   osName = $osName
   vcpkgExe = $vcpkgExe
   vcpkgCacheDir = $vcpkgCacheDir
   vcpkgBootstrapScript = $vcpkgBootstrapScript
   triplets = $triplets
   preStagePath = $preStagePath
   artifactSubfolder = $artifactSubfolder
}

Write-Message "Initialized vars:"
foreach ($paramName in $initParams.Keys) {
    $paramValue = $initParams[$paramName]
    Write-Message "- $paramName`: $paramValue"
}

Write-Banner -Level 3 -Title "Setting up vcpkg"
Write-Message "Removing vcpkg system cache..."
Write-Message "> Looking for user-specific vcpkg cache dir: $vcpkgCacheDir"
if (Test-Path -Path $vcpkgCacheDir -PathType Container) {
   Write-Message "> Deleting dir: $vcpkgCacheDir"
   Remove-Item -Path $vcpkgCacheDir -Recurse -Force
} else {
   Write-Message "> Directory not found: $vcpkgCacheDir"
}    

Write-Message "$(NL)Removing dir: vcpkg"
$vcpkgDir = "./vcpkg"
if (Test-Path -Path $vcpkgDir -PathType Container) {
   Write-Message "> Directory found. Deleting: $vcpkgDir"
   Remove-Item -Path $vcpkgDir -Recurse -Force
} else {
   Write-Message "> Directory not found: $vcpkgDir, skipping step."
}

Write-Message "$(NL)Installing vcpkg..."
if (Test-Path -Path $vcpkgDir -PathType Container) {
    Write-Message "> Directory already exists: $vcpkgDir!!!"
}
else
{
    Write-Message "> Cloning repo: $vcpkgRepo"
    git clone $vcpkgRepo
    if ($VcpkgHash -ne "") {
        Write-Message "> Using hash: $VcpkgHash"
        Push-Location vcpkg
        git checkout $VcpkgHash
        Pop-Location
    }

    Write-Message "$(NL)Bootstrapping vcpkg..."
    Push-Location "vcpkg"
    Invoke-Expression "$vcpkgBootstrapScript"
    Pop-Location
}

Write-Banner -Level 3 -Title "Pre-build step"
$preBuildScript = "custom-steps/$packageNameOnly/pre-build.ps1"
if (Test-Path -Path $preBuildScript -PathType Leaf) {
   Invoke-Powershell -FilePath $preBuildScript
} else {
   Write-Message "File does not exist: $preBuildScript.  Skipping step..."
}
[Console]::Out.Flush()

Write-Banner -Level 3 -Title "Installing package: $PackageAndFeatures"
$tripletCount = $triplets.Length
$tripletNum = 1
foreach ($triplet in $triplets) {
   Write-Message "Installing for triplet $tripletNum/$tripletCount`: $triplet..."
   Install-FromVcPkg -Package $PackageAndFeatures -Triplet $triplet -vcpkgExe $vcpkgExe
   Exit-IfError $LASTEXITCODE
   $tripletNum++
}

if($IsOnMacOS) {
   Write-Banner -Level 3 -Title "Creating universal binary"
   $arm64Dir = "vcpkg/installed/$($triplets[0])"
   $x64Dir = "vcpkg/installed/$($triplets[1])"
   Write-Message "$arm64Dir, $x64Dir ==> $preStagePath"
   ConvertTo-UniversalBinaries -arm64Dir "$arm64Dir" -x64Dir "$x64Dir" -universalDir "$preStagePath"
}

Write-Banner -Level 3 -Title "Post-build step"
$postBuildScript = "custom-steps/$packageNameOnly/post-build.ps1"
$preStagePath = (Resolve-Path $preStagePath).Path -replace '\\', '/' # Expand this, so it is an absolute path we are passing to other scripts
if (Test-Path -Path $postBuildScript -PathType Leaf) {
    $scriptArgs = @{ "BuildArtifactsPath" = "$preStagePath" }
    Invoke-Powershell -FilePath $postBuildScript -ArgumentList $scriptArgs
} else {
    Write-Message "File does not exist: $postBuildScript.  Skipping step..."
}

Write-Banner -Level 3 -Title "Stage build artifacts"
Write-Message "Creating dir: $artifactSubfolder"
New-Item -Path $StagedArtifactsPath/$artifactSubfolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

$dependenciesFilename = "dependencies.json"
Write-Message "$(NL)Generating: `"$dependenciesFilename`"..."
Invoke-Expression "$vcpkgExe list --x-json > $StagedArtifactsPath/$artifactSubfolder/$dependenciesFilename"

$packageInfoFilename = "package.json"
Write-Message "$(NL)Generating: `"$packageInfoFilename`"..."
$dependenciesJson = Get-Content -Raw -Path "$StagedArtifactsPath/$artifactSubfolder/$dependenciesFilename" | ConvertFrom-Json
$packageVersion = ($dependenciesJson.PSObject.Properties.Value | Where-Object { $_.package_name -eq $packageNameOnly } | Select-Object -First 1).version
Write-ReleaseInfoJson -PackageDisplayName $PackageDisplayName -ReleaseTagBaseName $ReleaseTagBaseName -ReleaseVersion $packageVersion -PathToJsonFile "$StagedArtifactsPath/$artifactSubfolder/$packageInfoFilename"

# TODO: Add info in this file on where each package was downloaded from
# TODO: Add license file info to the staged artifacts (ex. per-library LICENSE, COPYING, or other such files that commonly have license info in them)

Write-Message "$(NL)Copying: $preStagePath =`> $artifactSubfolder"
$excludedFolders = @("tools", "share", "debug")
Copy-Item -Path "$preStagePath/*" -Destination $StagedArtifactsPath/$artifactSubfolder -Force -Recurse -Exclude $excludedFolders

Write-Message "$(NL)Compressing: `"$artifactSubfolder`" =`> `"$artifactArchive`""
tar -czf "$StagedArtifactsPath/$artifactArchive" -C "$StagedArtifactsPath/$artifactSubfolder" .

Write-Message "$(NL)Deleting: `"$artifactSubfolder`""
Remove-Item -Path "$StagedArtifactsPath/$artifactSubfolder" -Recurse -Force

if($ShowDebug)
{
    Write-Banner -Level 3 -Title "Showing debug info"
    if($IsOnWindowsOS) {
        # Show Windows debugging info
        Write-Message "No additional debugging information is available."
    }
    else {
        # Show Mac debugging info
        Write-Message "No additional debugging information is available."
    }
}

# Done
Write-Message "$(NL)$(NL)Done."
