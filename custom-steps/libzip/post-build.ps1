param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$false)][string]$PackageAndFeatures,
    [Parameter(Mandatory=$false)][string]$LinkType,
    [Parameter(Mandatory=$false)][string]$BuildType
)

if ((Get-IsOnMacOS)) {
    Remove-DylibSymlinks -BuildArtifactsPath $BuildArtifactsPath
}
elseif((Get-IsOnWindowsOS)) {
    if($LinkType -eq "dynamic") {
        Update-VersionInfoForDlls -buildArtifactsPath $BuildArtifactsPath -versionInfoJsonPath "$PSScriptRoot/version-info.json"
    }
    else {
        Write-Message "LinkType is not `"dynamic`".  Skipping post-build step..."
    }
}
