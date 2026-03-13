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

Import-Module "$PSScriptRoot/../ffmpeg-shared/FFmpegBuildTests" -Force -DisableNameChecking

if (-Not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir
}

$ffmpegExe = "$FFMpegExePath -hide_banner"

# Define the encoding commands with explicit format specification
$tests = @(
    @{
        Name = "EncodersAllPlatforms"
        CmdOption = "-encoders"
        ExpectedValues = @(
            # We only really care about encoding mp3 for our use case
            " libmp3lame "
        )
        NotExpectedValues = @(
        )
        IsEnabled = $true
    },
    @{
        Name = "DecodersAllPlatforms"
        CmdOption = "-decoders"
        ExpectedValues = @(
            # Non-comprehensive list. Loosely based on:
            # common formats, supported Camtasia formats, supported Audiate formats
            " prores "
            " prores_raw "
            " mpeg1video "
            " mpegvideo "
            " mpeg2video "
            " mpeg4 "
            " mp3 "
            " mp3adu "
            " mp3adufloat "
            " mp3float "
            " mp3on4 "
            " mp3on4float"
            " h264 "
            " mts2 "
            " png "
            " apng "
            " wmav1 "
            " wmav2 "
            " wmv1 "
            " wmv2 "
            " wmv3 "
            " opus "
            " libopus "
            " vorbis "
            " libvorbis "
            " vp7 "
            " vp8 "
            " libvpx "
            " libvpx-vp9 "
            " vp9 "
            " pcm_u16le "
            " pcm_u24be "
            " pcm_u24le "
            " pcm_u32be "
            " pcm_u32le "
            " pcm_u8 "
            " pcm_vidc "
            " pcm_alaw "
            " pcm_bluray "
            " pcm_dvd "
            " pcm_f16le "
            " pcm_f24le "
            " pcm_f32be "
            " pcm_f32le "
            " pcm_f64be "
            " pcm_lxf "
            " pcm_mulaw "
            " pcm_s16be "
            " pcm_s16be_planar "
            " pcm_s16le "
            " pcm_s16le_planar "
            " pcm_s24be "
            " pcm_s24daud "
            " pcm_s24le "
            " pcm_s24le_planar "
            " pcm_s32be "
            " pcm_s32le "
            " pcm_s32le_planar "
            " pcm_s64be "
            " pcm_s64le "
            " pcm_s8 "
            " pcm_s8_planar "
            " pcm_sga "
            " pcm_u16be "
            " dvvideo "
            " dvaudio "
            " flac "

            # Others
            " aac "
            " aac_fixed "
            " aac_latm "
            " libaom-av1 "
            " libdav1d "
            " libopus "
            " libvorbis "
            " libvpx "
            " libvpx-vp9 "
            " mp3 "
            " mp3float "
            " mp3adufloat "
            " mp3adu "
            " mp3on4float "
            " mp3on4 "
            " opus "
            " png "
            " pcm_alaw "
            " pcm_bluray "
            " pcm_dvd "
            " pcm_f16le "
            " pcm_f24le "
            " pcm_f32be "
            " pcm_f32le "
            " pcm_f64be "
            " pcm_f64le "
            " pcm_lxf "
            " pcm_mulaw "
            " pcm_s16be "
            " pcm_s16be_planar "
            " pcm_s16le "
            " pcm_s16le_planar "
            " pcm_s24be "
            " pcm_s24daud "
            " pcm_s24le "
            " pcm_s24le_planar "
            " pcm_s32be "
            " pcm_s32le "
            " pcm_s32le_planar "
            " pcm_s64be "
            " pcm_s64le "
            " pcm_s8 "
            " pcm_s8_planar "
            " pcm_sga "
            " pcm_u16be "
            " pcm_u16le "
            " pcm_u24be "
            " pcm_u24le "
            " pcm_u32be "
            " pcm_u32le "
            " pcm_u8 "
            " pcm_vidc "
            " qtrle "
            " vorbis "
            " vp8 "
            " vp9 "
        )
        IsEnabled = $true
    },

    @{
        Name = "DecodersOldAllPlatforms"
        CmdOption = "-decoders"
        ExpectedValues = @(
            # Others from old tests, in case we missed any important ones
            " aac "
            " aac_fixed "
            " aac_latm "
            " libaom-av1 "
            " libdav1d "
            " libopus "
            " libvorbis "
            " libvpx "
            " libvpx-vp9 "
            " mp3 "
            " mp3float "
            " mp3adufloat "
            " mp3adu "
            " mp3on4float "
            " mp3on4 "
            " opus "
            " png "
            " pcm_alaw "
            " pcm_bluray "
            " pcm_dvd "
            " pcm_f16le "
            " pcm_f24le "
            " pcm_f32be "
            " pcm_f32le "
            " pcm_f64be "
            " pcm_f64le "
            " pcm_lxf "
            " pcm_mulaw "
            " pcm_s16be "
            " pcm_s16be_planar "
            " pcm_s16le "
            " pcm_s16le_planar "
            " pcm_s24be "
            " pcm_s24daud "
            " pcm_s24le "
            " pcm_s24le_planar "
            " pcm_s32be "
            " pcm_s32le "
            " pcm_s32le_planar "
            " pcm_s64be "
            " pcm_s64le "
            " pcm_s8 "
            " pcm_s8_planar "
            " pcm_sga "
            " pcm_u16be "
            " pcm_u16le "
            " pcm_u24be "
            " pcm_u24le "
            " pcm_u32be "
            " pcm_u32le "
            " pcm_u8 "
            " pcm_vidc "
            " qtrle "
            " vorbis "
            " vp8 "
            " vp9 "
        )
        IsEnabled = $true
    },
    @{
        Name = "DecodersOldWin"
        CmdOption = "-decoders"
        ExpectedValues = @(
            " av1_qsv "
            " vp8_qsv "
            " vp9_qsv "
        )
        NotExpectedValues = @()
        IsEnabled = $true
    },
    @{
        Name = "MuxersOldAllPlatforms"
        CmdOption = "-muxers"
        ExpectedValues = @(
            " adts " 
            " image2 "
            " latm "
            " matroska "
            " mkvtimestamp_v2 "
            " mov "
            " mp3 "
            " mp4 "
            " mpegts "
            " rtp "
            " rtp_mpegts "
            " webm "
        )
        NotExpectedValues = @()
        IsEnabled = $true
    },
    @{
        Name = "DemuxersOldAllPlatforms"
        CmdOption = "-demuxers"
        ExpectedValues = @(
            " aac "
            " image2 "
            " matroska,webm "
            " mov,mp4,m4a,3gp,3g2,mj2 "
            " mp3 "
            " mpegts "
            " mpegtsraw "
            " wav "
        )
        NotExpectedValues = @()
        IsEnabled = $true
    },
    @{
        Name = "FiltersOldAllPlatforms"
        CmdOption = "-filters"
        ExpectedValues = @(
            " aresample "
            " asetrate "
            " atempo "
            " scale "
        )
        NotExpectedValues = @()
        IsEnabled = $true
    }
)

$finalExitCode = Run-FFmpeg-Capabilities-Tests -tests $tests -OutputDir $OutputDir -ffmpegExe $ffmpegExe

Exit $finalExitCode
