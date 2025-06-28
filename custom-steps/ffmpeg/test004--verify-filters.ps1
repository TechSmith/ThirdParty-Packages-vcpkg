param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$true)][string]$PortAndFeatures,
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
$features = Get-Features $PortAndFeatures
$resourcesDir = "$PSScriptRoot/../../resources" 
$voiceClip = "$resourcesDir/AIVoiceAudioClip.mp3"

if($features -contains "filter-asetrate" -and $features -contains "filter-aresample")
{
   $tests += 
   @{
      Name = "Verify speed adjustment without pitch correction succeeds: @0.25x"
      OutFilename = "speed-adjustment-without-pitch-correction-0.25x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*0.25,aresample=44100`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment without pitch correction succeeds: @0.5x"
      OutFilename = "speed-adjustment-without-pitch-correction-0.50x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*0.5,aresample=44100`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment without pitch correction succeeds: @0.75x"
      OutFilename = "speed-adjustment-without-pitch-correction-0.75x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*0.75,aresample=44100`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment without pitch correction succeeds: @0.77x"
      OutFilename = "speed-adjustment-without-pitch-correction-0.77x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*0.77,aresample=44100`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment without pitch correction succeeds: @1.5x"
      OutFilename = "speed-adjustment-without-pitch-correction-1.50x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*1.5,aresample=44100`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment without pitch correction succeeds: @1.75x"
      OutFilename = "speed-adjustment-without-pitch-correction-1.75x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*1.75,aresample=44100`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment without pitch correction succeeds: @1.77x"
      OutFilename = "speed-adjustment-without-pitch-correction-1.77x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*1.77,aresample=44100`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment without pitch correction succeeds: @2x"
      OutFilename = "speed-adjustment-without-pitch-correction-2.00x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*2,aresample=44100`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment without pitch correction succeeds: @4x"
      OutFilename = "speed-adjustment-without-pitch-correction-4.00x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*4,aresample=44100`""
      ExpectedReturnCode = 0
   }
}

if($features -contains "filter-atempo")
{
   $tests += 
   @{
      Name = "Verify speed adjustment with pitch correction succeeds: @0.25x"
      OutFilename = "speed-adjustment-with-pitch-correction-0.25x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"atempo=0.5,atempo=0.5`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment with pitch correction succeeds: @0.5x"
      OutFilename = "speed-adjustment-with-pitch-correction-0.50x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"atempo=0.5`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment with pitch correction succeeds: @0.75x"
      OutFilename = "speed-adjustment-with-pitch-correction-0.75x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"atempo=0.75`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment with pitch correction succeeds: @0.77x"
      OutFilename = "speed-adjustment-with-pitch-correction-0.77x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"atempo=0.77`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment with pitch correction succeeds: @1.5x"
      OutFilename = "speed-adjustment-with-pitch-correction-1.50x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"atempo=1.5`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment with pitch correction succeeds: @1.75x"
      OutFilename = "speed-adjustment-with-pitch-correction-1.75x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"atempo=1.75`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment with pitch correction succeeds: @1.77x"
      OutFilename = "speed-adjustment-with-pitch-correction-1.77x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"atempo=1.77`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment with pitch correction succeeds: @2x"
      OutFilename = "speed-adjustment-with-pitch-correction-2.00x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"atempo=2`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify speed adjustment with pitch correction succeeds: @4x"
      OutFilename = "speed-adjustment-with-pitch-correction-4.00x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"atempo=2,atempo=2`""
      ExpectedReturnCode = 0
   }
}

if($features -contains "filter-asetrate" -and $features -contains "filter-atempo")
{
   $tests += 
   @{
      Name = "Verify pitch adjustment succeeds: @0.25x"
      OutFilename = "pitch-adjustment-0.25x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*0.25,atempo=2,atempo=2`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify pitch adjustment succeeds: @0.5x"
      OutFilename = "pitch-adjustment-0.50x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*0.5,atempo=2`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify pitch adjustment succeeds: @0.75x"
      OutFilename = "pitch-adjustment-0.75x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*0.75,atempo=(1/0.75)`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify pitch adjustment succeeds: @0.77x"
      OutFilename = "pitch-adjustment-0.77x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*0.77,atempo=(1/0.77)`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify pitch adjustment succeeds: @1.5x"
      OutFilename = "pitch-adjustment-1.50x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*1.5,atempo=(1/1.5)`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify pitch adjustment succeeds: @1.75x"
      OutFilename = "pitch-adjustment-1.75x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*1.75,atempo=1/1.75`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify pitch adjustment succeeds: @1.77x"
      OutFilename = "pitch-adjustment-1.77x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*1.77,atempo=1/1.77`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify pitch adjustment succeeds: @2x"
      OutFilename = "pitch-adjustment-2.00x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*2,atempo=0.5`""
      ExpectedReturnCode = 0
   },
   @{
      Name = "Verify pitch adjustment succeeds: @4x"
      OutFilename = "pitch-adjustment-4.00x.mp3"
      CmdPrefix = "$ffmpegExe -i `"$voiceClip`" -af `"asetrate=44100*4,atempo=0.5,atempo=0.5`""
      ExpectedReturnCode = 0
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