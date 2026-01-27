Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

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
    
    # Use project-local tools directory instead of temp
    $projectRoot = Resolve-Path "$PSScriptRoot/../.."
    $toolsDir = Join-Path $projectRoot "tools"
    $extractDir = Join-Path $toolsDir "VulkanSDK\$vulkanVersion"
    $installerPath = Join-Path $toolsDir "vulkan-sdk-$vulkanVersion.exe"
    
    # Create tools directory if it doesn't exist
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
    
    # Download the installer if not already cached
    if (Test-Path $installerPath) {
        Write-Message "Using cached Vulkan SDK installer: $installerPath"
    } else {
        Write-Message "Downloading Vulkan SDK installer ($vulkanVersion)..."
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
        Write-Message "Downloaded Vulkan SDK installer"
    }
    
    # Run installer in unattended mode with copy_only=1
    # This extracts files without system-wide installation (no registry, no PATH modification)
    # Reference: https://vulkan.lunarg.com/doc/sdk/1.3.296.0/windows/getting_started.html
    Write-Message "Extracting Vulkan SDK in unattended mode (copy_only=1)..."
    
    $installArgs = "--root `"$extractDir`" --accept-licenses --default-answer --confirm-command install copy_only=1"
    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    $exitCode = $process.ExitCode
    Write-Message "Installer exited with code: $exitCode"
    
    # Verify that glslc.exe was extracted
    $glslcPath = Join-Path $extractDir "Bin\glslc.exe"
    
    # Wait a bit for filesystem to settle
    Start-Sleep -Seconds 2
    
    if (-not (Test-Path $glslcPath)) {
        Write-Error "Installation appears to have failed - glslc.exe not found at: $glslcPath"
        exit 1
    }
    
    Write-Message "Extraction completed successfully"
    
    # Find glslc.exe in the extracted files
    $glslcExtracted = Get-ChildItem -Path $extractDir -Filter "glslc.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($glslcExtracted) {
        $vulkanBinDir = Split-Path $glslcExtracted.FullName -Parent
        Write-Message "Found glslc.exe at: $vulkanBinDir"
        
        # Set VULKAN_SDK environment variable (parent of Bin directory)
        $vulkanSdkDir = Split-Path $vulkanBinDir -Parent
        
        # Set environment variables directly
        $env:PATH = "$vulkanBinDir;$env:PATH"
        $env:VULKAN_SDK = $vulkanSdkDir
        
        Write-Message "Added Vulkan SDK to PATH: $vulkanBinDir"
        Write-Message "Set VULKAN_SDK environment variable: $vulkanSdkDir"
        Write-Message "SUCCESS: Vulkan SDK extracted and ready"
    } else {
        Write-Error "Could not find glslc.exe in extracted installer"
        exit 1
    }
    
} catch {
    Write-Error "Failed to download/extract Vulkan SDK: $_"
    exit 1
}
