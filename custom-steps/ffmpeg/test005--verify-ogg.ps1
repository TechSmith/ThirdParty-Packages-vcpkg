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

$inputOggAudio = "$PSScriptRoot/../../resources/AudioClip-vorbis.ogg"
$inputMp3Audio = "$PSScriptRoot/../../resources/AIVoiceAudioClip.mp3"
$ffmpegExe = "$FFMpegExePath -hide_banner"

$tests = @(
    # --- OGG Decoding Tests ---
    @{
        Name = "Verify decoding succeeds - OGG: Vorbis to WAV"
        OutFilename = "ogg-decoded.wav"
        CmdPrefix = "$ffmpegExe -i `"$inputOggAudio`" -c:a pcm_s16le -f wav"
    },

    # --- OGG Encoding Tests ---
    @{
        Name = "Verify encoding succeeds - OGG: Vorbis (libvorbis) from MP3"
        OutFilename = "vorbis.ogg"
        CmdPrefix = "$ffmpegExe -ss 0 -to 3.0 -i `"$inputMp3Audio`" -c:a libvorbis -b:a 128k -f ogg"
    },
    @{
        Name = "Verify encoding succeeds - OGG: Opus (libopus) from MP3"
        OutFilename = "opus.ogg"
        CmdPrefix = "$ffmpegExe -ss 0 -to 3.0 -i `"$inputMp3Audio`" -c:a libopus -b:a 128k -f ogg"
    }
)

$runMsg     = " RUN      "
$successMsg = "       OK "
$failMsg    = "     FAIL "
$finalExitCode = 0
Write-Host "Running OGG tests..."
foreach ($test in $tests) {
    $OutFilePath = "$OutputDir/$($test.OutFilename)"
    $cmd = "$($test.CmdPrefix) `"$OutFilePath`""
    Write-Host "[ $runMsg ] $($test.Name) ==> $OutFilePath"
    $startTime = Get-Date

    Write-Host ">> Executing FFMpeg command"
    Write-Host "$cmd"
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

Write-Host "`nOGG tests complete."

Exit $finalExitCode
