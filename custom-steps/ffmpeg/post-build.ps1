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
    Write-Message "> Updating library paths in ffmpeg executable..."
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
    $pathToFFmpegExe = "$pathToTools/ffmpeg"
}

Write-Message "$(NL)Running post-build tests..."
$finalExitCode = 0
$testScriptArgs = @{ 
  BuildArtifactsPath = $BuildArtifactsPath
  PackageAndFeatures = $PackageAndFeatures
  ModulesRoot = $ModulesRoot
  FFMpegExePath = $pathToFFmpegExe
  OutputDir = "test-output"
}
Push-Location $PSScriptRoot
if (Test-Path $testScriptArgs.OutputDir) {
  Remove-Item -Path $testScriptArgs.OutputDir -Recurse -Force
}
Invoke-Powershell -FilePath "test001--query-capabilities.ps1" -ArgumentList $testScriptArgs
$scriptReturnCode = $LASTEXITCODE
Write-Host "$(NL)> Script exit code = $scriptReturnCode"
if ( ($finalExitCode -eq 0) -and ($returnCode -ne 0) ) {
    $finalExitCode = $scriptReturnCode
}

Invoke-Powershell -FilePath "test002--verify-encoding.ps1" -ArgumentList $testScriptArgs
$scriptReturnCode = $LASTEXITCODE
Write-Host "$(NL)> Script exit code = $scriptReturnCode"
if ( ($finalExitCode -eq 0) -and ($returnCode -ne 0) ) {
    $finalExitCode = $scriptReturnCode
}

Pop-Location

Exit $finalExitCode
