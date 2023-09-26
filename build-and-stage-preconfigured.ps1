param(
    [Parameter(Mandatory=$true)][string]$PackageDisplayName, # Name of package from preconfigured-packages.json
    [string]$StagedArtifactsPath = "StagedArtifacts"  # Output path to stage these artifacts to
)
 
$jsonFilePath = "preconfigured-packages.json"

Write-Host ""
Write-Host "************************************************************"
Write-Host "Installing preconfigured package: `"$PackageDisplayName`""
Write-Host "************************************************************"
Write-Host "Reading config from: `"$jsonFilePath`""
$packagesJson = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json
$packageInfo = $packagesJson.packages | Where-Object { $_.name -eq $PackageDisplayName }
if (-not $packageInfo) {
    Write-Host "> Package not found in $jsonFilePath."
    exit
}
if ($env:OS -like '*win*') {
    $IsOnWindowsOS = $true
} else {
    $IsOnMacOS = $true
}
$tagBaseName = $packageInfo.tag
$selectedSection = if ($IsOnWindowsOS) { "win" } else { "mac" }
$packageAndFeatures = $packageInfo.$selectedSection.package
$linkType = $packageInfo.$selectedSection.linkType
$buildType = $packageInfo.$selectedSection.buildType

Write-Host ""
Write-Host "Variables set based on config for OS `"$selectedSection`":"
$allParams = @{
    PackageDisplayName = $PackageDisplayName
    packageAndFeatures = $packageAndFeatures
    linkType = $linkType
    buildType = $buildType
    tagBaseName = $tagBaseName
}
Write-Host "Parameters:"
foreach ($paramName in $allParams.Keys) {
    $paramValue = $allParams[$paramName]
    Write-Host "- $paramName`: $paramValue"
}

Write-Host ""
Write-Host "Running build-and-stage.ps1..."
Write-Host ""
./build-and-stage.ps1 -PackageAndFeatures $packageAndFeatures -LinkType $linkType -BuildType $buildType -StagedArtifactsPath $StagedArtifactsPath -ReleaseTagBaseName $tagBaseName -PackageDisplayName $PackageDisplayName
