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

if ((Get-IsOnMacOS)) {
    Remove-DylibSymlinks -BuildArtifactsPath $BuildArtifactsPath

    Write-Host "Generate .dSYM files & stripping debug symbols..."
    Push-Location "$BuildArtifactsPath/lib"
    $libraries = (Get-ChildItem -Path . -Filter "*.dylib")
    foreach($library in $libraries) {
        Write-Host "Running dsymutil on: $($library.Name)..."
        dsymutil $library.Name -o ($library.Name + ".dSYM")
        Write-Host "Running strip on: $($library.Name)..."
        strip $library.Name
    }
    Pop-Location
}
elseif((Get-IsOnWindowsOS)) {
    Update-VersionInfoForDlls -buildArtifactsPath $buildArtifactsPath -versionInfoJsonPath "$PSScriptRoot/version-info.json"
}
