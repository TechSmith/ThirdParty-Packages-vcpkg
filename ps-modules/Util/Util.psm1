function Show-FileContent {
    param (
        [string]$FilePath
    )

    Write-Host "Getting contents of `"$FilePath`""
    $fileContent = ""
    try {
        $fileContent = Get-Content -Path $FilePath -ErrorAction Stop
        Write-Host ">> Success"
    } catch {
        Write-Host ">> Error: $_.Exception.Message"
    }

    Write-Host ""
    Write-Host "Contents of `"$FilePath`"" with original line endings
    Write-Host "--START-----------------------------------------------------"
    Write-Host $fileContent
    Write-Host "--END-------------------------------------------------------"

    Write-Host ""
    Write-Host "Contents of `"$FilePath`"" with normalized line endings
    Write-Host "--START-----------------------------------------------------"
    Write-Output $fileContent
    Write-Host "--END-------------------------------------------------------"
}

function Install-FromVcpkg {
    param(
        [string] $Package,
        [string] $Triplet,
        [string] $VcpkgExe
    )

    $pkgToInstall = "${Package}:${Triplet}"
    Write-Host "Installing package: `"$pkgToInstall`""
    Invoke-Expression "$VcpkgExe install `"$pkgToInstall`" --overlay-triplets=`"custom-triplets`" --overlay-ports=`"custom-ports`""
}

function Exit-IfError {
    param (
        [int]$ExitCode
    )

    if ($ExitCode -ne 0) {
        Write-Host "Error: The last command returned an exit code of $ExitCode." 
        exit $ExitCode
    }
}

function Write-ReleaseInfoJson {
    param(
        [string] $PackageDisplayName,
        [string] $ReleaseTagBaseName,
        [string] $ReleaseVersion,
        [string] $PathToJsonFile
    )
    $releaseInfo = @{
        PackageDisplayName = $PackageDisplayName
        ReleaseTagBaseName = $ReleaseTagBaseName
        ReleaseVersion = $ReleaseVersion
    }
    $releaseInfo | ConvertTo-Json | Set-Content -Path $PathToJsonFile
}

function Get-PackageNameOnly {
   param (
      [string] $PackageNameAndFeatures
   )
   return $PackageAndFeatures -replace '\[.*$', ''
}

function Get-IsOnWindowsOS {
    if ($env:OS -like '*win*') {
        return $true
    }
    return $false
}

function Get-IsOnMacOS {
    if ($PSVersionTable.OS -like '*Darwin*') {
        return $true
    }
    return $false
}

function Invoke-Powershell {
    param (
        [string]$FilePath,
        [PSObject]$ArgumentList
    )

    $invokePrefix = ""
    
    if (-not $IsOnWindowsOS) {
        $invokePrefix = "pwsh "
    }

    $expression = "$invokePrefix./$FilePath"

    if ($ArgumentList) {
        foreach ($key in $ArgumentList.Keys) {
            $value = $ArgumentList[$key]
            $expression += " -$key $value"
        }
    }

    Write-Host "Invoke-Expression $expression"
    Invoke-Expression $expression
}

Export-ModuleMember -Function Show-FileContent
Export-ModuleMember -Function Install-FromVcpkg
Export-ModuleMember -Function Exit-IfError
Export-ModuleMember -Function Write-ReleaseInfoJson
Export-ModuleMember -Function Get-PackageNameOnly
Export-ModuleMember -Function Get-IsOnMacOS
Export-ModuleMember -Function Get-IsOnWindowsOS
Export-ModuleMember -Function Invoke-Powershell