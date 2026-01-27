param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$true)][string]$WhisperCliExePath,
    [Parameter(Mandatory=$true)][string]$ModulesRoot,
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

$runMsg     = " RUN      "
$successMsg = "       OK "
$failMsg    = "     FAIL "
$finalExitCode = 0

# Use local model from resources directory
$modelPath = "$PSScriptRoot/../../resources/models/whisper/ggml-tiny-q5_1.bin"
$audioFile = "$PSScriptRoot/../../resources/jfk.wav"
$whisperCli = $WhisperCliExePath

# Detect paravirtualized GPU environment on macOS
$noGpuFlag = ""
$gpuWarningDisplayed = $false

if ((Get-IsOnMacOS)) {
    Write-Host "`nDetecting GPU environment..." -ForegroundColor Cyan
    
    try {
        # Use system_profiler to get GPU information
        $gpuInfo = system_profiler SPDisplaysDataType 2>$null | Select-String -Pattern "Chipset Model:"
        
        if ($gpuInfo) {
            $gpuName = ($gpuInfo -split "Chipset Model:\s*")[1].Trim()
            Write-Host "> GPU detected: $gpuName" -ForegroundColor Cyan
            
            # Check if this is a paravirtual GPU
            if ($gpuName -match "Paravirtual|VMware|VirtualBox|Parallels") {
                Write-Host "" -ForegroundColor Yellow
                Write-Host "WARNING: Paravirtualized GPU detected!" -ForegroundColor Yellow
                Write-Host "  GPU: $gpuName" -ForegroundColor Yellow
                Write-Host "  This virtual GPU has limited Metal support and may cause assertion failures" -ForegroundColor Yellow
                Write-Host "  in the Metal backend. Running whisper-cli with --no-gpu flag to use CPU-only mode." -ForegroundColor Yellow
                Write-Host "" -ForegroundColor Yellow
                
                $noGpuFlag = "--no-gpu"
                $gpuWarningDisplayed = $true
            }
            else {
                Write-Host "> Full Metal GPU support available. GPU acceleration will be used." -ForegroundColor Green
            }
        }
        else {
            # Fallback: Try to detect via ioreg (more reliable for virtual environments)
            $ioregInfo = ioreg -l -w0 2>$null | Select-String -Pattern "model.*=" | Select-Object -First 1
            
            if ($ioregInfo -and ($ioregInfo -match "Paravirtual|VMware|VirtualBox|Parallels")) {
                Write-Host "" -ForegroundColor Yellow
                Write-Host "WARNING: Paravirtualized GPU environment detected!" -ForegroundColor Yellow
                Write-Host "  This virtual GPU has limited Metal support and may cause assertion failures" -ForegroundColor Yellow
                Write-Host "  in the Metal backend. Running whisper-cli with --no-gpu flag to use CPU-only mode." -ForegroundColor Yellow
                Write-Host "" -ForegroundColor Yellow
                
                $noGpuFlag = "--no-gpu"
                $gpuWarningDisplayed = $true
            }
            else {
                Write-Host "> Full Metal GPU support detected. GPU acceleration will be used." -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "> Could not detect GPU type. Assuming full Metal support is available." -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# Verify required files exist
if (-Not (Test-Path $modelPath)) {
    Write-Host "Model file not found: $modelPath" -ForegroundColor Red
    Exit 1
}

if (-Not (Test-Path $audioFile)) {
    Write-Host "Audio file not found: $audioFile" -ForegroundColor Red
    Exit 1
}

# Define the test
$tests = @(
    @{
        Name = "Transcribe JFK audio with tiny-q5_1 model"
        AudioFile = $audioFile
        ModelFile = $modelPath
        OutputFile = "$OutputDir/jfk-transcription.txt"
        ExpectedPhrases = @(
            "ask not what your country can do for you",
            "ask what you can do for your country"
        )
    }
)

Write-Host "Running transcription tests..."
foreach($test in $tests) {
    Write-Host ""
    Write-Host "--------------------------------------------------"
    Write-Host "Test: $($test.Name)"
    Write-Host "--------------------------------------------------"
    
    $testName = $test.Name
    Write-Host "[ $runMsg ] $testName"
    $startTime = Get-Date

    # Set up environment for Windows (add bin directory to PATH for DLL resolution)
    $originalPath = $env:PATH
    $binDir = "$BuildArtifactsPath/bin"
    if (Test-Path $binDir) {
        $env:PATH = "$binDir;$env:PATH"
    }
    
    # Run whisper-cli (with --no-gpu flag if running on paravirtual GPU)
    $gpuFlagDisplay = if ($noGpuFlag) { "$noGpuFlag " } else { "" }
    $gpuFlagCmd = if ($noGpuFlag) { "$noGpuFlag " } else { "" }
    $cmd = "& `"$whisperCli`" $gpuFlagCmd-m `"$($test.ModelFile)`" -f `"$($test.AudioFile)`" -otxt -of `"$OutputDir/jfk-transcription`""
    Write-Host "> Executing: whisper-cli $gpuFlagDisplay-m `"$($test.ModelFile)`" -f `"$($test.AudioFile)`" -otxt -of `"$OutputDir/jfk-transcription`""
    
    Invoke-Expression $cmd
    $cmdExitCode = $LASTEXITCODE
    
    # Restore original PATH
    $env:PATH = $originalPath
    
    # Check if command succeeded
    if ($cmdExitCode -ne 0) {
        $totalTime = (Get-Date) - $startTime
        Write-Host "[ $failMsg ] $testName - Command failed with exit code $cmdExitCode ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Red
        $finalExitCode = $cmdExitCode
        continue
    }
    
    # Verify output file was created
    if (-Not (Test-Path $test.OutputFile)) {
        $totalTime = (Get-Date) - $startTime
        Write-Host "[ $failMsg ] $testName - Output file not created ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Red
        $finalExitCode = -1
        continue
    }
    
    # Read and check transcription content
    $transcription = Get-Content -Path $test.OutputFile -Raw
    Write-Host "> Transcription output:"
    Write-Host $transcription
    
    # Check for expected phrases (case-insensitive)
    $allPhrasesFound = $true
    foreach($expectedPhrase in $test.ExpectedPhrases) {
        $phraseFound = $transcription -match [regex]::Escape($expectedPhrase)
        if (-not $phraseFound) {
            # Try case-insensitive match
            $phraseFound = $transcription -imatch [regex]::Escape($expectedPhrase)
        }
        if (-not $phraseFound) {
            Write-Host ">> Expected phrase not found: '$expectedPhrase'" -ForegroundColor Yellow
            $allPhrasesFound = $false
        } else {
            Write-Host ">> Found expected phrase: '$expectedPhrase'" -ForegroundColor Green
        }
    }
    
    $totalTime = (Get-Date) - $startTime
    $isSuccess = $allPhrasesFound
    $statusMsg = if ($isSuccess) { $successMsg } else { $failMsg }
    $statusColor = if ($isSuccess) { "Green" } else { "Red" }
    Write-Host "[ $statusMsg ] $testName ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor $statusColor
    
    if ( ($finalExitCode -eq 0) -and (-not $isSuccess) ) {
        $finalExitCode = -1
    }
}

Write-Host "`nTranscription tests complete"

Exit $finalExitCode
