Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

if (-not (Get-IsOnWindowsOS)) {
    exit
}

# Check if glslc (Vulkan SDK) is already available
$glslcPath = Get-Command glslc -ErrorAction SilentlyContinue
if ($glslcPath) {
    Write-Message "Vulkan SDK (glslc) already installed at: $($glslcPath.Source)"
    exit
}

Write-Message "Vulkan SDK not found. Downloading and extracting Vulkan SDK..."

try {
    # Vulkan SDK version
    $vulkanVersion = "1.3.290.0"
    $installerUrl = "https://sdk.lunarg.com/sdk/download/$vulkanVersion/windows/VulkanSDK-$vulkanVersion-Installer.exe"
    
    # Create temporary directory for Vulkan SDK
    $tempDir = Join-Path $env:TEMP "VulkanSDK-$vulkanVersion"
    $installerPath = Join-Path $env:TEMP "vulkan-sdk-$vulkanVersion.exe"
    $extractDir = Join-Path $tempDir "extracted"
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
    
    # Download the installer if not already cached
    if (Test-Path $installerPath) {
        Write-Message "Using cached Vulkan SDK installer: $installerPath"
    } else {
        Write-Message "Downloading Vulkan SDK installer ($vulkanVersion)..."
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
        Write-Message "Downloaded Vulkan SDK installer"
    }
    
    # Download 7-Zip console version to extract the installer
    # We need the full 7z.exe (not 7zr or 7za) to handle PE executables
    $sevenZipUrl = "https://www.7-zip.org/a/7z2409-x64.exe"  # 7-Zip installer (self-extracting)
    $sevenZipInstaller = Join-Path $env:TEMP "7z-installer.exe"
    $sevenZipDir = Join-Path $env:TEMP "7zip-portable"
    
    if (-not (Test-Path (Join-Path $sevenZipDir "7z.exe"))) {
        Write-Message "Downloading 7-Zip..."
        
        # Download 7-Zip installer
        Invoke-WebRequest -Uri $sevenZipUrl -OutFile $sevenZipInstaller -UseBasicParsing
        
        # Extract the installer itself (it's also a 7z archive)
        New-Item -ItemType Directory -Path $sevenZipDir -Force | Out-Null
        
        # Use PowerShell to run the self-extractor with /S /D flags
        $extractProc = Start-Process -FilePath $sevenZipInstaller -ArgumentList "/S", "/D=$sevenZipDir" -Wait -PassThru -NoNewWindow
        
        if ($extractProc.ExitCode -ne 0) {
            Write-Error "Failed to install 7-Zip"
            exit 1
        }
        
        Write-Message "Installed 7-Zip"
    } else {
        Write-Message "Using cached 7-Zip"
    }
    
    $sevenZipPath = Join-Path $sevenZipDir "7z.exe"
    
    if (-not (Test-Path $sevenZipPath)) {
        Write-Error "Could not find 7z.exe after installation"
        exit 1
    }
    
    # Extract the installer using 7-Zip
    Write-Message "Extracting Vulkan SDK installer (this may take a minute)..."
    
    $extractProcess = Start-Process -FilePath $sevenZipPath -ArgumentList "x", $installerPath, "-o$extractDir", "-y" -Wait -PassThru -NoNewWindow
    
    if ($extractProcess.ExitCode -ne 0) {
        Write-Error "Failed to extract Vulkan SDK installer with exit code: $($extractProcess.ExitCode)"
        exit 1
    }
    
    Write-Message "Extraction completed"
    
    # Find glslc.exe in the extracted files
    $glslcExtracted = Get-ChildItem -Path $extractDir -Filter "glslc.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($glslcExtracted) {
        $vulkanBinDir = Split-Path $glslcExtracted.FullName -Parent
        Write-Message "Found glslc.exe at: $vulkanBinDir"
        
        # Add to PATH for this session
        $env:PATH = "$vulkanBinDir;$env:PATH"
        
        # Set VULKAN_SDK environment variable (parent of Bin directory)
        $vulkanSdkDir = Split-Path $vulkanBinDir -Parent
        $env:VULKAN_SDK = $vulkanSdkDir
        
        Write-Message "Added Vulkan SDK to PATH: $vulkanBinDir"
        Write-Message "Set VULKAN_SDK: $vulkanSdkDir"
        
        # Verify glslc is now accessible
        $glslcPath = Get-Command glslc -ErrorAction SilentlyContinue
        if ($glslcPath) {
            Write-Message "SUCCESS: Vulkan SDK (glslc) is now available at: $($glslcPath.Source)"
        } else {
            Write-Error "Failed to make glslc available in PATH"
            exit 1
        }
    } else {
        Write-Error "Could not find glslc.exe in extracted installer"
        exit 1
    }
    
} catch {
    Write-Error "Failed to download/extract Vulkan SDK: $_"
    exit 1
}
