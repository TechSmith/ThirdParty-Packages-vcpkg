param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$true)][string]$FFMpegExePath,
    [Parameter(Mandatory=$false)][string]$OutputDir = "test-output"
)

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
            " aac ",
            " libaom-av1 ",
            #" libsvtav1 ",
            " libmp3lame ",
            " libopus ",
            " libvorbis ",
            " libvpx ",
            " libvpx-vp9 "
        )
        NotExpectedValues = @(" hevc "," h264 ")
    }
    @{
        Name = "Decoders"
        CmdOption = "-decoders"
        ExpectedValues = @(
            " aac ",
            " aac_fixed ",
            " aac_latm ",
            " av1 ",
            " hevc ",
            " libaom-av1 ",
            " libdav1d ",
            " libopus ",
            " libvorbis ",
            " libvpx ",
            " libvpx-vp9 ",
            " mp3 ",
            " opus ",
            " pcm ",
            " vorbis ",
            " vp8 ",
            " vp9 "
        )
        NotExpectedValues = @(" h264 ")
    },
    @{
        Name = "Muxers"
        CmdOption = "-muxers"
        ExpectedValues = @(
            " mp3 ", 
            " opus ",
            " webm ",
            " mp4 "
        )
        NotExpectedValues = @()
    },
    @{
        Name = "Demuxers"
        CmdOption = "-demuxers"
        ExpectedValues = @(
            " aac ",
            " hevc ",
            " m4a ",
            " mov ",
            " mp3 ",
            " mp4 ",
            " webm ",
            " mpegts "
        )
        NotExpectedValues = @()
    },
    @{
        Name = "Hwaccels"
        CmdOption = "-hwaccels"
        ExpectedValues = @(
            "dxva2"
            "d3d11va"
            "opencl"
            "d3d12va"
        )
        NotExpectedValues = @()
    }
)

$runMsg     = " RUN      "
$successMsg = "       OK "
$failMsg    = "     FAIL "
$finalExitCode = 0
Write-Host "Running capabilities tests..."
foreach($test in $tests) {
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

        $isSuccess = $fileContent.Contains($notExpectedValue)
        
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
