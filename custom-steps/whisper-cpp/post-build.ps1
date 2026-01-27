param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$false)][string]$PackageAndFeatures,
    [Parameter(Mandatory=$false)][string]$LinkType,
    [Parameter(Mandatory=$false)][string]$BuildType,
    [Parameter(Mandatory=$false)][string]$ModulesRoot,
    [Parameter(Mandatory=$false)][string[]]$Triplets
)

# Import modules
$moduleNames = @("Build", "Util")
foreach( $moduleName in $moduleNames ) {
    if(-not (Get-Module -Name $moduleName)) {
        Import-Module "$ModulesRoot/$moduleName" -Force -DisableNameChecking
    }
}

if((Get-IsOnWindowsOS)) {
    # Dynamically find the whisper DLL (could be whisper.dll or whisper-basic.dll)
    $binPath = "$BuildArtifactsPath/bin"
    $whisperDll = Get-ChildItem -Path $binPath -Filter "whisper*.dll" -File | Select-Object -First 1
    
    if ($whisperDll) {
        Write-Message "> Found whisper DLL: $($whisperDll.Name)"
        
        # Update version-info.json with the actual DLL name
        $versionInfoPath = "$PSScriptRoot/version-info.json"
        $versionInfo = Get-Content $versionInfoPath | ConvertFrom-Json
        $versionInfo.files[0].filename = "bin/$($whisperDll.Name)"
        $versionInfo | ConvertTo-Json -Depth 10 | Set-Content $versionInfoPath
        
        Update-VersionInfoForDlls -buildArtifactsPath $BuildArtifactsPath -versionInfoJsonPath $versionInfoPath
    }
    else {
        Write-Message "WARNING: No whisper DLL found in $binPath"
    }
}
