param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$true)][string]$PackageAndFeatures
)

Import-Module "$PSScriptRoot/../../scripts/ps-modules/Util" -Force -DisableNameChecking

$features = Get-Features $PackageAndFeatures
$requiredFeatures = @("avcodec", "avformat", "muxer-mp4", "protocol-file")
$forbiddenFeaturePrefixes = @("decoder-", "encoder-", "demuxer-", "muxer-")
$failed = $false

foreach ($feature in $requiredFeatures) {
    if ($features -contains $feature) {
        Write-Host "[ OK ] Required FFmpeg feature is enabled: $feature" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] Required FFmpeg feature is missing: $feature" -ForegroundColor Red
        $failed = $true
    }
}

foreach ($feature in $features) {
    foreach ($prefix in $forbiddenFeaturePrefixes) {
        if ($feature.StartsWith($prefix) -and $feature -ne "muxer-mp4") {
            Write-Host "[FAIL] Unexpected FFmpeg feature is enabled: $feature" -ForegroundColor Red
            $failed = $true
        }
    }
}

$requiredFiles = @(
    "bin/avutil-60.dll",
    "bin/avcodec-62.dll",
    "bin/avformat-62.dll",
    "lib/avutil.lib",
    "lib/avcodec.lib",
    "lib/avformat.lib",
    "include/libavcodec/avcodec.h",
    "include/libavformat/avformat.h"
)

$unexpectedFiles = @(
    "bin/avdevice-62.dll",
    "bin/avfilter-11.dll",
    "bin/swresample-6.dll",
    "bin/swscale-9.dll",
    "lib/avdevice.lib",
    "lib/avfilter.lib",
    "lib/swresample.lib",
    "lib/swscale.lib",
    "tools/ffmpeg/ffmpeg.exe",
    "tools/ffmpeg/ffprobe.exe",
    "tools/ffmpeg/ffplay.exe"
)

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $BuildArtifactsPath $relativePath
    if (Test-Path -LiteralPath $path) {
        Write-Host "[ OK ] Required mux-only package file exists: $relativePath" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] Required mux-only package file is missing: $relativePath" -ForegroundColor Red
        $failed = $true
    }
}

foreach ($relativePath in $unexpectedFiles) {
    $path = Join-Path $BuildArtifactsPath $relativePath
    if (Test-Path -LiteralPath $path) {
        Write-Host "[FAIL] Unexpected FFmpeg component was packaged: $relativePath" -ForegroundColor Red
        $failed = $true
    }
    else {
        Write-Host "[ OK ] Unneeded FFmpeg component is absent: $relativePath" -ForegroundColor Green
    }
}

if ($failed) {
    exit 1
}

Write-Host "MP4 mux-only package checks passed."
exit 0
