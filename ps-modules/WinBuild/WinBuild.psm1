function Set-DllVersionInfo {
    param (
        [string]$filePath,
        [hashtable]$fileInfo
    )

    if (-not $fileInfo.ContainsKey("filename")) {
        Write-Message "Missing 'filename' in the file info. Skipping..."
        return
    }

    Write-Message "Setting version info for: $filePath"
    $fileInfo.Keys | Where-Object { $_ -ne "filename" } | ForEach-Object {
        $type = $_
        $rceditType = switch ($type) {
            "fileVersion" { "--set-file-version" }
            "productVersion" { "--set-product-version" }
            "copyright" { "--set-version-string `"LegalCopyright`"" }
            "productName" { "--set-version-string `"ProductName`"" }
            "fileDescription" { "--set-version-string `"FileDescription`"" }
            Default { $null }
        }

        $value = $fileInfo[$type]

        if ($rceditType) {
            if ($null -ne $value) {
               Invoke-Expression "./rcedit.exe `"$filePath`" $rceditType `"$value`""
            }
        } else {
            Write-Message "Invalid VersionInfoType: $type"
        }
    }
}

function Update-VersionInfoForDlls {
    param (
        [string]$buildArtifactsPath,
        [string]$versionInfoJsonPath
    )

    if (-not (Get-IsOnWindowsOS)) {
        Write-Message "This function is only supported on Windows."
        return
    }

    $versionInfo = Get-Content $versionInfoJsonPath | ConvertFrom-Json
    $files = $versionInfo.files
    foreach ($fileInfo in $files) {
        $filePath = Join-Path $buildArtifactsPath $fileInfo.filename

        # Convert $fileInfo to a hashtable
        $fileInfoHashtable = @{
            filename = $fileInfo.filename
            fileDescription = $fileInfo.fileDescription
            fileVersion = $fileInfo.fileVersion
            productName = $fileInfo.productName
            productVersion = $fileInfo.productVersion
            copyright = $fileInfo.copyright
        }

        Set-DllVersionInfo -filePath $filePath -fileInfo $fileInfoHashtable
    }
}

Export-ModuleMember -Function Update-VersionInfoForDlls
