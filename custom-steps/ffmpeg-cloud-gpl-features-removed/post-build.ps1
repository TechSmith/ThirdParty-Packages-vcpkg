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

$pathToTools = "$BuildArtifactsPath/tools/ffmpeg"
$pathToFFmpegExe = "$pathToTools/ffmpeg.exe"

if(Get-IsOnLinux){
    $pathToFFmpegExe = "$pathToTools/ffmpeg"
}

# Expand/flatten feature flags, so we have them all in one big list
$vcpkgExe = "$PSScriptRoot/../../$(Get-VcPkgExe)"
$pathToCustomPorts = "$PSScriptRoot/../../custom-ports"
$vcpkgCommand = "$vcpkgExe install $PackageAndFeatures --overlay-ports '$pathToCustomPorts' --dry-run"
$dryRunOutput = Invoke-Expression $vcpkgCommand
$ffmpegPackageAndFeaturesExpanded = ($dryRunOutput -split "`n" | Select-String -Pattern 'ffmpeg-cloud-gpl-features-removed\[[^\]]+\]').Matches.Value

# Run tests
Write-Message "$(NL)Running post-build tests..."
Write-Message "Debug: BuildArtifactsPath = $BuildArtifactsPath"
Write-Message "Debug: ffmpegPackageAndFeaturesExpanded = $ffmpegPackageAndFeaturesExpanded"
Write-Message "Debug: ModulesRoot = $ModulesRoot"
Write-Message "Debug: pathToFFmpegExe = $pathToFFmpegExe"
Write-Message "Debug: PSScriptRoot = $PSScriptRoot"
Write-Message "Debug: testScriptArgs = $testScriptArgs"
Write-Message "Debug: PackageAndFeatures = $PackageAndFeatures"
Write-Message "Debug: dryRunOutput = $dryRunOutput"

$finalExitCode = 0
$testScriptArgs = @{ 
  BuildArtifactsPath = $BuildArtifactsPath
  PackageAndFeatures = $ffmpegPackageAndFeaturesExpanded
  ModulesRoot = $ModulesRoot
  FFMpegExePath = $pathToFFmpegExe
  OutputDir = "test-output"
}
Push-Location $PSScriptRoot
if (Test-Path $testScriptArgs.OutputDir) {
  Remove-Item -Path $testScriptArgs.OutputDir -Recurse -Force
}

$testScripts = @(
   "test001--query-capabilities.ps1"
   "test002--verify-decoding.ps1"
   "test003--verify-encoding.ps1"
   "test004--verify-filters.ps1"
)
foreach($testScript in $testScripts) {
   Write-Message "$(NL)Running tests: $testScript..."
   Invoke-Powershell -FilePath "$testScript" -ArgumentList $testScriptArgs
   $scriptReturnCode = $LASTEXITCODE
   if ( ($finalExitCode -eq 0) -and ($returnCode -ne 0) ) {
       $finalExitCode = $scriptReturnCode
   }
}

Pop-Location

Exit $finalExitCode
