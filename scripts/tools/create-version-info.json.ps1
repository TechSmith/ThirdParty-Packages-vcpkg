param (
    [Parameter(Mandatory=$true)]
    [string]$InputDllDir,

    [Parameter(Mandatory=$true)]
    [string]$OutputJsonFile
)

function Replace-NullWithEmptyString {
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$object
    )

    $object.PSObject.Properties | ForEach-Object {
        if ($_.Value -eq $null) {
            $_.Value = ""
        }
    }
    return $object
}

$filenamePrefix = "bin/"
$results = Get-ChildItem -Path "$InputDllDir/" -Filter "*.dll" | ForEach-Object {
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName)
    $dllInfo = [PSCustomObject]@{
        filename        = "$filenamePrefix$($_.Name)"
        fileDescription = $versionInfo.FileDescription
        fileVersion     = $versionInfo.FileVersion
        productName     = $versionInfo.ProductName
        productVersion  = $versionInfo.ProductVersion
        copyright       = $versionInfo.LegalCopyright
    }
    Replace-NullWithEmptyString -object $dllInfo
}

$jsonOutput = @{
    files = $results
} | ConvertTo-Json -Depth 3

$jsonOutput | Set-Content -Path $OutputJsonFile