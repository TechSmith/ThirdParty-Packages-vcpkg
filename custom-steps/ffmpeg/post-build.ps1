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

Write-Host ">> BuildArtifactsPath: $BuildArtifactsPath"

if ((Get-IsOnMacOS)) {
    Remove-DylibSymlinks -BuildArtifactsPath $BuildArtifactsPath

    # Symlinks aren't in a chain anymore for this lib.  Multiple symlinks point directly to the physical dll.
    # Compensate for this
    Push-Location "$BuildArtifactsPath/lib"
    Get-ChildItem -File | ForEach-Object { if (($_.Attributes -eq "ReparsePoint") -and ($_.Name -like "*.dylib")) { Remove-Item $_.FullName } }
    $renameFiles = @{ 
        "libavcodec.60.dylib" = "libavcodec.dylib";
        "libavdevice.60.dylib" = "libavdevice.dylib";
        "libavfilter.9.dylib" = "libavfilter.dylib";
        "libavformat.60.dylib" = "libavformat.dylib";
        "libavutil.58.dylib" = "libavutil.dylib";
        "libmp3lame.dylib" = "libmp3lame.dylib";
        "libswresample.4.dylib" = "libswresample.dylib";
        "libswscale.7.dylib" = "libswscale.dylib";
    }
    foreach ($key in $renameFiles.Keys) {
        if (Test-Path $key) {
            Rename-Item -Path $key -NewName $renameFiles[$key]
        } else {
            Write-Host "File $key does not exist."
        }
    }
    Pop-Location
}
elseif((Get-IsOnWindowsOS)) {
    Update-VersionInfoForDlls -buildArtifactsPath $buildArtifactsPath -versionInfoJsonPath "$PSScriptRoot/version-info.json"
}

