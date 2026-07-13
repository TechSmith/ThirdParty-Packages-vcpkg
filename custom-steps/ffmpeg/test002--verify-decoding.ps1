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

$ffmpegExe = "$FFMpegExePath -hide_banner"
$features = Get-Features $PackageAndFeatures
$resourcesDir = "$PSScriptRoot/../../resources"
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

function Test-HwDecodeSupport {
    param(
        [Parameter(Mandatory=$true)][string]$InputFile,
        [Parameter(Mandatory=$true)][string]$HwAccel,
        [Parameter(Mandatory=$true)][string]$CodecName,
        [Parameter(Mandatory=$true)][string]$OutputFile
    )

    $hwOutputFormat = switch ($HwAccel) {
        "d3d11va" { "d3d11" }
        "dxva2" { "dxva2_vld" }
        "videotoolbox" { "videotoolbox_vld" }
        default { $HwAccel }
    }

    $probeCommand = "$ffmpegExe -v error -y -hwaccel $HwAccel -hwaccel_output_format $hwOutputFormat -c:v $CodecName -i `"$InputFile`" -frames:v 1 -an -f null NUL"
    if(-not (Get-IsOnWindowsOS)) {
        $probeCommand = "$ffmpegExe -v error -y -hwaccel $HwAccel -hwaccel_output_format $hwOutputFormat -c:v $CodecName -i `"$InputFile`" -frames:v 1 -an -f null /dev/null"
    }

    Invoke-Expression $probeCommand
    if($LASTEXITCODE -ne 0) {
        return @{ ProbeSucceeded = $false; DecodeSucceeded = $false }
    }

    $decodeCommand = "$ffmpegExe -v error -y -hwaccel $HwAccel -hwaccel_output_format $hwOutputFormat -c:v $CodecName -i `"$InputFile`" -ss 00:00:01 -frames:v 1 -an `"$OutputFile`""
    $result = Invoke-FFmpegCommand -Name "Verify HW decoding succeeds - $CodecName via $HwAccel" -Command $decodeCommand -ExpectedReturnCode 0
    if(-not $result.IsSuccess) {
        if($script:finalExitCode -eq 0) {
            $script:finalExitCode = $result.ExitCode
        }
    }

    return @{ ProbeSucceeded = $true; DecodeSucceeded = $result.IsSuccess }
}

function Ensure-SampleClip {
    param(
        [Parameter(Mandatory=$true)][string]$CodecName,
        [Parameter(Mandatory=$true)][string]$SamplePath,
        [Parameter(Mandatory=$true)][string]$SourcePath
    )

    if(Test-Path $SamplePath) {
        return $true
    }

    $sampleCmd = ""
    if($CodecName -eq "vp8") {
        $sampleCmd = "$ffmpegExe -v error -y -ss 00:00:00 -t 1.5 -i `"$SourcePath`" -an -c:v libvpx -b:v 300k `"$SamplePath`""
    }
    elseif($CodecName -eq "av1") {
        $sampleCmd = "$ffmpegExe -v error -y -ss 00:00:00 -t 1.0 -i `"$SourcePath`" -an -cpu-used 8 -row-mt 1 -threads 4 -c:v libaom-av1 -b:v 300k `"$SamplePath`""
    }

    if([string]::IsNullOrEmpty($sampleCmd)) {
        return $false
    }

    Invoke-Expression $sampleCmd
    return ($LASTEXITCODE -eq 0 -and (Test-Path $SamplePath))
}

Write-Host "Running decoding tests..."

# OGG decode tests
$inputOggVorbis = "$resourcesDir/AudioClip-vorbis.ogg"
$inputOggOpus = "$resourcesDir/AudioClip-opus.ogg"
if($features -contains "demuxer-ogg" -and $features -contains "decoder-vorbis") {
    $result = Invoke-FFmpegCommand -Name "Verify decoding succeeds - OGG: Vorbis to WAV" -Command "$ffmpegExe -y -i `"$inputOggVorbis`" -c:a pcm_s16le -f wav `"$OutputDir/ogg-vorbis-decoded.wav`""
    if(-not $result.IsSuccess -and $finalExitCode -eq 0) { $finalExitCode = $result.ExitCode }
}
if($features -contains "demuxer-ogg" -and $features -contains "decoder-opus") {
    $result = Invoke-FFmpegCommand -Name "Verify decoding succeeds - OGG: Opus to WAV" -Command "$ffmpegExe -y -i `"$inputOggOpus`" -c:a pcm_s16le -f wav `"$OutputDir/ogg-opus-decoded.wav`""
    if(-not $result.IsSuccess -and $finalExitCode -eq 0) { $finalExitCode = $result.ExitCode }
}

# H.264 decode conditional test
$inputH264Video = "$resourcesDir/BigBuckBunnyClip-h264-240p.mp4"
$inputHevcVideo = "$resourcesDir/BigBuckBunnyClip-hevc-240p.mp4"

