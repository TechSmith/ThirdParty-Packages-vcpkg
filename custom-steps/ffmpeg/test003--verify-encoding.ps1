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
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$inputVideo = "$PSScriptRoot/../../resources/BigBuckBunnyClip-vp9-240p.mp4"
$inputMp3Audio = "$PSScriptRoot/../../resources/AIVoiceAudioClip.mp3"
$ffmpegExe = "$FFMpegExePath -hide_banner"
$ffmpegCmd = "$ffmpegExe -i `"$inputVideo`" -r 30 -b:a 192k"

$runMsg     = " RUN      "
$successMsg = "       OK "
$failMsg    = "     FAIL "
$skipMsg    = "     SKIP "
$finalExitCode = 0

function Invoke-FFmpegCommand {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Command,
        [Parameter(Mandatory=$false)][int]$ExpectedReturnCode = 0
    )

    Write-Host "[ $runMsg ] $Name"
    $startTime = Get-Date
    Invoke-Expression $Command
    $cmdExitCode = $LASTEXITCODE
    $isSuccess = ($cmdExitCode -eq $ExpectedReturnCode)
    $totalTime = (Get-Date) - $startTime
    $statusMsg = ($isSuccess ? $successMsg : $failMsg)
    $failSuffix = ($isSuccess ? "" : " | CMD EXIT CODE = $cmdExitCode")
    Write-Host "[ $statusMsg ] $Name ($($totalTime.TotalMilliseconds) ms)$failSuffix" -ForegroundColor ($isSuccess ? "Green" : "Red")
    return @{ IsSuccess = $isSuccess; ExitCode = $cmdExitCode }
}

function Try-HwEncodePath {
    param(
        [Parameter(Mandatory=$true)][string]$CodecName,
        [Parameter(Mandatory=$true)][string]$EncoderName,
        [Parameter(Mandatory=$true)][string]$OutputFile
    )

    $probeTarget = if(Get-IsOnWindowsOS) { "NUL" } else { "/dev/null" }
    $probeCommand = "$ffmpegExe -v error -y -f lavfi -i color=size=128x72:rate=30:duration=1 -an -c:v $EncoderName -f null $probeTarget"
    Invoke-Expression $probeCommand
    if($LASTEXITCODE -ne 0) {
        return @{ ProbeSucceeded = $false; EncodeSucceeded = $false }
    }

    $encodeCommand = "$ffmpegExe -v error -y -f lavfi -i color=size=128x72:rate=30:duration=1 -an -c:v $EncoderName `"$OutputFile`""
    $result = Invoke-FFmpegCommand -Name "Verify HW encoding succeeds - $CodecName via $EncoderName" -Command $encodeCommand -ExpectedReturnCode 0
    if(-not $result.IsSuccess -and $script:finalExitCode -eq 0) {
        $script:finalExitCode = $result.ExitCode
    }

    return @{ ProbeSucceeded = $true; EncodeSucceeded = $result.IsSuccess }
}

Write-Host "Running encoding tests..."

