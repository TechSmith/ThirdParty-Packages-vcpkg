param(
    [Parameter(Mandatory=$true)][string]$PackageDisplayName, # Name of package from preconfigured-packages.json
    [string]$StagedArtifactsPath = "StagedArtifacts"  # Output path to stage these artifacts to
)

Import-Module "$PSScriptRoot/ps-modules/Util" -Force
 
Write-Banner -Level 1 -Title "Installing preconfigured package: `"$PackageDisplayName`""

$jsonFilePath = "preconfigured-packages.json"
Write-Message "Reading config from: `"$jsonFilePath`""
$packagesJson = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json
$packageInfo = $packagesJson.packages | Where-Object { $_.name -eq $PackageDisplayName }
if (-not $packageInfo) {
    Write-Message "> Package not found in $jsonFilePath."
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
$vcpkgHash = $packageInfo.$selectedSection.vcpkgHash

Write-Message "$(NL)Variables set based on config for OS `"$selectedSection`":"
$allParams = @{
    PackageDisplayName = $PackageDisplayName
    packageAndFeatures = $packageAndFeatures
    LinkType = $linkType
    BuildType = $buildType
    ReleaseTagBaseName = $tagBaseName
    VcpkgHash = $vcpkgHash
}
Write-Message "Parameters:"
foreach ($paramName in $allParams.Keys) {
    $paramValue = $allParams[$paramName]
    Write-Host "- $paramName`: $paramValue"
}

Write-Message "$(NL)Running build-and-stage.ps1...$(NL)"
./build-and-stage.ps1 -PackageAndFeatures $packageAndFeatures -LinkType $linkType -BuildType $buildType -StagedArtifactsPath $StagedArtifactsPath -ReleaseTagBaseName $tagBaseName -PackageDisplayName $PackageDisplayName -VcpkgHash $vcpkgHash
