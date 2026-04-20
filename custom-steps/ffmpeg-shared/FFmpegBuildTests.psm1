
function Run-FFmpeg-Capabilities-Tests {
    param(
        [Object[]]$tests,
        [string]$OutputDir,
        [string]$ffmpegExe
    )

    # For example values for $tests objects, see ffmpeg/test001--query-capabilities.ps1

    $runMsg     = " RUN      "
    $successMsg = "       OK "
    $failMsg    = "     FAIL "
    $finalExitCode = 0
    Write-Host "Running capabilities tests..."
    foreach($test in $tests) {
        if(-not $test.IsEnabled) {
            continue
        }

        $outFile = "$OutputDir/$($test.Name).txt"
        $cmd = "$ffmpegExe $($test.CmdOption) > $outFile"
        
        Write-Host ""
        Write-Host "--------------------------------------------------"
        Write-Host "Test Group: $($test.Name)"
        Write-Host "--------------------------------------------------"
        #Write-Host "> Executing: $cmd"
        Invoke-Expression $cmd
        $fileContent = Get-Content -Path $outFile -Raw
        
        #Write-Host "`n> Inspecting $outFile for expected values..."
        foreach($expectedValue in $test.ExpectedValues) {
            $testName = "$($test.Name) - '$($expectedValue)' exists"
            Write-Host "[ $runMsg ] $testName"
            $startTime = Get-Date

            $isSuccess = $fileContent.Contains($expectedValue)

            $totalTime = (Get-Date) - $startTime
            $statusMsg = ($isSuccess ? $successMsg : $failMsg)
            Write-Host "[ $statusMsg ] $testName ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor ($isSuccess ? "Green" : "Red")
            if ( ($finalExitCode -eq 0) -and (-not $isSuccess) ) {
                $finalExitCode = -1
            }
        }
        
        if( -not $test.NotExpectedValues ) {
            continue
        }
        #Write-Host "`n> Inspecting $outFile for not expected values..."
        foreach($notExpectedValue in $test.NotExpectedValues) {
            $testName = "$($test.Name) - '$($notExpectedValue)' does NOT exist"
            Write-Host "[ $runMsg ] $testName"
            $startTime = Get-Date

            $isSuccess = ( -not ($fileContent.Contains($notExpectedValue)) )
            
            $totalTime = (Get-Date) - $startTime
            $statusMsg = ($isSuccess ? $successMsg : $failMsg)
            Write-Host "[ $statusMsg ] $testName ($($totalTime.TotalMilliseconds) ms)" -ForegroundColor ($isSuccess ? "Green" : "Red")
            if ( ($finalExitCode -eq 0) -and (-not $isSuccess) ) {
                $finalExitCode = -1
            }
        }
    }

    Write-Host "`nCapabilities tests complete"
    #Write-Host "Exit $finalExitCode"

    return $finalExitCode
}

