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

$audioFiles = @(
    @{ Name = "jfk.wav"; Path = "$PSScriptRoot/../../resources/jfk.wav" },
    @{ Name = "rf_lec10_10min.wav"; Path = "$PSScriptRoot/../../resources/rf_lec10_10min.wav" }
)
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

foreach ($audioFile in $audioFiles) {
    if (-Not (Test-Path $audioFile.Path)) {
        Write-Host "Audio file not found: $($audioFile.Path)" -ForegroundColor Red
        Exit 1
    }
}

Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Test: Transcription speed benchmark (warmup analysis)"
Write-Host "--------------------------------------------------"

$testName = "Transcription speed benchmark"
Write-Host "[ $runMsg ] $testName"

# Set up environment for Windows (add bin directory to PATH for DLL resolution)
$originalPath = $env:PATH
$binDir = "$BuildArtifactsPath/bin"
if (Test-Path $binDir) {
    $env:PATH = "$binDir;$env:PATH"
}

# Prepare command
$gpuFlagDisplay = if ($noGpuFlag) { "$noGpuFlag " } else { "" }
$gpuFlagCmd = if ($noGpuFlag) { "$noGpuFlag " } else { "" }

# Process each audio file
foreach ($audioFile in $audioFiles) {
    Write-Host ""
    Write-Host "[ $runMsg ] Transcription speed benchmark - $($audioFile.Name)"
    
    # Array to store run times
    $runTimes = @()
    
    # Run transcription 6 times (1 warmup + 5 measurements)
    Write-Host ""
    Write-Host "Running transcription 6 times (1 warmup + 5 measurements)..."
    Write-Host ""
    for ($i = 1; $i -le 6; $i++) {
        # Print the start message without newline
        Write-Host "> $i/6: Transcribing $($audioFile.Name)" -NoNewline
        
        $outputFile = "$OutputDir/$($audioFile.Name)-transcription-run$i"
        $cmd = "& `"$whisperCli`" $gpuFlagCmd-m `"$modelPath`" -f `"$($audioFile.Path)`" -otxt -of `"$outputFile`""
        
        # Start timer
        $startTime = Get-Date
        
        # Run the command (suppress output)
        Invoke-Expression $cmd 2>&1 | Out-Null
        $cmdExitCode = $LASTEXITCODE
        
        # Stop timer and calculate elapsed time
        $endTime = Get-Date
        $elapsedMs = ($endTime - $startTime).TotalMilliseconds
        
        # Check if command succeeded
        if ($cmdExitCode -ne 0) {
            Write-Host " - FAILED (exit code $cmdExitCode)" -ForegroundColor Red
            $finalExitCode = $cmdExitCode
            break
        }
        
        # Append the elapsed time to the same line
        $runTimes += $elapsedMs
        Write-Host " ($([math]::Round($elapsedMs, 0))ms)" -ForegroundColor Green
        
        # Pause 2 seconds between runs (except after the last run)
        if ($i -lt 6) {
            Start-Sleep -Seconds 2
        }
    }
    
    # Calculate and display results for this audio file
    if ($runTimes.Count -eq 6 -and $finalExitCode -eq 0) {
        Write-Host ""
        Write-Host "--------------------------------------------------"
        Write-Host "Performance Results for $($audioFile.Name):"
        Write-Host "--------------------------------------------------"
        
        $warmupTime = $runTimes[0]
        $measurementRuns = $runTimes[1..5]
        $avgMeasurementTime = ($measurementRuns | Measure-Object -Average).Average
        $minTime = ($measurementRuns | Measure-Object -Minimum).Minimum
        $maxTime = ($measurementRuns | Measure-Object -Maximum).Maximum
        
        Write-Host ""
        Write-Host "Warmup run (cold start):       $([math]::Round($warmupTime, 2)) ms" -ForegroundColor Yellow
        Write-Host "Runs 2-6 (individual times):   $([string]::Join(', ', ($measurementRuns | ForEach-Object { [math]::Round($_, 2) }))) ms" -ForegroundColor Cyan
        Write-Host "Runs 2-6 (average):            $([math]::Round($avgMeasurementTime, 2)) ms" -ForegroundColor Green
        Write-Host "Runs 2-6 (min):                $([math]::Round($minTime, 2)) ms" -ForegroundColor Green
        Write-Host "Runs 2-6 (max):                $([math]::Round($maxTime, 2)) ms" -ForegroundColor Green
        Write-Host ""
        
        # Calculate speedup (if warmup was slower)
        if ($warmupTime -gt $avgMeasurementTime) {
            $speedup = $warmupTime / $avgMeasurementTime
            Write-Host "Warm-up speedup: $([math]::Round($speedup, 2))x faster after warmup" -ForegroundColor Magenta
        }
        Write-Host ""
        Write-Host "[ $successMsg ] Transcription speed benchmark - $($audioFile.Name)" -ForegroundColor Green
    }
    elseif ($finalExitCode -ne 0) {
        Write-Host ""
        Write-Host "[ $failMsg ] Transcription speed benchmark - $($audioFile.Name)" -ForegroundColor Red
        break
    }
    else {
        Write-Host ""
        Write-Host "[ $failMsg ] Transcription speed benchmark - $($audioFile.Name) - Did not complete all 6 runs" -ForegroundColor Red
        $finalExitCode = -1
        break
    }
}

# Restore original PATH
$env:PATH = $originalPath

# Final result
if ($finalExitCode -eq 0) {
    Write-Host ""
    Write-Host "[ $successMsg ] $testName" -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "[ $failMsg ] $testName" -ForegroundColor Red
}

Exit $finalExitCode
