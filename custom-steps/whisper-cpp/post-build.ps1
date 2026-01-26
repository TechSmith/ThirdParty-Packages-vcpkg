param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$false)][string]$PackageAndFeatures,
    [Parameter(Mandatory=$false)][string]$LinkType,
    [Parameter(Mandatory=$false)][string]$BuildType,
    [Parameter(Mandatory=$false)][string]$ModulesRoot,
    [Parameter(Mandatory=$false)][string[]]$Triplets
)

# Import modules
$moduleNames = @("Build", "Util")
foreach( $moduleName in $moduleNames ) {
    if(-not (Get-Module -Name $moduleName)) {
        Import-Module "$ModulesRoot/$moduleName" -Force -DisableNameChecking
    }
}

if((Get-IsOnWindowsOS)) {
    # Dynamically find the whisper DLL (could be whisper.dll or whisper-basic.dll)
    $binPath = "$BuildArtifactsPath/bin"
    $whisperDll = Get-ChildItem -Path $binPath -Filter "whisper*.dll" -File | Select-Object -First 1
    
    if ($whisperDll) {
        Write-Message "> Found whisper DLL: $($whisperDll.Name)"
        
        # Update version-info.json with the actual DLL name
        $versionInfoPath = "$PSScriptRoot/version-info.json"
        $versionInfo = Get-Content $versionInfoPath | ConvertFrom-Json
        $versionInfo.files[0].filename = "bin/$($whisperDll.Name)"
        $versionInfo | ConvertTo-Json -Depth 10 | Set-Content $versionInfoPath
        
        Update-VersionInfoForDlls -buildArtifactsPath $BuildArtifactsPath -versionInfoJsonPath $versionInfoPath
    }
    else {
        Write-Message "WARNING: No whisper DLL found in $binPath"
    }
}

if((Get-IsOnMacOS)) {
    # Update library paths in tools to match the consolidated dylib names
    Write-Message "> Updating library paths in /tools/whisper-cpp/..."
    $toolsPath = "$BuildArtifactsPath/tools/whisper-cpp"
    
    if (Test-Path $toolsPath) {
        $files = Get-ChildItem -Path $toolsPath -Attributes !Hidden
        foreach ($binaryPath in $files) {
            Write-Message "   > Updating: $binaryPath"
            $otoolOutput = & "otool" "-L" $binaryPath
            foreach ($line in $otoolOutput) {
                # Match versioned dylib paths like @rpath/libwhisper.1.8.2.dylib
                if ($line -match '@rpath\/([^\.]+)\.[^\/]*\.dylib') {
                    $originalPath = $matches[0]
                    $newPath = "@rpath/$($matches[1]).dylib"
                    Write-Message "      >> Updating $originalPath to $newPath"
                    & "install_name_tool" "-change" $originalPath $newPath $binaryPath
                }
            }
        }
    }
    
    # Copy dylib files to tools directory so executables can find them at runtime
    Write-Message "> Copying dylib files to tools directory..."
    $libDir = "$BuildArtifactsPath/lib"
    
    if (Test-Path $toolsPath) {
        $dylibFiles = Get-ChildItem -Path $libDir -Filter "libwhisper*.dylib" -File
        foreach ($dylib in $dylibFiles) {
            $destPath = Join-Path -Path $toolsPath -ChildPath $dylib.Name
            Write-Message "   > Copying: $($dylib.Name) to $toolsPath"
            Copy-Item -Path $dylib.FullName -Destination $destPath -Force
        }
    }
}

# Determine path to whisper-cli executable
$pathToTools = "$BuildArtifactsPath/tools/whisper-cpp"
$pathToWhisperCliExe = ""
if((Get-IsOnWindowsOS)) {
    $pathToWhisperCliExe = "$pathToTools/whisper-cli.exe"
}
elseif((Get-IsOnMacOS)) {
    $pathToWhisperCliExe = "$pathToTools/whisper-cli"
}
elseif((Get-IsOnLinux)) {
    $pathToWhisperCliExe = "$pathToTools/whisper-cli"
}

# Run tests
if (Test-Path $pathToWhisperCliExe) {
    Write-Message "$(NL)Running post-build tests..."
    $finalExitCode = 0
    $testScriptArgs = @{ 
        BuildArtifactsPath = $BuildArtifactsPath
        WhisperCliExePath = $pathToWhisperCliExe
        ModulesRoot = $ModulesRoot
        OutputDir = "test-output"
    }
    Push-Location $PSScriptRoot
    if (Test-Path $testScriptArgs.OutputDir) {
        Remove-Item -Path $testScriptArgs.OutputDir -Recurse -Force
    }
    
    $testScripts = @(
        "test001--verify-transcription.ps1"
    )
    
    # Add AVX-512 verification test only on Windows
    if((Get-IsOnWindowsOS)) {
        $testScripts += "test002--verify-no-avx512.ps1"
    }
    foreach($testScript in $testScripts) {
        Write-Message "$(NL)Running tests: $testScript..."
        Invoke-Powershell -FilePath "$testScript" -ArgumentList $testScriptArgs
        $scriptReturnCode = $LASTEXITCODE
        if ( ($finalExitCode -eq 0) -and ($scriptReturnCode -ne 0) ) {
            $finalExitCode = $scriptReturnCode
        }
    }
    
    Pop-Location
    
    if ($finalExitCode -ne 0) {
        Exit $finalExitCode
    }
}
else {
    Write-Message "whisper-cli not found at $pathToWhisperCliExe, skipping tests"
}