function Run-FFmpeg-Decoding-Tests {
    param(
        [Object[]]$tests,
        [string]$OutputDir
    )

    # For example values for $tests objects, see ffmpeg/test002--verify-decoding.ps1

    $runMsg     = " RUN      "
    $successMsg = "       OK "
    $failMsg    = "     FAIL "
    $finalExitCode = 0
    Write-Host "Running decoding tests..."
    foreach ($test in $tests) {
        $OutFilePath = "$OutputDir/$($test.OutFilename)"
        $cmd = "$($test.CmdPrefix) `"$OutFilePath`""
        Write-Host "[ $runMsg ] $($test.Name) ==> $OutFilePath"
        $startTime = Get-Date

        #Write-Host ">> Executing FFMpeg command"
        #Write-Host "$cmd"
        Invoke-Expression $cmd
        $cmdExitCode = $LASTEXITCODE

        $expectedReturnCode = if ($test.ContainsKey('ExpectedReturnCode')) { $test.ExpectedReturnCode } else { 0 }
        Write-Host ">> Expected return code = $expectedReturnCode.  Actual return code = $cmdExitCode"

        $isSuccess = ($cmdExitCode -eq $expectedReturnCode)
        if ( ($finalExitCode -eq 0) -and (-not $isSuccess) ) {
            $finalExitCode = $cmdExitCode
        }
        $statusMsg = ($isSuccess ? $successMsg : $failMsg)
        $failSuffix = ($isSuccess ? "" : " | CMD EXIT CODE = $cmdExitCode")
        $totalTime = (Get-Date) - $startTime
        Write-Host "[ $statusMsg ] $($test.Name) ($($totalTime.TotalMilliseconds) ms)$failSuffix" -ForegroundColor ($isSuccess ? "Green" : "Red")
    }

    Write-Host "`nEncoding tests complete."

    return $finalExitCode
}

function Run-FFmpeg-Encoding-Tests {
    param(
        [Object[]]$tests,
        [string]$OutputDir
    )

    $runMsg     = " RUN      "
    $successMsg = "       OK "
    $failMsg    = "     FAIL "
    $finalExitCode = 0
    Write-Host "Running encoding tests..."
    foreach ($test in $tests) {
        $OutFilePath = "$OutputDir/$($test.OutFilename)"
        $cmd = "$($test.CmdPrefix) `"$OutFilePath`""
        Write-Host "[ $runMsg ] $($test.Name) ==> $OutFilePath"
        $startTime = Get-Date

        Write-Host ">> Executing FFMpeg command"
        Write-Host "$cmd"
        Invoke-Expression $cmd
        $cmdExitCode = $LASTEXITCODE

        $expectedReturnCode = if ($test.ContainsKey('ExpectedReturnCode')) { $test.ExpectedReturnCode } else { 0 }
        Write-Host ">> Expected return code = $expectedReturnCode.  Actual return code = $cmdExitCode"

        $isSuccess = ($cmdExitCode -eq $expectedReturnCode)
        if ( ($finalExitCode -eq 0) -and (-not $isSuccess) ) {
            $finalExitCode = $cmdExitCode
        }
        $statusMsg = ($isSuccess ? $successMsg : $failMsg)
        $failSuffix = ($isSuccess ? "" : " | CMD EXIT CODE = $cmdExitCode")
        $totalTime = (Get-Date) - $startTime
        Write-Host "[ $statusMsg ] $($test.Name) ($($totalTime.TotalMilliseconds) ms)$failSuffix" -ForegroundColor ($isSuccess ? "Green" : "Red")
    }

    Write-Host "`nEncoding tests complete."

    return $finalExitCode
}

function Run-FFmpeg-Filters-Tests {
    param(
        [Object[]]$tests,
        [string]$OutputDir
    )

    $runMsg     = " RUN      "
    $successMsg = "       OK "
    $failMsg    = "     FAIL "
    $finalExitCode = 0
    Write-Host "Running decoding tests..."
    foreach ($test in $tests) {
        $OutFilePath = "$OutputDir/$($test.OutFilename)"
        $cmd = "$($test.CmdPrefix) `"$OutFilePath`""
        Write-Host "[ $runMsg ] $($test.Name) ==> $OutFilePath"
        $startTime = Get-Date

        #Write-Host ">> Executing FFMpeg command"
        #Write-Host "$cmd"
        Invoke-Expression $cmd
        $cmdExitCode = $LASTEXITCODE

        $expectedReturnCode = if ($test.ContainsKey('ExpectedReturnCode')) { $test.ExpectedReturnCode } else { 0 }
        Write-Host ">> Expected return code = $expectedReturnCode.  Actual return code = $cmdExitCode"

        $isSuccess = ($cmdExitCode -eq $expectedReturnCode)
        if ( ($finalExitCode -eq 0) -and (-not $isSuccess) ) {
            $finalExitCode = $cmdExitCode
        }
        $statusMsg = ($isSuccess ? $successMsg : $failMsg)
        $failSuffix = ($isSuccess ? "" : " | CMD EXIT CODE = $cmdExitCode")
        $totalTime = (Get-Date) - $startTime
        Write-Host "[ $statusMsg ] $($test.Name) ($($totalTime.TotalMilliseconds) ms)$failSuffix" -ForegroundColor ($isSuccess ? "Green" : "Red")
    }

    Write-Host "`nEncoding tests complete."

    return $finalExitCode
}

Export-ModuleMember -Function Run-FFmpeg-Capabilities-Tests, Run-FFmpeg-Decoding-Tests, Run-FFmpeg-Encoding-Tests, Run-FFmpeg-Filters-Tests