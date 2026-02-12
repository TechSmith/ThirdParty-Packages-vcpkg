param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$true)][string]$WhisperCliExePath,
    [Parameter(Mandatory=$true)][string]$ModulesRoot,
    [Parameter(Mandatory=$true)][string]$ShouldBeEnabled,  # Passed as "1" or "0" string
    [Parameter(Mandatory=$false)][string]$OutputDir = "test-output"
)

# Convert string "1" or "0" to boolean
$ShouldBeEnabledBool = ($ShouldBeEnabled -eq "1")

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

$testMode = if ($ShouldBeEnabledBool) { "enabled" } else { "disabled" }
Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Test: Verify AVX2 is $testMode"
Write-Host "--------------------------------------------------"

# Verify whisper-cli exists
if (-Not (Test-Path $WhisperCliExePath)) {
    Write-Host "[ $failMsg ] whisper-cli not found: $WhisperCliExePath" -ForegroundColor Red
    Exit 1
}

Write-Host "[ $runMsg ] Running whisper-cli to check system info..."
$startTime = Get-Date

# Download a test model if not present
$modelDir = "$OutputDir/WhisperModels"
if (-Not (Test-Path $modelDir)) {
    New-Item -ItemType Directory -Path $modelDir | Out-Null
}

$modelPath = "$modelDir/ggml-tiny-q5_1.bin"
$modelUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q5_1.bin?download=true"

if (-Not (Test-Path $modelPath)) {
    Write-Host "Downloading Whisper model..."
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $modelUrl -OutFile $modelPath -UseBasicParsing
        $ProgressPreference = 'Continue'
    }
    catch {
        Write-Host "[ $failMsg ] Failed to download model: $_" -ForegroundColor Red
        Exit 1
    }
}

# Set up environment for Windows (add bin directory to PATH for DLL resolution)
$originalPath = $env:PATH
$binDir = "$BuildArtifactsPath/bin"
if (Test-Path $binDir) {
    $env:PATH = "$binDir;$env:PATH"
}

# Run whisper-cli with a short audio file to trigger system_info output
# system_info is only printed during actual processing, not with --help
$audioFile = "$PSScriptRoot/../../resources/jfk.wav"
if (-Not (Test-Path $audioFile)) {
    Write-Host "[ $failMsg ] Audio file not found: $audioFile" -ForegroundColor Red
    Exit 1
}

$systemInfoFile = "$OutputDir/system-info-avx2.txt"
$cmd = "& `"$WhisperCliExePath`" -m `"$modelPath`" -f `"$audioFile`" 2>&1 | Out-File -FilePath `"$systemInfoFile`" -Encoding UTF8"

try {
    Invoke-Expression $cmd
    
    # Restore original PATH
    $env:PATH = $originalPath
    
    # Check if output file was created
    if (-Not (Test-Path $systemInfoFile)) {
        $totalTime = (Get-Date) - $startTime
        Write-Host "[ $failMsg ] Failed to capture system info ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Red
        Exit 1
    }
    
    # Read system info
    $systemInfo = Get-Content -Path $systemInfoFile -Raw
    
    # Extract just the system_info line
    $systemInfoLine = ""
    if ($systemInfo -match 'system_info:([^\n]+)') {
        $systemInfoLine = $matches[1]
        Write-Host "> System info line:"
        Write-Host "system_info:$systemInfoLine"
    } else {
        $totalTime = (Get-Date) - $startTime
        Write-Host "[ $failMsg ] Could not find system_info line in output ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Red
        Exit 1
    }
    
    # Check for AVX2 setting in system_info output
    $avx2Found = $false
    $avx2Value = 0
    
    if ($systemInfoLine -match 'AVX2\s*=\s*(\d+)') {
        $avx2Found = $true
        $avx2Value = [int]$matches[1]
        Write-Host "> Found AVX2 setting: AVX2 = $avx2Value"
    } else {
        Write-Host "> AVX2 not found in system_info output (feature not compiled in)"
    }
    
    $totalTime = (Get-Date) - $startTime
    
    # Determine if the test passed based on expected state
    $testPassed = $false
    
    if ($ShouldBeEnabledBool) {
        # AVX2 should be enabled (AVX2 = 1)
        if ($avx2Found -and $avx2Value -eq 1) {
            Write-Host "[ $successMsg ] AVX2 is correctly enabled (AVX2 = 1) ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Green
            $testPassed = $true
        } elseif ($avx2Found -and $avx2Value -eq 0) {
            Write-Host "[ $failMsg ] AVX2 is unexpectedly disabled (AVX2 = 0) ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Red
            Write-Host ">> This build SHOULD have AVX2 support when built with the avx2 feature" -ForegroundColor Red
            $testPassed = $false
        } else {
            Write-Host "[ $failMsg ] AVX2 not found in system_info ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Red
            Write-Host ">> This build SHOULD have AVX2 support when built with the avx2 feature" -ForegroundColor Red
            $testPassed = $false
        }
    } else {
        # AVX2 should be disabled (AVX2 = 0 or not present)
        if ($avx2Found -and $avx2Value -eq 1) {
            Write-Host "[ $failMsg ] AVX2 is unexpectedly enabled (AVX2 = 1) ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Red
            Write-Host ">> This build should NOT have AVX2 support when built without the avx2 feature" -ForegroundColor Red
            $testPassed = $false
        } elseif ($avx2Found -and $avx2Value -eq 0) {
            Write-Host "[ $successMsg ] AVX2 is correctly disabled (AVX2 = 0) ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Green
            $testPassed = $true
        } else {
            Write-Host "[ $successMsg ] AVX2 is correctly disabled (not compiled in) ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Green
            $testPassed = $true
        }
    }
    
    if (-not $testPassed) {
        $finalExitCode = 1
    }
}
catch {
    $env:PATH = $originalPath
    Write-Host "[ $failMsg ] Error running whisper-cli: $_" -ForegroundColor Red
    $finalExitCode = 1
}

Write-Host ""
Write-Host "--------------------------------------------------"
if ($finalExitCode -eq 0) {
    Write-Host "PASS: AVX2 status is correct ($testMode)" -ForegroundColor Green
} else {
    Write-Host "FAIL: AVX2 status verification failed (expected $testMode)" -ForegroundColor Red
}
Write-Host "--------------------------------------------------"

Exit $finalExitCode
