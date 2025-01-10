param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
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
        )
        NotExpectedValues = @(" hevc "," h264 ")
        IsEnabled = $true
    },
    @{
        Name = "EncodersWin"
        CmdOption = "-encoders"
        ExpectedValues = @(
            "aac_mf"
            "mp3_mf"
            "h264_mf"
            "hevc_mf"
        )
        NotExpectedValues = @()
        IsEnabled = (Get-IsOnWindowsOS)
    },
    @{
        Name = "EncodersMac"
        CmdOption = "-encoders"
        ExpectedValues = @(
            " aac_at "
            " h264_videotoolbox "
            " hevc_videotoolbox "
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
            " hevc "
            " libaom-av1 "
            " libdav1d "
            " libopus "
            " libvorbis "
            " libvpx "
            " libvpx-vp9 "
            " mp3 "
            "pcm_"
            " vp8 "
            " vp9 "
        )
        NotExpectedValues = @(" h264 ")
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
        Name = "Muxers"
        CmdOption = "-muxers"
        ExpectedValues = @(
            " matroska "
            " mkvtimestamp_v2 "
            " mp3 "
            " mp4 "
            " mpegts "
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
            " hevc "
            " matroska,webm "
            " mov,mp4,m4a,3gp,3g2,mj2 "
            " mp3 "
            " mpegts "
            " mpegtsraw "
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
        NotExpectedValues = @()
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