# Base software encoding coverage
$softwareTests = @(
    @{ Name = "Verify encoding succeeds - M4A: AAC"; OutFilename = "aac.m4a"; CmdPrefix = "$ffmpegExe -ss 2.0 -to 5.0 -i `"$inputVideo`" -vn -c:a aac -b:a 192k -f mp4" },
    @{ Name = "Verify encoding succeeds - MP3: MP3 (libmp3lame)"; OutFilename = "libmp3lame.mp3"; CmdPrefix = "$ffmpegExe -ss 2.0 -to 5.0 -i `"$inputVideo`" -vn -c:a libmp3lame -b:a 192k -f mp3" },
    @{ Name = "Verify encoding fails - MP4: h.264 + AAC (libx264)"; OutFilename = "libx264_aac.mp4"; CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libx264 -c:a aac -f mp4"; ExpectedReturnCode = if(Get-IsOnWindowsOS) { -1129203192 } elseif(Get-IsOnMacOS) { 8 } else { -1 } },
    @{ Name = "Verify encoding succeeds - MP4: VP9 + Opus (libvpx-vp9, libopus)"; OutFilename = "libvpx-vp9_opus.mp4"; CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx-vp9 -c:a libopus -f mp4" },
    @{ Name = "Verify encoding succeeds - MP4: AV1 + AAC (libaom-av1)"; OutFilename = "libaom-av1_aac.mp4"; CmdPrefix = "$ffmpegCmd -ss 2.0 -to 3.0 -c:v libaom-av1 -c:a aac -f mp4" },
    @{ Name = "Verify encoding succeeds - WEBM: VP9 + Opus (libvpx-vp9, libopus)"; OutFilename = "libvpx-vp9_opus.webm"; CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx-vp9 -c:a libopus -f webm" },
    @{ Name = "Verify encoding succeeds - WEBM: VP8 + Vorbis (libvpx, libvorbis)"; OutFilename = "libvpx(vp8)_vorbis.webm"; CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx -c:a libvorbis -f webm" },
    @{ Name = "Verify encoding succeeds - WEBM: AV1 + Opus (libaom-av1, libopus)"; OutFilename = "libaom-av1_opus.webm"; CmdPrefix = "$ffmpegCmd -ss 2.0 -to 3.0 -c:v libaom-av1 -c:a libopus -f webm" },
    @{ Name = "Verify encoding succeeds - MKV: VP9 + Opus (libvpx-vp9, libopus)"; OutFilename = "libvpx-vp9_opus.mkv"; CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx-vp9 -c:a libopus -f matroska" },
    @{ Name = "Verify encoding succeeds - MKV: VP8 + Vorbis (libvpx, libvorbis)"; OutFilename = "libvpx(vp8)_vorbis.mkv"; CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx -c:a libvorbis -f matroska" }
)

$features = Get-Features $PackageAndFeatures
if($features -contains "muxer-ogg" -and $features -contains "encoder-vorbis") {
    $softwareTests += @{ Name = "Verify encoding succeeds - OGG: Vorbis (libvorbis) from MP3"; OutFilename = "vorbis.ogg"; CmdPrefix = "$ffmpegExe -ss 0 -to 3.0 -i `"$inputMp3Audio`" -c:a libvorbis -b:a 128k -f ogg" }
}
if($features -contains "muxer-ogg" -and $features -contains "encoder-opus") {
    $softwareTests += @{ Name = "Verify encoding succeeds - OGG: Opus (libopus) from MP3"; OutFilename = "opus.ogg"; CmdPrefix = "$ffmpegExe -ss 0 -to 3.0 -i `"$inputMp3Audio`" -c:a libopus -b:a 128k -f ogg" }
}

foreach ($test in $softwareTests) {
    $outFilePath = "$OutputDir/$($test.OutFilename)"
    $expectedReturnCode = if ($test.ContainsKey('ExpectedReturnCode')) { $test.ExpectedReturnCode } else { 0 }
    $result = Invoke-FFmpegCommand -Name $test.Name -Command "$($test.CmdPrefix) `"$outFilePath`"" -ExpectedReturnCode $expectedReturnCode
    if(-not $result.IsSuccess -and $finalExitCode -eq 0) {
        $finalExitCode = $result.ExitCode
    }
}

# VP8/VP9/AV1 HW encode tests
$codecToEncoders = @{
    "VP8" = @()
    "VP9" = @()
    "AV1" = @()
}

if(Get-IsOnWindowsOS) {
    if($features -contains "encoder-vp8-mf") { $codecToEncoders["VP8"] += "vp8_mf" }
    if($features -contains "encoder-vp9-mf") { $codecToEncoders["VP9"] += "vp9_mf" }
    if($features -contains "encoder-av1-mf") { $codecToEncoders["AV1"] += "av1_mf" }
}
elseif(Get-IsOnMacOS) {
    if($features -contains "encoder-vp8-videotoolbox") { $codecToEncoders["VP8"] += "vp8_videotoolbox" }
    if($features -contains "encoder-vp9-videotoolbox") { $codecToEncoders["VP9"] += "vp9_videotoolbox" }
    if($features -contains "encoder-av1-videotoolbox") { $codecToEncoders["AV1"] += "av1_videotoolbox" }
}

if($features -contains "encoder-av1-vulkan") {
    $codecToEncoders["AV1"] += "av1_vulkan"
}

foreach($codecName in @("VP8", "VP9", "AV1")) {
    $encoders = $codecToEncoders[$codecName]
    if($encoders.Count -eq 0) {
        Write-Host "[ $skipMsg ] No hardware encoding support for $codecName on this machine" -ForegroundColor Yellow
        continue
    }

    $encoded = $false
    $hasSupportedHwPath = $false
    foreach($encoderName in $encoders) {
        $outputExtension = if($codecName -eq "AV1") { "mkv" } elseif($codecName -eq "VP9") { "webm" } else { "webm" }
        $outputFile = "$OutputDir/hw-encode-$($codecName.ToLower())-$encoderName.$outputExtension"
        $encodeResult = Try-HwEncodePath -CodecName $codecName -EncoderName $encoderName -OutputFile $outputFile
        if($encodeResult.ProbeSucceeded) {
            $hasSupportedHwPath = $true
        }
        if($encodeResult.EncodeSucceeded) {
            $encoded = $true
            break
        }
    }

    if((-not $encoded) -and (-not $hasSupportedHwPath)) {
        Write-Host "[ $skipMsg ] No hardware encoding support for $codecName on this machine" -ForegroundColor Yellow
    }
}

Write-Host "`nEncoding tests complete."
Exit $finalExitCode
