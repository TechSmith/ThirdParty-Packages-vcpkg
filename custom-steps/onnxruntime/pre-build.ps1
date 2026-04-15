param(
    [string]$PackageAndFeatures = ""
)

Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

$features = Get-Features $PackageAndFeatures
$cudaEnabled = $features -contains "cuda"
if (-not $cudaEnabled) {
    Write-Message "CUDA feature not enabled, skipping CUDA installation..."
    exit 0
}

if (-not (Get-IsOnWindowsOS)) {
    Write-Message "CUDA installation only needed on Windows, skipping..."
    exit 0
}

Write-Message "CUDA feature enabled. Checking for CUDA installation..."

# Helper function to set environment variables in current scope AND persist them
function Set-CudaEnvironment {
    param([string]$cudaPath)
    
    Write-Message "Configuring CUDA environment variables..."
    
    # Set for current PowerShell session (will be inherited by child processes like vcpkg)
    $env:CUDA_PATH = $cudaPath
    $env:CUDA_HOME = $cudaPath
    $env:CUDA_TOOLKIT_ROOT_DIR = $cudaPath
    
    $cudaBinPath = Join-Path $cudaPath "bin"
    if (Test-Path $cudaBinPath) {
        # Prepend to PATH so it takes precedence
        $env:PATH = "$cudaBinPath;$env:PATH"
        Write-Message "Set CUDA_PATH=$cudaPath"
        Write-Message "Added to PATH: $cudaBinPath"
    }
    
    # Verify nvcc is accessible
    try {
        $nvccPath = Get-Command nvcc -ErrorAction Stop
        Write-Message "Verified nvcc.exe is accessible at: $($nvccPath.Source)"
    } catch {
        Write-Warning "nvcc.exe not found in PATH after configuration"
    }
    
    # Try to set at Machine level for persistence (requires admin)
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        try {
            $currentMachineCudaPath = [Environment]::GetEnvironmentVariable("CUDA_PATH", "Machine")
            if ($currentMachineCudaPath -ne $cudaPath) {
                Write-Message "Setting CUDA environment variables at system level..."
                [Environment]::SetEnvironmentVariable("CUDA_PATH", $cudaPath, "Machine")
                [Environment]::SetEnvironmentVariable("CUDA_HOME", $cudaPath, "Machine")
                [Environment]::SetEnvironmentVariable("CUDA_TOOLKIT_ROOT_DIR", $cudaPath, "Machine")
                
                # Add to system PATH if not already there
                $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                if ($machinePath -notlike "*$cudaBinPath*") {
                    [Environment]::SetEnvironmentVariable("Path", "$machinePath;$cudaBinPath", "Machine")
                }
                Write-Message "System environment variables updated (will persist for future sessions)"
            }
        } catch {
            Write-Warning "Failed to set system environment variables: $_"
        }
    } else {
        Write-Message "(Not running as admin - system environment variables not persisted)"
    }
}

# Check common CUDA installation paths
$cudaPossiblePaths = @(
    $env:CUDA_PATH,
    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4",
    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.3",
    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.2",
    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.1",
    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.0",
    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8",
    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.7"
)

$cudaPath = $null
foreach ($path in $cudaPossiblePaths) {
    if ($path -and (Test-Path $path)) {
        $cudaPath = $path
        break
    }
}

if ($cudaPath) {
    Write-Message "CUDA found at: $cudaPath"
    
    # Check if cuDNN is also present
    $cudnnInclude = Join-Path $cudaPath "include\cudnn.h"
    $cudnnFound = Test-Path $cudnnInclude
    
    if ($cudnnFound) {
        Write-Message "cuDNN headers found at: $cudnnInclude"
    } else {
        Write-Warning "cuDNN not found in CUDA installation"
        Write-Warning "Looking for cuDNN in alternative locations..."
        
        # Check for standalone cuDNN installation
        $cudnnPaths = @(
            $env:CUDNN_ROOT_DIR,
            $env:CUDNN,
            "C:\Program Files\NVIDIA\CUDNN\v9.5",
            "C:\Program Files\NVIDIA\CUDNN\v9.4",
            "C:\Program Files\NVIDIA\CUDNN\v9.3",
            "C:\Program Files\NVIDIA\CUDNN\v9.2",
            "C:\Program Files\NVIDIA\CUDNN\v9.1",
            "C:\Program Files\NVIDIA\CUDNN\v9.0",
            "C:\Program Files\NVIDIA\CUDNN\v8.9"
        )
        
        foreach ($path in $cudnnPaths) {
            if ($path -and (Test-Path "$path\include\cudnn.h")) {
                Write-Message "Found standalone cuDNN at: $path"
                $cudnnFound = $true
                break
            }
        }
        
        if (-not $cudnnFound) {
            Write-Warning "cuDNN not found. The build may fail."
            Write-Warning "cuDNN can be downloaded from: https://developer.nvidia.com/cudnn"
        }
    }
    
    # Configure environment for this build
    Set-CudaEnvironment -cudaPath $cudaPath
    
    Write-Message "CUDA pre-build configuration completed successfully."
    exit 0
}

