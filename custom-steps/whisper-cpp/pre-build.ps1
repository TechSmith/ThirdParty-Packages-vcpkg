param (
    [Parameter(Mandatory=$false)][string]$PackageAndFeatures
)

Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking
Import-Module "$PSScriptRoot/../../scripts/ps-modules/Util" -DisableNameChecking

# Install Vulkan SDK prerequisites only if vulkan feature is enabled (Windows only)
if (Get-IsOnWindowsOS) {
    # Check if vulkan feature is enabled
    $features = Get-Features -packageAndFeatures $PackageAndFeatures
    $hasVulkan = $features -contains "vulkan"
    
    if ($hasVulkan) {
        Write-Message "Vulkan feature detected, installing Vulkan SDK..."
        
        # Dot-source the script to run in the current scope (preserves environment variables)
        . "$PSScriptRoot/install-vulkan-sdk.ps1"
        
        # Verify glslc is now accessible
        $glslcPath = Get-Command glslc -ErrorAction SilentlyContinue
        if ($glslcPath) {
            Write-Message "SUCCESS: Vulkan SDK (glslc) is now available at: $($glslcPath.Source)"
        } else {
            Write-Error "Failed to make glslc available in PATH after Vulkan SDK installation"
            exit 1
        }
    } else {
        Write-Message "Vulkan feature not enabled, skipping Vulkan SDK installation"
    }
}
