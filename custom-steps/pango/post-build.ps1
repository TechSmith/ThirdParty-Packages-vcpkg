param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$false)][string]$PackageAndFeatures,
    [Parameter(Mandatory=$false)][string]$LinkType,
    [Parameter(Mandatory=$false)][string]$BuildType,
    [Parameter(Mandatory=$false)][string]$ModulesRoot,
    [Parameter(Mandatory=$false)][string[]]$Triplets
)

$moduleName = "Build"
if(-not (Get-Module -Name $moduleName)) {
    Import-Module "$ModulesRoot/$moduleName" -Force -DisableNameChecking
}

if((Get-IsOnWindowsOS)) {
    Update-VersionInfoForDlls -buildArtifactsPath $buildArtifactsPath -versionInfoJsonPath "$PSScriptRoot/version-info.json"
}

if((Get-IsOnMacOS)) {
    # Clean up setuptools if we installed it
    $stateFile = "$PSScriptRoot/.setuptools-state.txt"
    if (Test-Path $stateFile) {
        $state = Get-Content -Path $stateFile -Raw
        $state = $state.Trim()
        
        if ($state -eq "INSTALLED") {
            Write-Message "Uninstalling setuptools (was installed by pre-build)..."
            python3 -m pip uninstall -y setuptools 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Message "> setuptools uninstalled successfully"
            } else {
                Write-Message "> Warning: setuptools uninstallation failed (exit code: $LASTEXITCODE)"
                # Reset exit code to prevent build failure
                $global:LASTEXITCODE = 0
            }
        } elseif ($state -eq "PREEXISTING") {
            Write-Message "Skipping setuptools cleanup (was pre-existing)"
        }
        
        # Remove state file
        Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
    }
}

