param(
    [Parameter(Mandatory=$true)]
    [string]$PackageName,
    [string]$TargetPlatform,
    [string]$OverlayPortsPath = 'custom-ports',
    [string]$VcpkgHash = "",                         # The hash of vcpkg to checkout (if applicable)
    [PSObject]$RunCleanup = $true                    # If true, will cleanup files from previous runs and re-clone vcpkg
)

Import-Module "$PSScriptRoot/../ps-modules/Build" -Force -DisableNameChecking
if($RunCleanup) {
    Run-CleanupStep
    Run-SetupVcPkgStep $VcPkgHash
}
$portVersion = Get-PackageMainPortVersion -packageName $PackageName -targetPlatform $targetPlatform -overlayPortsPath $OverlayPortsPath
Write-Host "> Main port version for $PackageName is: $portVersion"
Write-Host "##vso[task.setvariable variable=mainPortVersion]$mainPortVersion"
