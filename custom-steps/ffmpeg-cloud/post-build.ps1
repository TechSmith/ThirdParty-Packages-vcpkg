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
    Update-VersionInfoForDlls -buildArtifactsPath $buildArtifactsPath -versionInfoJsonPath "$PSScriptRoot/version-info.json"
    Get-ChildItem $buildArtifactsPath -Recurse -Filter *.exe | Move-Item -Destination $buildArtifactsPath
    Remove-Item -Recurse -Force "$buildArtifactsPath/tools"
}

if((Get-IsOnLinux)) {
    Get-ChildItem $buildArtifactsPath -Recurse -Include ffmpeg, ffprobe, lame -File | Move-Item -Destination $buildArtifactsPath
    Remove-Item -Recurse -Force "$buildArtifactsPath/tools"
}

