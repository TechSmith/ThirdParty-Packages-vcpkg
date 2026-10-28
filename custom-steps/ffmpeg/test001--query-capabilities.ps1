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

# Define the encoding commands with explicit format specification
$tests = @(
    @{
        Name = "Encoders"
        CmdOption = "-encoders"
        ExpectedValues = @(
            " aac "
            " libaom-av1 "
            " libmp3lame "
            " libopus "
            " libvorbis "
            " libvpx "
            " libvpx-vp9 "
            " opus "
            " png "
            " vorbis "
        )
        NotExpectedValues = @()
        IsEnabled = $true
    },
    @{
        Name = "EncodersWin"
        CmdOption = "-encoders"
        ExpectedValues = @(
            "aac_mf"
            "mp3_mf"
        )
        NotExpectedValues = @("_qsv")
        IsEnabled = (Get-IsOnWindowsOS)
    },
    @{
        Name = "EncodersMac"
        CmdOption = "-encoders"
        ExpectedValues = @(
            " aac_at "
        )
        NotExpectedValues = @()
        IsEnabled = (Get-IsOnMacOS)
    },
    @{
        Name = "Decoders"
        CmdOption = "-decoders"
        ExpectedValues = @(
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
        NotExpectedValues = @()
        IsEnabled = $true
    },
    @{
        Name = "DecodersMac"
        CmdOption = "-decoders"
        ExpectedValues = @(
            " aac_at "
        )
        NotExpectedValues = @()
        IsEnabled = (Get-IsOnMacOS)
    },
    @{
        Name = "DecodersWin"
        CmdOption = "-decoders"
        ExpectedValues = @()
        NotExpectedValues = @("_qsv")
        IsEnabled = (Get-IsOnWindowsOS)
    },
    @{
        Name = "Muxers"
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
        Name = "Demuxers"
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
        Name = "Filters"
        CmdOption = "-filters"
        ExpectedValues = @(
            " aresample "
            " asetrate "
            " atempo "
            " scale "
        )
        NotExpectedValues = @()
        IsEnabled = $true
    },
    @{
        Name = "HwaccelsWin"
        CmdOption = "-hwaccels"
        ExpectedValues = @(
            "dxva2"
            "d3d11va"
            "d3d12va"
        )
        NotExpectedValues = @("qsv")
        IsEnabled = (Get-IsOnWindowsOS)
    },
    @{
        Name = "HwaccelsMac"
        CmdOption = "-hwaccels"
        ExpectedValues = @(
           "videotoolbox"
        )
        NotExpectedValues = @()
        IsEnabled = (Get-IsOnMacOS)
    }
)

$features = Get-Features $PackageAndFeatures
$expectedVp8Vp9Av1Encoders = @()
$notExpectedVp8Vp9Av1Encoders = @()

if($features -contains "encoder-libvpx-vp8") { $expectedVp8Vp9Av1Encoders += " libvpx " } else { $notExpectedVp8Vp9Av1Encoders += " libvpx " }
if($features -contains "encoder-libvpx-vp9") { $expectedVp8Vp9Av1Encoders += " libvpx-vp9 " } else { $notExpectedVp8Vp9Av1Encoders += " libvpx-vp9 " }
if($features -contains "encoder-libaom-av1") { $expectedVp8Vp9Av1Encoders += " libaom-av1 " } else { $notExpectedVp8Vp9Av1Encoders += " libaom-av1 " }
if($features -contains "encoder-av1-vulkan") { $expectedVp8Vp9Av1Encoders += " av1_vulkan " } else { $notExpectedVp8Vp9Av1Encoders += " av1_vulkan " }

$expectedH264HevcEncoders = @()
$notExpectedH264HevcEncoders = @()
if($features -contains "encoder-h264-mf") { $expectedH264HevcEncoders += " h264_mf " }
elseif($features -contains "encoder-h264-videotoolbox") { $expectedH264HevcEncoders += " h264_videotoolbox " }
else { $notExpectedH264HevcEncoders += " h264_mf "; $notExpectedH264HevcEncoders += " h264_videotoolbox " }

if($features -contains "encoder-hevc-mf") { $expectedH264HevcEncoders += " hevc_mf " }
elseif($features -contains "encoder-hevc-videotoolbox") { $expectedH264HevcEncoders += " hevc_videotoolbox " }
else { $notExpectedH264HevcEncoders += " hevc_mf "; $notExpectedH264HevcEncoders += " hevc_videotoolbox " }

$expectedH264HevcDecoders = @()
$notExpectedH264HevcDecoders = @()
if($features -contains "decoder-h264") { $expectedH264HevcDecoders += " h264 " } else { $notExpectedH264HevcDecoders += " h264 " }
if($features -contains "decoder-hevc") { $expectedH264HevcDecoders += " hevc " } else { $notExpectedH264HevcDecoders += " hevc " }

$expectedVp8Vp9Av1Decoders = @()
$notExpectedVp8Vp9Av1Decoders = @()

if($features -contains "decoder-vp8") { $expectedVp8Vp9Av1Decoders += " vp8 " } else { $notExpectedVp8Vp9Av1Decoders += " vp8 " }
if($features -contains "decoder-vp9") { $expectedVp8Vp9Av1Decoders += " vp9 " } else { $notExpectedVp8Vp9Av1Decoders += " vp9 " }
if($features -contains "decoder-av1") { $expectedVp8Vp9Av1Decoders += " av1 " } else { $notExpectedVp8Vp9Av1Decoders += " av1 " }

$expectedHwaccelsFromFeatures = @()
if(($features | Where-Object { $_ -match "^hwaccel-.*-d3d11va2?$" }).Count -gt 0) { $expectedHwaccelsFromFeatures += "d3d11va" }
if(($features | Where-Object { $_ -match "^hwaccel-.*-d3d12va$" }).Count -gt 0) { $expectedHwaccelsFromFeatures += "d3d12va" }
if(($features | Where-Object { $_ -match "^hwaccel-.*-dxva2$" }).Count -gt 0) { $expectedHwaccelsFromFeatures += "dxva2" }
if(($features | Where-Object { $_ -match "^hwaccel-.*-videotoolbox$" }).Count -gt 0) { $expectedHwaccelsFromFeatures += "videotoolbox" }
if(($features | Where-Object { $_ -match "^hwaccel-.*-vulkan$" }).Count -gt 0) { $expectedHwaccelsFromFeatures += "vulkan" }

$tests += @(
@{
   Name = "EncodersMacH264"
   CmdOption = "-encoders"
   ExpectedValues = ($features -contains "encoder-h264-videotoolbox") ? @( " h264_videotoolbox " ) : @()
   NotExpectedValues = ($features -contains "encoder-h264-videotoolbox") ? @() : @( " h264_videotoolbox " )
   IsEnabled = (Get-IsOnMacOS)
},
@{
   Name = "EncodersWinH264"
   CmdOption = "-encoders"
   ExpectedValues = ($features -contains "encoder-h264-mf") ? @( " h264_mf " ) : @()
   NotExpectedValues = ($features -contains "encoder-h264-mf") ? @() : @( " h264_mf " )
   IsEnabled = (Get-IsOnWindowsOS)
},
@{
   Name = "EncodersVp8Vp9Av1FeatureDriven"
   CmdOption = "-encoders"
   ExpectedValues = $expectedVp8Vp9Av1Encoders
   NotExpectedValues = $notExpectedVp8Vp9Av1Encoders
   IsEnabled = $true
},
@{
   Name = "EncodersH264HevcFeatureDriven"
   CmdOption = "-encoders"
   ExpectedValues = $expectedH264HevcEncoders
   NotExpectedValues = $notExpectedH264HevcEncoders
   IsEnabled = $true
},
@{
   Name = "DecodersVp8Vp9Av1FeatureDriven"
   CmdOption = "-decoders"
   ExpectedValues = $expectedVp8Vp9Av1Decoders
   NotExpectedValues = $notExpectedVp8Vp9Av1Decoders
   IsEnabled = $true
},
@{
   Name = "DecodersH264HevcFeatureDriven"
   CmdOption = "-decoders"
   ExpectedValues = $expectedH264HevcDecoders
   NotExpectedValues = $notExpectedH264HevcDecoders
   IsEnabled = $true
},
@{
   Name = "DecodersHEVC"
   CmdOption = "-decoders"
   ExpectedValues = ($features -contains "decoder-hevc") ? @( " hevc " ) : @()
   NotExpectedValues = ($features -contains "decoder-hevc") ? @() : @( " hevc " )
   IsEnabled = $true
},
@{
   Name = "DemuxersHEVC"
   CmdOption = "-demuxers"
   ExpectedValues = ($features -contains "demuxer-hevc") ? @( " hevc " ) : @()
   NotExpectedValues = ($features -contains "demuxer-hevc") ? @() : @( " hevc " )
   IsEnabled = $true
},
@{
   Name = "MuxersOGG"
   CmdOption = "-muxers"
   ExpectedValues = ($features -contains "muxer-ogg") ? @( " ogg " ) : @()
   NotExpectedValues = ($features -contains "muxer-ogg") ? @() : @( " ogg " )
   IsEnabled = $true
},
@{
   Name = "DemuxersOGG"
   CmdOption = "-demuxers"
   ExpectedValues = ($features -contains "demuxer-ogg") ? @( " ogg " ) : @()
   NotExpectedValues = ($features -contains "demuxer-ogg") ? @() : @( " ogg " )
   IsEnabled = $true
},
@{
   Name = "MuxersWAV"
   CmdOption = "-muxers"
   ExpectedValues = ($features -contains "muxer-wav") ? @( " wav " ) : @()
   NotExpectedValues = ($features -contains "muxer-wav") ? @() : @( " wav " )
   IsEnabled = $true
},
@{
   Name = "HwaccelsFeatureDriven"
   CmdOption = "-hwaccels"
   ExpectedValues = $expectedHwaccelsFromFeatures
   NotExpectedValues = @("qsv", "nvdec")
   IsEnabled = $true
},
@{
   Name = "ForbiddenEncoders"
   CmdOption = "-encoders"
   ExpectedValues = @()
   NotExpectedValues = @("_qsv", "_nvenc", "_amf")
   IsEnabled = $true
},
@{
   Name = "ForbiddenDecoders"
   CmdOption = "-decoders"
   ExpectedValues = @()
   NotExpectedValues = @("_qsv", "_cuvid", "_amf")
   IsEnabled = $true
}
)

$runMsg     = " RUN      "
$successMsg = "       OK "
$failMsg    = "     FAIL "
$finalExitCode = 0
Write-Host "Running capabilities tests..."
foreach($test in $tests) {
    if(-not $test.IsEnabled) {
        continue
    }

    $outFile = "$OutputDir/$($test.Name).txt"
    $cmd = "$ffmpegExe $($test.CmdOption) > $outFile"
    
    Write-Host ""
    Write-Host "--------------------------------------------------"
    Write-Host "Test Group: $($test.Name)"
    Write-Host "--------------------------------------------------"
    #Write-Host "> Executing: $cmd"
    Invoke-Expression $cmd
    $fileContent = Get-Content -Path $outFile -Raw
    
    #Write-Host "`n> Inspecting $outFile for expected values..."
    foreach($expectedValue in $test.ExpectedValues) {
        $testName = "$($test.Name) - '$($expectedValue)' exists"
        Write-Host "[ $runMsg ] $testName"
        $startTime = Get-Date

        $isSuccess = $fileContent.Contains($expectedValue)

        $totalTime = (Get-Date) - $startTime
        $statusMsg = ($isSuccess ? $successMsg : $failMsg)
        Write-Host "[ $statusMsg ] $testName ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor ($isSuccess ? "Green" : "Red")
        if ( ($finalExitCode -eq 0) -and (-not $isSuccess) ) {
            $finalExitCode = -1
        }
    }
    
    if( -not $test.NotExpectedValues ) {
        continue
    }
    #Write-Host "`n> Inspecting $outFile for not expected values..."
    foreach($notExpectedValue in $test.NotExpectedValues) {
        $testName = "$($test.Name) - '$($notExpectedValue)' does NOT exist"
        Write-Host "[ $runMsg ] $testName"
        $startTime = Get-Date

        $isSuccess = ( -not ($fileContent.Contains($notExpectedValue)) )
        
        $totalTime = (Get-Date) - $startTime
        $statusMsg = ($isSuccess ? $successMsg : $failMsg)
        Write-Host "[ $statusMsg ] $testName ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor ($isSuccess ? "Green" : "Red")
        if ( ($finalExitCode -eq 0) -and (-not $isSuccess) ) {
            $finalExitCode = -1
        }
    }
}

Write-Host "`nCapabilities tests complete"
#Write-Host "Exit $finalExitCode"

Exit $finalExitCode
