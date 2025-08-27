function Test-WSLPrerequisites {
    param (
        [PSCustomObject]$Logger,
        [string]$WslDistroName
    )
    
    $Logger.WriteLog("INFO", "Checking WSL version...", "Cyan")
    $wslVersionInfo = wsl --version | Select-String "WSL version:"
    if ($wslVersionInfo -match "WSL version: (\d+\.\d+\.\d+\.\d+)") {
        $wslVersion = $matches[1]
        $Logger.WriteLog("SUCCESS", "WSL Version: $wslVersion", "Green")
    }
    else {
        $Logger.WriteLog("WARNING", "Could not determine WSL version. Assuming modern WSL.", "Yellow")
    }
    
    $Logger.WriteLog("INFO", "Checking for prerequisites (git)...", "White")
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $Logger.WriteLog("ERROR", "Git is not installed or not in your PATH.", "Red")
        throw "Git is not installed."
    }
    
    $Logger.WriteLog("SUCCESS", "Prerequisites check completed.", "Green")
    return $true
}

function Test-GitFunctionality {
    param (
        [PSCustomObject]$Logger
    )

    $Logger.WritePhaseStatus("GIT_CHECK", "STARTING", "Verifying Git for Windows functionality...")
    $testGitCloneDir = Join-Path $env:TEMP "git_test_clone_$((Get-Random))" # Create a unique temp dir
    $testLogFile = Join-Path $env:TEMP "git_test_output_$((Get-Random)).log"

    try {
        # Attempt to clone a small, public repository
        Start-Process -FilePath "git" -ArgumentList "clone", "https://github.com/git/hello-world.git", $testGitCloneDir `
            -RedirectStandardOutput $testLogFile -RedirectStandardError $testLogFile -NoNewWindow -Wait
        $testExitCode = $LASTEXITCODE # Get the exit code from Start-Process
        $testOutput = Get-Content $testLogFile | Out-String # Read full output

        if ($testExitCode -ne 0) {
            $Logger.WriteLog("ERROR", "Git functionality check failed (Exit Code: $testExitCode). Full output:", "Red")
            $testOutput.Split("`n") | ForEach-Object { $Logger.WriteLog("ERROR", $_, "DarkRed") }
            return $false
        }
        $Logger.WritePhaseStatus("GIT_CHECK", "SUCCESS", "Git for Windows is functional.")
        return $true
    }
    catch {
        $Logger.WriteLog("ERROR", "Exception during Git functionality check: $($_.Exception.Message)", "Red")
        return $false
    }
    finally {
        # Clean up test files
        if (Test-Path $testGitCloneDir) { Remove-Item -Recurse -Force $testGitCloneDir -ErrorAction SilentlyContinue }
        if (Test-Path $testLogFile) { Remove-Item $testLogFile -ErrorAction SilentlyContinue }
    }
}