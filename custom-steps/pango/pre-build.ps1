Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# Helper function to apply vcpkg core patches (not port patches)
function Apply-VcpkgCorePatch {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PatchFile,
        
        [Parameter(Mandatory=$true)]
        [string]$Description
    )
    
    Write-Message "Applying TechSmith patches to vcpkg core ($Description)..."
    
    if (-not (Test-Path $PatchFile)) {
        Write-Message "FATAL: Patch file not found: $PatchFile" -Error
        exit 1
    }
    
    $vcpkgRoot = "$PSScriptRoot/../../vcpkg"
    Push-Location $vcpkgRoot
    try {
        $output = git apply --unidiff-zero --ignore-whitespace "$PatchFile" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Message "> vcpkg core patch ($Description) applied successfully"
        } else {
            $checkOutput = git apply --reverse --check --ignore-whitespace "$PatchFile" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Message "> vcpkg core patch ($Description) already applied (skipping)"
            } else {
                Write-Message "FATAL: Failed to apply vcpkg core patch ($Description)" -Error
                Write-Message "> Git apply exit code: $LASTEXITCODE" -Error
                Write-Message "> Git apply output: $output" -Error
                exit 1
            }
        }
    } finally {
        Pop-Location
    }
}

# Apply patch to vcpkg's pango portfile to add Objective-C language support for macOS
Write-Message "Applying TechSmith patches to vcpkg pango port..."
$patchSuccess = Apply-VcpkgPortPatch -PortName "pango" -PatchFile "$PSScriptRoot/add-objc-language-support.patch"
if (-not $patchSuccess) {
    Write-Message "FATAL: Failed to apply patch to pango port" -Error
    exit 1
}

# Apply patch to vcpkg's harfbuzz portfile to add Objective-C/Objective-C++ language support for macOS
Write-Message "Applying TechSmith patches to vcpkg harfbuzz port..."
$patchSuccess = Apply-VcpkgPortPatch -PortName "harfbuzz" -PatchFile "$PSScriptRoot/1001-tsc-add-objc-support-to-harfbuzz.patch"
if (-not $patchSuccess) {
    Write-Message "FATAL: Failed to apply patch to harfbuzz port" -Error
    exit 1
}

# Apply patches to vcpkg core (scripts and vcpkg-tool-meson port)
# Note: These use git apply directly since they patch core vcpkg infrastructure, not regular ports
Apply-VcpkgCorePatch -PatchFile "$PSScriptRoot/1002-tsc-enable-objcxx-in-get-cmake-vars.patch" -Description "get_cmake_vars OBJCXX support"
Apply-VcpkgCorePatch -PatchFile "$PSScriptRoot/1003-tsc-fix-meson-objcpp-crosscompile.patch" -Description "meson OBJCXX/OBJCPP cross-compile fix"

if ((Get-IsOnMacOS)) {
    Write-Message "Installing build tools via Homebrew..."
    
    # Install build tool prerequisites: autoconf, autoconf-archive, automake, and libtool
    # On the Mac, there is not a clean way to do this with vcpkg.json like there is on Windows.
    # The  dependency tree for these tools is somewhat circular and complex on Mac/Linux, and the 
    # vcpkg maintainers have decided to just assume these tools exist on these environments rather
    # than building them.  See: https://github.com/microsoft/vcpkg/issues/34723#issuecomment-1824852084
    brew install autoconf autoconf-archive automake libtool
    
    Write-Message "Checking for setuptools in user site-packages..."
    
    # Check if setuptools exists in user site-packages (not system-wide)
    $checkScript = @"
import sys, site, os
user_site = site.getusersitepackages()
setuptools_path = os.path.join(user_site, 'setuptools')
sys.exit(0 if os.path.exists(setuptools_path) else 1)
"@
    
    $setuptoolsInUserSpace = $false
    python3 -c $checkScript 2>$null
    if ($LASTEXITCODE -eq 0) {
        $setuptoolsInUserSpace = $true
        Write-Message "> setuptools found in user site-packages"
    } else {
        Write-Message "> setuptools not found in user site-packages"
    }
    
    # Track whether we installed setuptools (for cleanup in post-build)
    $stateFile = "$PSScriptRoot/.setuptools-state.txt"
    if ($setuptoolsInUserSpace) {
        "PREEXISTING" | Set-Content -Path $stateFile
    } else {
        Write-Message "> Installing setuptools to user site-packages..."
        # Use --break-system-packages with --user for externally-managed Python environments (PEP 668)
        # This is safe when combined with --user as it installs to user site-packages only
        python3 -m pip install --user --break-system-packages setuptools
        if ($LASTEXITCODE -eq 0) {
            "INSTALLED" | Set-Content -Path $stateFile
        } else {
            "FAILED" | Set-Content -Path $stateFile
        }
    }
}
