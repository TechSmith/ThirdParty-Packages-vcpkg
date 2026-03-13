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
$tests = @()
$features = Get-Features $PackageAndFeatures
$resourcesDir = "$PSScriptRoot/../../resources" 

# H.264 decode tests
$features = Get-Features $PackageAndFeatures
$inputH264Video = "$PSScriptRoot/../../resources/BigBuckBunnyClip-h264-240p.mp4"
$ffmpegDecodeH264FrameCmd = "$ffmpegExe -i `"$inputH264Video`" -ss 00:00:04.5 -frames:v 1"
$tests += 
@{
   Name = "Verify decoding fails - MP4: h.264"
   OutFilename = "h264-frame.png"
   CmdPrefix = "$ffmpegDecodeH264FrameCmd"
   ExpectedReturnCode = if(Get-IsOnWindowsOS) { -22 } elseif(Get-IsOnMacOS) { 234 } else { -1 }
}

# HEVC decode tests
$inputVideo = "$resourcesDir/BigBuckBunnyClip-hevc-240p.mp4"
$ffmpegCmd = "$ffmpegExe -i `"$inputVideo`" -ss 00:00:04.5 -frames:v 1"
if($features -contains "decoder-hevc")
{
   $tests += 
   @{
      Name = "Verify decoding succeeds - MP4: hevc"
      OutFilename = "hevc-frame.png"
      CmdPrefix = "$ffmpegCmd"
      ExpectedReturnCode = 0
   }
}
else
{
   $tests += 
   @{
      Name = "Verify decoding fails - MP4: hevc"
      OutFilename = "hevc-frame.png"
      CmdPrefix = "$ffmpegCmd"
      ExpectedReturnCode = if(Get-IsOnWindowsOS) { -22 } elseif(Get-IsOnMacOS) { 234 } else { -1 }
   }
}

$finalExitCode = Run-FFmpeg-Decoding-Tests -tests $tests -OutputDir $OutputDir

Exit $finalExitCode