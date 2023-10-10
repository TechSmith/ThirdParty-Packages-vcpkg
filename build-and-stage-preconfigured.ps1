param(
    [Parameter(Mandatory=$true)][string]$PackageName, # Name of package from preconfigured-packages.json
    [string]$StagedArtifactsPath = "StagedArtifacts"  # Output path to stage these artifacts to
)

Import-Module "$PSScriptRoot/ps-modules/Util" -Force
 
Write-Banner -Level 1 -Title "Installing preconfigured package: `"$PackageName`""

$jsonFilePath = "preconfigured-packages.json"
Write-Message "Reading config from: `"$jsonFilePath`""
$packagesJson = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json
$pkg = $packagesJson.packages | Where-Object { $_.name -eq $PackageName }
if (-not $pkg) {
    Write-Message "> Package not found in $jsonFilePath."
    exit
}
if ($env:OS -like '*win*') {
    $IsOnWindowsOS = $true
} else {
    $IsOnMacOS = $true
}
$selectedSection = if ($IsOnWindowsOS) { "win" } else { "mac" }
$osPkg = $pkg.$selectedSection
$packageAndFeatures = $osPkg.package
$linkType = $osPkg.linkType
$buildType = $osPkg.buildType
$vcpkgHash = $osPkg.vcpkgHash

Write-Message "$(NL)Variables set based on config for OS `"$selectedSection`":"
$allParams = @{
    PackageName = $PackageName
    PackageAndFeatures = $packageAndFeatures
    LinkType = $linkType
    BuildType = $buildType
    VcpkgHash = $vcpkgHash
}
Write-Message "Parameters:"
foreach ($paramName in $allParams.Keys) {
    $paramValue = $allParams[$paramName]
    Write-Host "- $paramName`: $paramValue"
}

Write-Message "$(NL)Running build-and-stage.ps1...$(NL)"
./build-and-stage.ps1 -PackageName $PackageName -PackageAndFeatures $PackageAndFeatures -LinkType $linkType -BuildType $buildType -StagedArtifactsPath $StagedArtifactsPath -VcpkgHash $vcpkgHash
