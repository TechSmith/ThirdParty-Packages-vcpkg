param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$false)][string]$PackageAndFeatures,
    [Parameter(Mandatory=$false)][string]$LinkType,
    [Parameter(Mandatory=$false)][string]$BuildType,
    [Parameter(Mandatory=$false)][string]$ModulesRoot    
)

$moduleName = "Build"
if(-not (Get-Module -Name $moduleName)) {
    Import-Module "$ModulesRoot/$moduleName" -Force -DisableNameChecking
}

if((Get-IsOnWindowsOS)) {
    if($LinkType -eq "dynamic") {
        Update-VersionInfoForDlls -buildArtifactsPath $BuildArtifactsPath -versionInfoJsonPath "$PSScriptRoot/version-info.json"
    }
    else {
        Write-Message "LinkType is not `"dynamic`".  Skipping post-build step..."
    }
}