if($features -contains "decoder-h264") {
    $result = Invoke-FFmpegCommand -Name "Verify decoding succeeds - MP4: h.264" -Command "$ffmpegExe -y -i `"$inputH264Video`" -ss 00:00:04.5 -frames:v 1 `"$OutputDir/h264-frame.png`"" -ExpectedReturnCode 0
}
else {
    $expectedH264FailCode = if(Get-IsOnWindowsOS) { -22 } elseif(Get-IsOnMacOS) { 234 } else { -1 }
    $result = Invoke-FFmpegCommand -Name "Verify decoding fails - MP4: h.264" -Command "$ffmpegExe -y -i `"$inputH264Video`" -ss 00:00:04.5 -frames:v 1 `"$OutputDir/h264-frame.png`"" -ExpectedReturnCode $expectedH264FailCode
}
if(-not $result.IsSuccess -and $finalExitCode -eq 0) { $finalExitCode = $result.ExitCode }

# HEVC decode conditional test
if($features -contains "decoder-hevc") {
    $result = Invoke-FFmpegCommand -Name "Verify decoding succeeds - MP4: hevc" -Command "$ffmpegExe -y -i `"$inputHevcVideo`" -ss 00:00:04.5 -frames:v 1 `"$OutputDir/hevc-frame.png`"" -ExpectedReturnCode 0
}
else {
    $expectedHevcFailCode = if(Get-IsOnWindowsOS) { -22 } elseif(Get-IsOnMacOS) { 234 } else { -1 }
    $result = Invoke-FFmpegCommand -Name "Verify decoding fails - MP4: hevc" -Command "$ffmpegExe -y -i `"$inputHevcVideo`" -ss 00:00:04.5 -frames:v 1 `"$OutputDir/hevc-frame.png`"" -ExpectedReturnCode $expectedHevcFailCode
}
if(-not $result.IsSuccess -and $finalExitCode -eq 0) { $finalExitCode = $result.ExitCode }

# H.264/HEVC/VP8/VP9/AV1 HW decode tests
$vp9Source = "$resourcesDir/BigBuckBunnyClip-vp9-240p.mp4"
$vp8Sample = "$OutputDir/sample-vp8.webm"
$av1Sample = "$OutputDir/sample-av1.mkv"

$hasVp8Sample = Ensure-SampleClip -CodecName "vp8" -SamplePath $vp8Sample -SourcePath $vp9Source
$hasAv1Sample = Ensure-SampleClip -CodecName "av1" -SamplePath $av1Sample -SourcePath $vp9Source

$codecSpecs = @(
    @{ Name = "H264"; Codec = "h264"; Feature = "decoder-h264"; Input = $inputH264Video; SampleReady = $true },
    @{ Name = "HEVC"; Codec = "hevc"; Feature = "decoder-hevc"; Input = $inputHevcVideo; SampleReady = $true },
    @{ Name = "VP8"; Codec = "vp8"; Feature = "decoder-vp8"; Input = $vp8Sample; SampleReady = $hasVp8Sample },
    @{ Name = "VP9"; Codec = "vp9"; Feature = "decoder-vp9"; Input = $vp9Source; SampleReady = $true },
    @{ Name = "AV1"; Codec = "av1"; Feature = "decoder-av1"; Input = $av1Sample; SampleReady = $hasAv1Sample }
)

$hwaccelCandidates = @()
if(Get-IsOnWindowsOS) {
    $hwaccelCandidates = @("d3d11va", "dxva2")
    if($features | Where-Object { $_ -match "^hwaccel-.*-vulkan$" }) {
        $hwaccelCandidates += "vulkan"
    }
}
elseif(Get-IsOnMacOS) {
    $hwaccelCandidates = @("videotoolbox")
    if($features | Where-Object { $_ -match "^hwaccel-.*-vulkan$" }) {
        $hwaccelCandidates += "vulkan"
    }
}

foreach($spec in $codecSpecs) {
    if((-not ($features -contains $spec.Feature)) -or (-not $spec.SampleReady)) {
        Write-Host "[ $skipMsg ] No hardware decoding support for $($spec.Name) on this machine" -ForegroundColor Yellow
        continue
    }

    $hasSuccessfulHwPath = $false
    $hasSupportedHwPath = $false
    foreach($hwaccel in $hwaccelCandidates) {
        $outputPath = "$OutputDir/hw-decode-$($spec.Codec)-$hwaccel.png"
        $hwResult = Test-HwDecodeSupport -InputFile $spec.Input -HwAccel $hwaccel -CodecName $spec.Codec -OutputFile $outputPath
        if($hwResult.ProbeSucceeded) {
            $hasSupportedHwPath = $true
        }
        if($hwResult.DecodeSucceeded) {
            $hasSuccessfulHwPath = $true
            break
        }
    }

    if((-not $hasSuccessfulHwPath) -and (-not $hasSupportedHwPath)) {
        Write-Host "[ $skipMsg ] No hardware decoding support for $($spec.Name) on this machine" -ForegroundColor Yellow
    }
}

Write-Host "`nDecoding tests complete."
Exit $finalExitCode
