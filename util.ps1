function ShowFileContent {
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

function Install-From-Vcpkg {
    param(
        [string] $Package,
        [string] $Triplet,
        [string] $VcpkgExe
    )

    $pkgToInstall = "${Package}:${Triplet}"
    Write-Host "Installing package: `"$pkgToInstall`""
    Invoke-Expression "$VcpkgExe install `"$pkgToInstall`" --overlay-triplets=`"custom-triplets`" --overlay-ports=`"custom-ports`""
}

function Exit-If-Error {
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