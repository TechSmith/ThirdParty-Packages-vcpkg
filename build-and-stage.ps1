param(
    [Parameter(Mandatory=$true)][string]$PackageAndFeatures, # Name of package + optional feature flags ("foo" or "foo[feature1,feature2]")
    [Parameter(Mandatory=$true)][string]$LinkType,           # Linking type: static or dynamic
    [string]$BuildType = "release",                          # Build type: release or debug
    [string]$StagedArtifactsPath = "StagedArtifacts",        # Output path to stage these artifacts to
    [string]$ReleaseTagBaseName = "",                        # The base name of the tag to be used when publishing the release (ex. "openssl-static").  If not specified, it will default to "$Package-$LinkType"
    [string]$PackageDisplayName = "",                        # The human-readable name of the package (ex. "openssl (static)").  If not specified, it will default to "$Package-$LinkType"
    [switch]$ShowDebug = $false                              # Show additional debugging information
)

Write-Host "************************************************************"
Write-Host "Starting vcpkg install for: $PackageAndFeatures"
Write-Host "************************************************************"
$allParams = @{
    PackageAndFeatures = $PackageAndFeatures
    BuildType = $BuildType
    LinkType = $LinkType
    StagedArtifactsPath = $StagedArtifactsPath
    ReleaseTagBaseName = $ReleaseTagBaseName
    PackageName = $PackageDisplayName
    ShowDebug = $ShowDebug
}
Write-Host "Parameters:"
foreach ($paramName in $allParams.Keys) {
    $paramValue = $allParams[$paramName]
    Write-Host "- $paramName`: $paramValue"
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Initializing"
Write-Host "============================================================"
Import-Module "$PSScriptRoot/ps-modules/Util"
$vcpkgRepo = "https://github.com/TechSmith/vcpkg.git"
$IsOnWindowsOS = $false # Built-in IsWindows variable not working on Windows agent
$IsOnMacOS = $false
Write-Host "Checking OS..."
$IsOnWindowsOS = Get-IsOnWindowsOS
$IsOnMacOS = Get-IsOnMacOS
if ($IsOnWindowsOS) {
    Write-Host "> Running on: Windows"
} else {
    Write-Host "> Running on: Mac"
}

if ( $IsOnMacOS ) {
   Import-Module "$PSScriptRoot/ps-modules/MacUtil"
}

$packageNameOnly = $PackageAndFeatures -replace '\[.*$', ''
if( $ReleaseTagBaseName -eq "") {
   $ReleaseTagBaseName = "$packageNameOnly-$LinkType"
}
if( $PackageDisplayName -eq "") {
   $PackageDisplayName = "$packageNameOnly-$LinkType"
}

Write-Host ""
Write-Host "Setting other vars based on OS..."
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
} else {
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

Write-Host "- osName: $osName"
Write-Host "- vcpkgExe: $vcpkgExe"
Write-Host "- vcpkgCacheDir: $vcpkgCacheDir"
Write-Host "- vcpkgBootstrapScript: $vcpkgBootstrapScript"
Write-Host "- triplets: $triplets"
Write-Host "- preStagePath: $preStagePath"

Write-Host ""
Write-Host "============================================================"
Write-Host "Setting up vcpkg"
Write-Host "============================================================"
Write-Host "Removing vcpkg system cache..."
Write-Host "> Looking for user-specific vcpkg cache dir: $vcpkgCacheDir"
if (Test-Path -Path $vcpkgCacheDir -PathType Container) {
   Write-Host "> Deleting dir: $vcpkgCacheDir"
   Remove-Item -Path $vcpkgCacheDir -Recurse -Force
} else {
   Write-Host "> Directory not found: $vcpkgCacheDir"
}    

Write-Host ""
Write-Host "Removing dir: vcpkg"
$vcpkgDir = "./vcpkg"
if (Test-Path -Path $vcpkgDir -PathType Container) {
   Write-Host "> Directory found. Deleting: $vcpkgDir"
   Remove-Item -Path $vcpkgDir -Recurse -Force
} else {
   Write-Host "> Directory not found: $vcpkgDir, skipping step."
}

Write-Host ""
Write-Host "Installing vcpkg..."
if (Test-Path -Path $vcpkgDir -PathType Container) {
    Write-Host "> Directory already exists: $vcpkgDir!!!"
}
else
{
    Write-Host "> Cloning repo: $vcpkgRepo"
    git clone $vcpkgRepo

    Write-Host ""
    Write-Host "Bootstrapping vcpkg..."
    Push-Location "vcpkg"
    Invoke-Expression "$vcpkgBootstrapScript"
    Pop-Location
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Pre-build step"
Write-Host "============================================================"
$preBuildScript = "custom-steps/$packageNameOnly/pre-build.ps1"
if (Test-Path -Path $preBuildScript -PathType Leaf) {
   Invoke-Powershell -FilePath $preBuildScript
} else {
    Write-Host "File does not exist: $preBuildScript.  Skipping step..."
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Installing package: $Package"
Write-Host "============================================================"
$tripletCount = $triplets.Length
$tripletNum = 1
foreach ($triplet in $triplets) {
   Write-Host "Installing for triplet $tripletNum/$tripletCount`: $triplet..."
   Install-FromVcPkg -Package $PackageAndFeatures -Triplet $triplet -vcpkgExe $vcpkgExe
   Exit-IfError $LASTEXITCODE
   Write-Host ""
   $tripletNum++
}

if($IsOnMacOS) {
   Write-Host ""
   Write-Host "============================================================"
   Write-Host "Creating universal binary"
   Write-Host "============================================================"
   $arm64Dir = "vcpkg/installed/$($triplets[0])"
   $x64Dir = "vcpkg/installed/$($triplets[1])"
   Write-Host "$arm64Dir, $x64Dir ==> $preStagePath"
   ConvertTo-UniversalBinaries -arm64Dir "$arm64Dir" -x64Dir "$x64Dir" -universalDir "$preStagePath"
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Post-build step"
Write-Host "============================================================"
$postBuildScript = "custom-steps/$packageNameOnly/post-build.ps1"
$preStagePath = (Resolve-Path $preStagePath).Path -replace '\\', '/' # Expand this, so it is an absolute path we are passing to other scripts
if (Test-Path -Path $postBuildScript -PathType Leaf) {
    $scriptArgs = @{ "BuildArtifactsPath" = "$preStagePath" }
    Invoke-Powershell -FilePath $postBuildScript -ArgumentList $scriptArgs
} else {
    Write-Host "File does not exist: $postBuildScript.  Skipping step..."
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Stage build artifacts"
Write-Host "============================================================"
Write-Host "Creating dir: $artifactSubfolder"
New-Item -Path $StagedArtifactsPath/$artifactSubfolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

$dependenciesFilename = "dependencies.json"
Write-Host ""
Write-Host "Generating: `"$dependenciesFilename`"..."
Invoke-Expression "$vcpkgExe list --x-json > $StagedArtifactsPath/$artifactSubfolder/$dependenciesFilename"

$packageInfoFilename = "package.json"
Write-Host ""
Write-Host "Generating: `"$packageInfoFilename`"..."
$dependenciesJson = Get-Content -Raw -Path "$StagedArtifactsPath/$artifactSubfolder/$dependenciesFilename" | ConvertFrom-Json
$packageVersion = ($dependenciesJson.PSObject.Properties.Value | Where-Object { $_.package_name -eq $packageNameOnly } | Select-Object -First 1).version
Write-ReleaseInfoJson -PackageDisplayName $PackageDisplayName -ReleaseTagBaseName $ReleaseTagBaseName -ReleaseVersion $packageVersion -PathToJsonFile "$StagedArtifactsPath/$artifactSubfolder/$packageInfoFilename"

# TODO: Add info in this file on where each package was downloaded from
# TODO: Add license file info to the staged artifacts (ex. per-library LICENSE, COPYING, or other such files that commonly have license info in them)

Write-Host ""
Write-Host "Copying: $preStagePath =`> $artifactSubfolder"
$excludedFolders = @("tools", "share", "debug")
Copy-Item -Path "$preStagePath/*" -Destination $StagedArtifactsPath/$artifactSubfolder -Force -Recurse -Exclude $excludedFolders

Write-Host ""
Write-Host "Compressing: `"$artifactSubfolder`" =`> `"$artifactArchive`""
tar -czf "$StagedArtifactsPath/$artifactArchive" -C "$StagedArtifactsPath/$artifactSubfolder" .

Write-Host ""
Write-Host "Deleting: `"$artifactSubfolder`""
Remove-Item -Path "$StagedArtifactsPath/$artifactSubfolder" -Recurse -Force

if($ShowDebug)
{
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Showing debug info"
    Write-Host "============================================================"
    if($IsOnWindowsOS) {
        # Show Windows debugging info
        Write-Host "No additional debugging information is available."
    }
    else {
        # Show Mac debugging info
        Write-Host "No additional debugging information is available."
    }
}


# Done
Write-Host "`n`nDone."
