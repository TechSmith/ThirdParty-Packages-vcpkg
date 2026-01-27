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

Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Test: Verify no AVX-512 instructions (zmm registers)"
Write-Host "--------------------------------------------------"

# Platform-specific configuration
$disassemblerPath = $null
$disassemblerCmd = $null
$binariesToCheck = @()

if ((Get-IsOnWindowsOS)) {
    Write-Host "Platform: Windows" -ForegroundColor Cyan
    
    # Find objdump executable
    $possiblePaths = @(
        "C:\msys64\mingw64\bin\objdump.exe",
        "C:\msys64\usr\bin\objdump.exe",
        "C:\Program Files\Git\usr\bin\objdump.exe",
        "C:\Program Files (x86)\Git\usr\bin\objdump.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $disassemblerPath = $path
            break
        }
    }
    
    # Try to find objdump in PATH
    if (-not $disassemblerPath) {
        $objdumpInPath = Get-Command "objdump.exe" -ErrorAction SilentlyContinue
        if ($objdumpInPath) {
            $disassemblerPath = $objdumpInPath.Source
        }
    }
    
    if (-not $disassemblerPath) {
        Write-Host "[ $failMsg ] objdump not found - cannot verify AVX-512 instructions" -ForegroundColor Red
        Write-Host "Please install objdump (e.g., via MSYS2, Git for Windows, or binutils)" -ForegroundColor Yellow
        Exit 1
    }
    
    Write-Host "Using disassembler: $disassemblerPath" -ForegroundColor Cyan
    $disassemblerCmd = { param($path, $output) & $disassemblerPath -d $path > $output 2>&1 }
    
    # Find Windows binaries: whisper.dll and whisper-cli.exe
    $whisperDll = "$BuildArtifactsPath/bin/whisper.dll"
    if (Test-Path $whisperDll) {
        $binariesToCheck += $whisperDll
    }
    
    if (Test-Path $WhisperCliExePath) {
        $binariesToCheck += $WhisperCliExePath
    }
}
elseif ((Get-IsOnMacOS)) {
    Write-Host "Platform: macOS" -ForegroundColor Cyan
    
    # On macOS, use otool which is pre-installed with Xcode Command Line Tools
    $otoolPath = Get-Command "otool" -ErrorAction SilentlyContinue
    
    if (-not $otoolPath) {
        Write-Host "[ $failMsg ] otool not found - cannot verify AVX-512 instructions" -ForegroundColor Red
        Write-Host "Please install Xcode Command Line Tools: xcode-select --install" -ForegroundColor Yellow
        Exit 1
    }
    
    $disassemblerPath = $otoolPath.Source
    Write-Host "Using disassembler: $disassemblerPath" -ForegroundColor Cyan
    $disassemblerCmd = { param($path, $output) & otool -tV $path > $output 2>&1 }
    
    # Find macOS binaries: libwhisper.dylib and whisper-cli
    $whisperDylib = "$BuildArtifactsPath/lib/libwhisper.dylib"
    if (Test-Path $whisperDylib) {
        $binariesToCheck += $whisperDylib
    }
    
    # Also check tools directory
    $whisperToolsDylib = "$BuildArtifactsPath/tools/whisper-cpp/libwhisper.dylib"
    if (Test-Path $whisperToolsDylib) {
        $binariesToCheck += $whisperToolsDylib
    }
    
    if (Test-Path $WhisperCliExePath) {
        $binariesToCheck += $WhisperCliExePath
    }
}
else {
    Write-Host "[ $failMsg ] Unsupported platform - this test only runs on Windows and macOS" -ForegroundColor Red
    Exit 1
}

if ($binariesToCheck.Count -eq 0) {
    Write-Host "[ $failMsg ] No binaries found to check" -ForegroundColor Red
    Exit 1
}

Write-Host "Checking $($binariesToCheck.Count) binary file(s) for AVX-512 instructions..."
Write-Host ""

$overallSuccess = $true
$totalZmmReferences = 0

foreach ($binaryPath in $binariesToCheck) {
    $binaryName = Split-Path -Leaf $binaryPath
    Write-Host "[ $runMsg ] Checking: $binaryName"
    $startTime = Get-Date
    
    if (-Not (Test-Path $binaryPath)) {
        Write-Host "[ $failMsg ] Binary not found: $binaryPath" -ForegroundColor Red
        $overallSuccess = $false
        $finalExitCode = 1
        continue
    }
    
    # Run disassembler and search for zmm register references
    # AVX-512 uses zmm0-zmm31 registers
    $outputFile = "$OutputDir/$binaryName-disassembly.txt"
    
    try {
        # Disassemble the binary using platform-specific tool
        & $disassemblerCmd $binaryPath $outputFile
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ $failMsg ] Disassembler failed with exit code $LASTEXITCODE" -ForegroundColor Red
            $overallSuccess = $false
            $finalExitCode = 1
            continue
        }
        
        # Search for zmm register references (case-insensitive)
        $zmmMatches = Select-String -Path $outputFile -Pattern '\bzmm\d+\b' -AllMatches
        
        $zmmCount = 0
        if ($zmmMatches) {
            $zmmCount = ($zmmMatches | Measure-Object).Count
            $totalZmmReferences += $zmmCount
        }
        
        $totalTime = (Get-Date) - $startTime
        
        if ($zmmCount -eq 0) {
            Write-Host "[ $successMsg ] $binaryName - No AVX-512 instructions found ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Green
        } else {
            Write-Host "[ $failMsg ] $binaryName - Found $zmmCount AVX-512 instruction(s) with zmm registers ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor Red
            Write-Host ">> Disassembly saved to: $outputFile" -ForegroundColor Yellow
            Write-Host ">> Sample zmm references:" -ForegroundColor Yellow
            
            # Show first few matches as examples
            $sampleMatches = $zmmMatches | Select-Object -First 5
            foreach ($match in $sampleMatches) {
                Write-Host "   Line $($match.LineNumber): $($match.Line.Trim())" -ForegroundColor Yellow
            }
            
            if ($zmmCount -gt 5) {
                Write-Host "   ... and $($zmmCount - 5) more" -ForegroundColor Yellow
            }
            
            $overallSuccess = $false
            $finalExitCode = 1
        }
    }
    catch {
        Write-Host "[ $failMsg ] Error checking $binaryName : $_" -ForegroundColor Red
        $overallSuccess = $false
        $finalExitCode = 1
    }
}

Write-Host ""
Write-Host "--------------------------------------------------"
if ($overallSuccess) {
    Write-Host "PASS: No AVX-512 instructions found in any binaries" -ForegroundColor Green
} else {
    Write-Host "FAIL: Found $totalZmmReferences AVX-512 instruction(s) across checked binaries" -ForegroundColor Red
    Write-Host "This build contains AVX-512 code and will crash on CPUs without AVX-512 support!" -ForegroundColor Red
}
Write-Host "--------------------------------------------------"

Exit $finalExitCode