Write-Message "CUDA Toolkit not found. Attempting automatic installation..."

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    throw @"
CUDA Toolkit not found and automatic installation requires administrator privileges.

Please run PowerShell as Administrator and retry this build.

Alternatively, manually install CUDA Toolkit from: https://developer.nvidia.com/cuda-downloads
"@
}

Write-Message "Running as Administrator - proceeding with CUDA installation..."

# Define CUDA Toolkit version (using local installer for reliability)
$cudaVersion = "12.4.0"
$cudaInstallerUrl = "https://developer.download.nvidia.com/compute/cuda/12.4.0/local_installers/cuda_12.4.0_551.61_windows.exe"
$installerPath = "$env:TEMP\cuda_12.4.0_installer.exe"

Write-Message "Downloading CUDA Toolkit $cudaVersion local installer (~3GB, this may take a while)..."
try {
    # Show progress for large download
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $cudaInstallerUrl -OutFile $installerPath -UseBasicParsing
    $ProgressPreference = 'Continue'
    Write-Message "Download completed."
} catch {
    throw "Failed to download CUDA installer: $_"
}

Write-Message "Installing CUDA Toolkit $cudaVersion (this will take several minutes)..."

try {
    # Create a log file for the CUDA installer
    $logPath = "$env:TEMP\cuda_install_log.txt"

    # Try multiple installation strategies
    $installStrategies = @(
        @{
            Name = "Minimal install (nvcc, runtime, libraries)"
            Args = "-s nvcc_12.4 cudart_12.4 cublas_12.4 cublas_dev_12.4 cufft_12.4 cufft_dev_12.4 curand_12.4 curand_dev_12.4 cusolver_12.4 cusolver_dev_12.4 cusparse_12.4 cusparse_dev_12.4 visual_studio_integration_12.4"
        },
        @{
            Name = "Core components only"
            Args = "-s nvcc_12.4 cudart_12.4 cublas_12.4 cublas_dev_12.4"
        },
        @{
            Name = "Full silent install"
            Args = "-s"
        }
    )

    $installed = $false
    foreach ($strategy in $installStrategies) {
        Write-Message "Trying installation strategy: $($strategy.Name)"
        
        try {
            $process = Start-Process -FilePath $installerPath -ArgumentList $strategy.Args -Wait -PassThru -RedirectStandardOutput "$logPath.out" -RedirectStandardError "$logPath.err" -NoNewWindow
            
            Write-Message "Installer exit code: $($process.ExitCode)"
            
            # Check if installation succeeded (exit code 0) or partially succeeded (non-zero but files exist)
            $defaultCudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4"
            $nvccPath = Join-Path $defaultCudaPath "bin\nvcc.exe"
            
            if (Test-Path $nvccPath) {
                Write-Message "CUDA Toolkit installed successfully at: $defaultCudaPath"
                
                # Check if cuDNN was installed
                $cudnnInclude = Join-Path $defaultCudaPath "include\cudnn.h"
                if (Test-Path $cudnnInclude) {
                    Write-Message "cuDNN headers found - cuDNN installed successfully"
                } else {
                    Write-Warning "cuDNN headers not found in CUDA installation - installing cuDNN separately..."
                    
                    # Download and install cuDNN
                    $cudnnVersion = "9.5.1"
                    $cudnnUrl = "https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/windows-x86_64/cudnn-windows-x86_64-9.5.1.17_cuda12-archive.zip"
                    $cudnnZipPath = "$env:TEMP\cudnn-9.5.1.zip"
                    
                    try {
                        Write-Message "Downloading cuDNN $cudnnVersion (~700MB, this may take a while)..."
                        $ProgressPreference = 'SilentlyContinue'
                        Invoke-WebRequest -Uri $cudnnUrl -OutFile $cudnnZipPath -UseBasicParsing
                        $ProgressPreference = 'Continue'
                        Write-Message "cuDNN download completed."
                        
                        Write-Message "Extracting cuDNN..."
                        $cudnnExtractPath = "$env:TEMP\cudnn-extract"
                        Expand-Archive -Path $cudnnZipPath -DestinationPath $cudnnExtractPath -Force
                        
                        # Find the extracted directory (should be like cudnn-windows-x86_64-9.5.1.17_cuda12-archive)
                        $cudnnDir = Get-ChildItem $cudnnExtractPath -Directory | Select-Object -First 1
                        
                        if ($cudnnDir) {
                            Write-Message "Copying cuDNN files to CUDA installation..."
                            
                            # Copy include files
                            $cudnnIncludeSource = Join-Path $cudnnDir.FullName "include\*"
                            $cudnnIncludeDest = Join-Path $defaultCudaPath "include"
                            Copy-Item -Path $cudnnIncludeSource -Destination $cudnnIncludeDest -Recurse -Force
                            
                            # Copy lib files
                            $cudnnLibSource = Join-Path $cudnnDir.FullName "lib\*"
                            $cudnnLibDest = Join-Path $defaultCudaPath "lib"
                            Copy-Item -Path $cudnnLibSource -Destination $cudnnLibDest -Recurse -Force
                            
                            # Copy bin files (DLLs)
                            $cudnnBinSource = Join-Path $cudnnDir.FullName "bin\*"
                            $cudnnBinDest = Join-Path $defaultCudaPath "bin"
                            Copy-Item -Path $cudnnBinSource -Destination $cudnnBinDest -Recurse -Force
                            
                            Write-Message "cuDNN installed successfully"
                        } else {
                            Write-Warning "Could not find extracted cuDNN directory"
                        }
                        
                        # Clean up
                        Remove-Item $cudnnZipPath -Force -ErrorAction SilentlyContinue
                        Remove-Item $cudnnExtractPath -Recurse -Force -ErrorAction SilentlyContinue
                    } catch {
                        Write-Warning "Failed to install cuDNN automatically: $_"
                        Write-Warning "cuDNN can be downloaded manually from: https://developer.nvidia.com/cudnn"
                    }
                }
                
                # Configure environment for this build
                Set-CudaEnvironment -cudaPath $defaultCudaPath
                $installed = $true
                break
            } elseif ($process.ExitCode -ne 0) {
                Write-Warning "Installation strategy failed with exit code: $($process.ExitCode)"
                if (Test-Path "$logPath.err") {
                    $errContent = Get-Content "$logPath.err" -Raw -ErrorAction SilentlyContinue
                    if ($errContent) {
                        Write-Warning "Error output: $errContent"
                    }
                }
            }
        } catch {
            Write-Warning "Installation attempt failed: $_"
        }
    }

    if (-not $installed) {
        # Clean up log files
        Remove-Item "$logPath*" -Force -ErrorAction SilentlyContinue
        
        throw @"
Failed to install CUDA Toolkit after trying multiple strategies.

Possible causes:
1. Visual Studio C++ build tools not installed (required by CUDA installer)
2. Incompatible Windows version
3. Insufficient disk space
4. Previous partial installation interfering

Manual installation steps:
1. Download CUDA 12.4 from: https://developer.nvidia.com/cuda-12-4-0-download-archive
2. Run the installer manually and select required components
3. Verify nvcc.exe is accessible from command line
4. Re-run this build

Alternatively, try installing with:
  choco install cuda --version=12.4.0
"@
    }
} finally {
    # Clean up installer and logs
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force
        Write-Message "Cleaned up installer file."
    }
    Remove-Item "$env:TEMP\cuda_install_log*" -Force -ErrorAction SilentlyContinue
}

Write-Message "CUDA pre-build step completed successfully."

