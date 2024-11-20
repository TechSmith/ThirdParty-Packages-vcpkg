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
}

if((Get-IsOnMacOS)) {
    Write-Host "Updating library paths in ffmpeg executable..."
    $binaryPath = "$buildArtifactsPath/tools/ffmpeg/ffmpeg"
    $otoolOutput = & "otool" "-L" $binaryPath
    foreach ($line in $otoolOutput) {
        if ($line -match '@rpath\/([^\.]+)\.[^\/]*\.dylib') {
            $originalPath = $matches[0]
            $newPath = "@rpath/$($matches[1]).dylib"
    
            Write-Output ">> Updating $originalPath to $newPath"
            & "install_name_tool" "-change" $originalPath $newPath $binaryPath
        }
    }
}

