Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# Dawn uses a custom overlay port in custom-ports/dawn/ (committed to the repo).
# All TechSmith customizations (non-monolithic build, tint header install,
# SPIRV-Tools copy, CTAD fix, etc.) are baked directly into that overlay portfile.
# No runtime patching needed.
Write-Message "Dawn: using custom overlay port in custom-ports/dawn/"
