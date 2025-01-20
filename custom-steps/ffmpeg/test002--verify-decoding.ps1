param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$true)][string]$PackageAndFeatures,
    [Parameter(Mandatory=$true)][string]$ModulesRoot,
    [Parameter(Mandatory=$true)][string]$FFMpegExePath,
    [Parameter(Mandatory=$false)][string]$OutputDir = "test-output"
)

# Import modules
$moduleNames = @("Build", "Util")
foreach( $moduleName in $moduleNames ) {
    if(-not (Get-Module -Name $moduleName)) {
        Import-Module "$ModulesRoot/$moduleName" -Force -DisableNameChecking
    }
}

if (-Not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir
}

$ffmpegExe = "$FFMpegExePath -hide_banner"
$tests = @()
$features = Get-Features $PackageAndFeatures
$resourcesDir = "$PSScriptRoot/../../resources" 
Write-Message "Features are..."
$features | Format-List

# H.264 decode tests
$features = Get-Features $PackageAndFeatures
$inputH264Video = "$PSScriptRoot/../../resources/BigBuckBunnyClip-h264-240p.mp4"
$ffmpegDecodeH264FrameCmd = "$ffmpegExe -i `"$inputH264Video`" -ss 00:00:04.5 -frames:v 1"
$tests += 
@{
   Name = "Verify decoding fails - MP4: h.264"
   OutFilename = "h264-frame.png"
   CmdPrefix = "$ffmpegDecodeH264FrameCmd"
   ExpectedReturnCode = if(Get-IsOnWindowsOS) { -22 } elseif(Get-IsOnMacOS) { 234 } else { -1 }
}

# HEVC decode tests
$inputVideo = "$resourcesDir/BigBuckBunnyClip-hevc-240p.mp4"
$ffmpegCmd = "$ffmpegExe -i `"$inputVideo`" -ss 00:00:04.5 -frames:v 1"
if($features -contains "decoder-hevc")
{
   $tests += 
   @{
      Name = "Verify decoding succeeds - MP4: hevc"
      OutFilename = "hevc-frame.png"
      CmdPrefix = "$ffmpegCmd"
      ExpectedReturnCode = 0
   }
}
else
{
   $tests += 
   @{
      Name = "Verify decoding fails - MP4: hevc"
      OutFilename = "hevc-frame.png"
      CmdPrefix = "$ffmpegCmd"
      ExpectedReturnCode = if(Get-IsOnWindowsOS) { -22 } elseif(Get-IsOnMacOS) { 234 } else { -1 }
   }
}

$runMsg     = " RUN      "
$successMsg = "       OK "
$failMsg    = "     FAIL "
$finalExitCode = 0
Write-Host "Running decoding tests..."
foreach ($test in $tests) {
    $OutFilePath = "$OutputDir/$($test.OutFilename)"
    $cmd = "$($test.CmdPrefix) `"$OutFilePath`""
    Write-Host "[ $runMsg ] $($test.Name) ==> $OutFilePath"
    $startTime = Get-Date

    #Write-Host ">> Executing FFMpeg command"
    #Write-Host "$cmd"
    Invoke-Expression $cmd
    $cmdExitCode = $LASTEXITCODE

    $expectedReturnCode = if ($test.ContainsKey('ExpectedReturnCode')) { $test.ExpectedReturnCode } else { 0 }
    Write-Host ">> Expected return code = $expectedReturnCode.  Actual return code = $cmdExitCode"

    $isSuccess = ($cmdExitCode -eq $expectedReturnCode)
    if ( ($finalExitCode -eq 0) -and (-not $isSuccess) ) {
        $finalExitCode = $cmdExitCode
    }
    $statusMsg = ($isSuccess ? $successMsg : $failMsg)
    $failSuffix = ($isSuccess ? "" : " | CMD EXIT CODE = $cmdExitCode")
    $totalTime = (Get-Date) - $startTime
    Write-Host "[ $statusMsg ] $($test.Name) ($($totalTime.TotalMilliseconds) ms)$failSuffix" -ForegroundColor ($isSuccess ? "Green" : "Red")
}

Write-Host "`nEncoding tests complete."

Exit $finalExitCode