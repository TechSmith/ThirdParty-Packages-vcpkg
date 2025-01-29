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

$inputVideo = "$PSScriptRoot/../../resources/BigBuckBunnyClip-vp9-240p.mp4"
$ffmpegExe = "$FFMpegExePath -hide_banner"
$ffmpegCmd = "$ffmpegExe -i `"$inputVideo`" -r 30 -b:a 192k"

# Define the encoding commands with explicit format specification
$features = ($PackageAndFeatures -match '\[(.*?)\]')[1] -split ','
$tests = @(
    # --- M4A Tests ---
    @{
        Name = "Verify encoding succeeds - M4A: AAC"
        OutFilename = "aac.m4a"
        CmdPrefix = "$ffmpegExe -ss 2.0 -to 5.0 -i `"$inputVideo`" -vn -c:a aac -b:a 192k -f mp4"
    },

    # --- MP3 Tests ---
    @{
        Name = "Verify encoding succeeds - MP3: MP3 (libmp3lame)"
        OutFilename = "libmp3lame.mp3"
        CmdPrefix = "$ffmpegExe -ss 2.0 -to 5.0 -i `"$inputVideo`" -vn -c:a libmp3lame -b:a 192k -f mp3"
    },

    # --- MP4 Tests ---
    @{
        Name = "Verify encoding fails - MP4: h.264 + AAC (libx264)"
        OutFilename = "libx264_aac.mp4"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libx264 -c:a aac -f mp4"
        ExpectedReturnCode = if(Get-IsOnWindowsOS) { -1129203192 } elseif(Get-IsOnMacOS) { 8 } else { -1 }
    },
    @{
        Name = "Verify encoding succeeds - MP4: VP9 + Opus (libvpx-vp9, libopus)"
        OutFilename = "libvpx-vp9_opus.mp4"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx-vp9 -c:a libopus -f mp4"
    },
    @{
        Name = "Verify encoding succeeds - MP4: AV1 + AAC (libaom-av1)"
        OutFilename = "libaom-av1_aac.mp4"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 3.0 -c:v libaom-av1 -c:a aac -f mp4"
    },
    ## AV1 + Opus will not play the opus audio in MP4 format on Windows
    ##"$ffmpegCmd -ss 2.0 -to 3.0 -c:v libaom-av1 -c:a libopus -f mp4 `"$OutputDir\libaom-av1_opus.mp4`""
    #@{
    #    Name = "Verify encoding succeeds - MP4: AV1 + Opus (libaom-av1, libopus)"
    #    OutFilename = "libaom-av1_opus.mp4"
    #    CmdPrefix = "$ffmpegCmd -ss 2.0 -to 3.0 -c:v libaom-av1 -c:a libopus -f mp4"
    #},

    # --- WEBM Tests ---
    @{
        Name = "Verify encoding succeeds - WEBM: VP9 + Opus (libvpx-vp9, libopus)"
        OutFilename = "libvpx-vp9_opus.webm"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx-vp9 -c:a libopus -f webm"
    },
    @{
        Name = "Verify encoding succeeds - WEBM: VP8 + Vorbis (libvpx, libvorbis)"
        OutFilename = "libvpx(vp8)_vorbis.webm"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx -c:a libvorbis -f webm"
    },
    @{
        Name = "Verify encoding succeeds - WEBM: AV1 + Opus (libaom-av1, libopus)"
        OutFilename = "libaom-av1_opus.webm"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 3.0 -c:v libaom-av1 -c:a libopus -f webm"
    },

    # --- MKV Tests ---
    @{
        Name = "Verify encoding succeeds - MKV: VP9 + Opus (libvpx-vp9, libopus)"
        OutFilename = "libvpx-vp9_opus.mkv"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx-vp9 -c:a libopus -f matroska"
    },
    @{
        Name = "Verify encoding succeeds - MKV: VP8 + Vorbis (libvpx, libvorbis)"
        OutFilename = "libvpx(vp8)_vorbis.mkv"
        CmdPrefix = "$ffmpegCmd -ss 2.0 -to 5.0 -c:v libvpx -c:a libvorbis -f matroska"
    }
)

$runMsg     = " RUN      "
$successMsg = "       OK "
$failMsg    = "     FAIL "
$finalExitCode = 0
Write-Host "Running encoding tests..."
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

Write-Host "`nEncoding tests complete."

Exit $finalExitCode