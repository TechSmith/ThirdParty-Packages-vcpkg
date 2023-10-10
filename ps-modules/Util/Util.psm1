function Show-FileContent {
    param (
        [string]$FilePath
    )

    Write-Message "Getting contents of `"$FilePath`""
    $fileContent = ""
    try {
        $fileContent = Get-Content -Path $FilePath -ErrorAction Stop
        Write-Message ">> Success"
    } catch {
        Write-Message ">> Error: $_.Exception.Message"
    }

    Write-Message ""
    Write-Message "Contents of `"$FilePath`"" with original line endings
    Write-Message "--START-----------------------------------------------------"
    Write-Message $fileContent
    Write-Message "--END-------------------------------------------------------"

    Write-Message ""
    Write-Message "Contents of `"$FilePath`"" with normalized line endings
    Write-Message "--START-----------------------------------------------------"
    Write-Output $fileContent
    Write-Message "--END-------------------------------------------------------"
}

function Install-FromVcpkg {
    param(
        [string] $Package,
        [string] $Triplet,
        [string] $VcpkgExe
    )

    $pkgToInstall = "${Package}:${Triplet}"
    Write-Message "Installing package: `"$pkgToInstall`""
    Invoke-Expression "$VcpkgExe install `"$pkgToInstall`" --overlay-triplets=`"custom-triplets`" --overlay-ports=`"custom-ports`""
}

function Exit-IfError {
    param (
        [int]$ExitCode
    )

    if ($ExitCode -ne 0) {
        Write-Message "Error: The last command returned an exit code of $ExitCode." 
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

    Invoke-Expression $expression
}

function Write-Banner {
    param (
        [string]$Title,
        [int]$Level = 1
    )

    $bannerChars = @("*", "=", "-", ".")
    $bannerHorizontalBorderSizes = @(2, 1, 1, 1)

    $bannerSize = 80
    $bannerChar = $bannerChars[$Level - 1]
    $bannerHorizontalBorderSize = $bannerHorizontalBorderSizes[$Level - 1]
    $bannerLine = $bannerChar * $bannerSize
    $titleLine = "$($bannerChar * $bannerHorizontalBorderSize) $Title $(' ' * $($bannerSize - $Title.Length - ($bannerHorizontalBorderSize * 2 + 3))) $($bannerChar * $bannerHorizontalBorderSize)"

    [Console]::Out.Flush()
    Write-Message "$(NL)$bannerLine$(NL)$titleLine$(NL)$bannerLine"
    [Console]::Out.Flush()
}

function Write-Message {
    param (
        [string]$Message
    )
    [Console]::Out.Flush()
    Write-Host $Message
    [Console]::Out.Flush()
}

function NL {
   return [System.Environment]::NewLine
}

Export-ModuleMember -Function Show-FileContent
Export-ModuleMember -Function Install-FromVcpkg
Export-ModuleMember -Function Exit-IfError
Export-ModuleMember -Function Write-ReleaseInfoJson
Export-ModuleMember -Function Get-IsOnMacOS
Export-ModuleMember -Function Get-IsOnWindowsOS
Export-ModuleMember -Function Invoke-Powershell
Export-ModuleMember -Function Write-Banner
Export-ModuleMember -Function Write-Message
Export-ModuleMember -Function NL

$IsOnMacOS = Get-IsOnMacOS
if ( $IsOnMacOS ) {
   Import-Module "$PSScriptRoot/../../ps-modules/MacUtil"
   Export-ModuleMember -Function ConvertTo-UniversalBinaries
   Export-ModuleMember -Function Remove-DylibSymlinks
}
