param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$false)][string]$PortAndFeatures,
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

if( Check-IsEmscriptenBuild -triplets $Triplets ) {
   Exit 0
}

$pathToTools = "$BuildArtifactsPath/tools/ffmpeg"
$pathToFFmpegExe = ""
if((Get-IsOnWindowsOS)) {
    Update-VersionInfoForDlls -buildArtifactsPath $buildArtifactsPath -versionInfoJsonPath "$PSScriptRoot/version-info.json"
    $pathToFFmpegExe = "$pathToTools/ffmpeg.exe"
}

if((Get-IsOnMacOS)) {
    Write-Message  "> Updating library paths in /tools/ffmpeg/..."
    $folderPath = "$buildArtifactsPath/tools/ffmpeg/"
    $files = Get-ChildItem -Path $folderPath -Attributes !Hidden
    foreach ($binaryPath in $files) {
        Write-Output "   > Updating: $binaryPath"
        $otoolOutput = & "otool" "-L" $binaryPath
        foreach ($line in $otoolOutput) {
            if ($line -match '@rpath\/([^\.]+)\.[^\/]*\.dylib') {
                $originalPath = $matches[0]
                $newPath = "@rpath/$($matches[1]).dylib"
                Write-Output "      >> Updating $originalPath to $newPath"
                & "install_name_tool" "-change" $originalPath $newPath $binaryPath
            }
        }
    }
    $pathToFFmpegExe = "$pathToTools/ffmpeg"
}

# Expand/flatten feature flags, so we have them all in one big list
$vcpkgExe = "$PSScriptRoot/../../$(Get-VcPkgExe)"
$pathToCustomPorts = "$PSScriptRoot/../../custom-ports"
$vcpkgCommand = "$vcpkgExe install $PortAndFeatures --overlay-ports '$pathToCustomPorts' --dry-run"
$dryRunOutput = Invoke-Expression $vcpkgCommand
$ffmpegPortAndFeaturesExpanded = ($dryRunOutput -split "`n" | Select-String -Pattern 'ffmpeg\[[^\]]+\]').Matches.Value

# Run tests
Write-Message "$(NL)Running post-build tests..."
$finalExitCode = 0
$testScriptArgs = @{ 
  BuildArtifactsPath = $BuildArtifactsPath
  PortAndFeatures = $ffmpegPortAndFeaturesExpanded
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
