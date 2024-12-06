param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$true)][string]$FFMpegExePath,
    [Parameter(Mandatory=$false)][string]$OutputDir = "test-output"
)

if (-Not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir
}

$inputVideo = "$PSScriptRoot/../../resources/BigBuckBunnyClip-240p.mp4"
$ffmpegExe = "$FFMpegExePath -hide_banner"
$ffmpegCmd = "$ffmpegExe -i `"$inputVideo`" -r 30 -b:a 192k"

# Define the encoding commands with explicit format specification
$tests = @(
    @{
        Name = "Verify encoding fails - MP4: h.264 + AAC (libx264)"
        OutFilename = "libx264_aac.mp4"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libx264 -c:a aac -f mp4"
    },
    @{
        Name = "Verify encoding succeeds - M4A: AAC"
        OutFilename = "aac.m4a"
        CmdPrefix = "$ffmpegExe -ss 2.0 -to 5.0 -i `"$inputVideo`" -vn -c:a aac -b:a 192k -f mp4"
    },
    @{
        Name = "Verify encoding succeeds - MP3: MP3 (libmp3lame)"
        OutFilename = "libmp3lame.mp3"
        CmdPrefix = "$ffmpegExe -ss 2.0 -to 5.0 -i `"$inputVideo`" -vn -c:a libmp3lame -b:a 192k -f mp3"
    },
    @{
        Name = "Verify encoding succeeds - WEBM: VP9 + Opus (libvpx-vp9, libopus)"
        OutFilename = "libvpx-vp9_opus.webm"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx-vp9 -c:a libopus -f webm"
    },
    @{
        Name = "Verify encoding succeeds - MKV: VP9 + Opus (libvpx-vp9, libopus)"
        OutFilename = "libvpx-vp9_opus.mkv"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx-vp9 -c:a libopus -f matroska"
    },
    @{
        Name = "Verify encoding succeeds - WEBM: VP8 + Vorbis (libvpx, libvorbis)"
        OutFilename = "libvpx(vp8)_vorbis.webm"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx -c:a libvorbis -f webm"
    },
    @{
        Name = "Verify encoding succeeds - MKV: VP8 + Vorbis (libvpx, libvorbis)"
        OutFilename = "libvpx(vp8)_vorbis.mkv"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx -c:a libvorbis -f matroska"
    },
    # AV1 w/ libaom-av1 + AAC (mp4, webm)
    @{
        Name = "Verify encoding succeeds - MP4: AV1 + AAC (libaom-av1)"
        OutFilename = "libaom-av1_aac.mp4"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 3.0 -c:v libaom-av1 -c:a aac -f mp4"
    },
    ## You cannot encode to webm using AAC audio with FFMpeg
    ## > Error: [webm @ 00000165D93AED40] Only VP8 or VP9 or AV1 video and Vorbis or Opus audio and WebVTT subtitles are supported for WebM.
    #@{
    #    Name = "Verify encoding succeeds - WEBM: AV1 + AAC (libaom-av1)"
    #    OutFilename = "libaom-av1_aac.webm"
    #    CmdPrefix = "$ffmpegCmd -c:v libaom-av1 -c:a aac -f webm"
    #},
    ## AV1 + Opus will not play the opus audio in MP4 format on Windows
    ##"$ffmpegCmd -ss 2.0 -to 3.0 -c:v libaom-av1 -c:a libopus -f mp4 `"$OutputDir\libaom-av1_opus.mp4`""
    #@{
    #    Name = "Verify encoding succeeds - MP4: AV1 + Opus (libaom-av1, libopus)"
    #    OutFilename = "libaom-av1_opus.mp4"
    #    CmdPrefix = "$ffmpegCmd -ss 2.0 -to 3.0 -c:v libaom-av1 -c:a libopus -f mp4"
    #},
    @{
        Name = "Verify encoding succeeds - WEBM: AV1 + Opus (libaom-av1, libopus)"
        OutFilename = "libaom-av1_opus.webm"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 3.0 -c:v libaom-av1 -c:a libopus -f webm"
    }
    # === These won't work until we enable libstv ===
    ## AV1 w/ libstv + AAC (mp4, webm)
    #@{
    #    Name = "Verify encoding succeeds - MP4: AV1 + AAC (libstv-av1)"
    #    OutFilename = "libstv-av1_aac.mp4"
    #    CmdPrefix = "$ffmpegCmd -c:v libstv-av1 -c:a aac -f mp4"
    #},
    #@{
    #    Name = "Verify encoding succeeds - WEBM: AV1 + AAC (libstv-av1)"
    #    OutFilename = "libstv-av1_aac.webm"
    #    CmdPrefix = "$ffmpegCmd -c:v libstv-av1 -c:a aac -f webm"
    #},
    ## AV1 w/ libstv + Opus (mp4, webm)
    #@{
    #    Name = "Verify encoding succeeds - MP4: AV1 + Opus (libstv-av1, libopus)"
    #    OutFilename = "libstv-av1_opus.mp4"
    #    CmdPrefix = "$ffmpegCmd -c:v libstv-av1 -c:a libopus -f mp4"
    #},
    #@{
    #    Name = "Verify encoding succeeds - WEBM: AV1 + Opus (libstv-av1, libopus)"
    #    OutFilename = "libstv-av1_opus.webm"
    #    CmdPrefix = "$ffmpegCmd -c:v libstv-av1 -c:a libopus -f webm"
    #}
)

$runMsg     = " RUN      "
$successMsg = "       OK "
$failMsg    = "     FAIL "
$finalExitCode = 0
Write-Host "Running encoding tests..."
foreach ($test in $tests) {
    $OutFilePath = "$OutputDir/$($test.OutFilename)"
    $cmd = "$($test.CmdPrefix) `"$OutFilePath`" > `"$OutFilePath.txt`""
    Write-Host "[ $runMsg ] $($test.Name) ==> $OutFilePath"
    #Write-Host "> CMD = $cmd"
    $startTime = Get-Date
    Invoke-Expression $cmd
    $cmdExitCode = $LASTEXITCODE
    #Write-Host "> RETURN = $cmdExitCode"
    $isSuccess = ($cmdExitCode -eq 0)
    if ( ($finalExitCode -eq 0) -and (-not $isSuccess) ) {
        $finalExitCode = $cmdExitCode
    }
    $statusMsg = ($isSuccess ? $successMsg : $failMsg)
    $failSuffix = ($isSuccess ? "" : " | CMD EXIT CODE = $cmdExitCode")
    $totalTime = (Get-Date) - $startTime
    Write-Host "[ $statusMsg ] $($test.Name) ($($totalTime.TotalMilliseconds) ms)$failSuffix" -ForegroundColor ($isSuccess ? "Green" : "Red")
}

Write-Host "`nEncoding tests complete."
#Write-Host "Exit $finalExitCode"

Exit $finalExitCode