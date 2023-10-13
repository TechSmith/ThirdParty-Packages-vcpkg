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

function Exit-IfError {
    param (
        [int]$ExitCode
    )

    if ($ExitCode -ne 0) {
        Write-Message "Error: The last command returned an exit code of $ExitCode." 
        exit $ExitCode
    }
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
    $titleLine = "$($bannerChar * $bannerHorizontalBorderSize) $Title"

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

function Get-PSObjectAsFormattedList
{
    param(
        [PSObject]$Object
    )

    $output = ""
    $count = 0
    $keys = $Object.Keys | Sort-Object $_
    foreach ($key in $keys) {
        $value = $Object[$key]
        $output += "$(if($count -gt 0) { NL } )- $key`: $value"
        $count++
    }
    return $output
}

function Write-Debug { 
    param(
       [string]$message
    )
    if($global:showDebug) {
        Write-Message $message
    }
}

function Run-ScriptIfExists {
   param(
      [string]$title,
      [string]$script,
      [PSObject]$scriptArgs
   )
   if ( -not (Test-Path -Path $script -PathType Leaf) ) {
      return
   }
   Write-Banner -Level 3 -Title $title
   Invoke-Powershell -FilePath $script -ArgumentList $scriptArgs
}

Export-ModuleMember -Function Show-FileContent, Install-FromVcpkg, Exit-IfError, Write-ReleaseInfoJson, Get-IsOnMacOS, Get-IsOnWindowsOS, Invoke-Powershell, Write-Banner, Write-Message, Write-Debug, NL, Get-PSObjectAsFormattedList, Run-ScriptIfExists
