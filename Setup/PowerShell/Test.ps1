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
	$testGitCloneDir = Join-Path $env:TEMP "git_test_clone_$((Get-Random))"
	$testStdoutFile = Join-Path $env:TEMP "git_test_stdout_$((Get-Random)).log"
	$testStderrFile = Join-Path $env:TEMP "git_test_stderr_$((Get-Random)).log"

	try {
		Start-Process -FilePath "git" -ArgumentList "clone", "https://github.com/git/hello-world.git", $testGitCloneDir `
			-RedirectStandardOutput $testStdoutFile -RedirectStandardError $testStderrFile -NoNewWindow -Wait `
			-ErrorAction Stop # Ensure any Start-Process errors are caught
		$testExitCode = $LASTEXITCODE
        
		# Combine content from both temporary files for the full output
		$testOutput = ""
		if (Test-Path $testStdoutFile) { $testOutput += (Get-Content $testStdoutFile | Out-String) }
		if (Test-Path $testStderrFile) { $testOutput += (Get-Content $testStderrFile | Out-String) }

		if ($testExitCode -ne 0) {
			$Logger.WriteLog("ERROR", "Git functionality check failed (Exit Code: $testExitCode). Full output:", "Red")
			$testOutput.Split("`n") | ForEach-Object { $Logger.WriteLog("ERROR", $_, "DarkRed") }
			return $false
		}
		$Logger.WritePhaseStatus("GIT_CHECK", "SUCCESS", "Git for Windows is functional.")
		return $true
	}
	catch {
		# Catch any exceptions during Start-Process itself (e.g., git.exe not found)
		$Logger.WriteLog("ERROR", "Exception during Git functionality check: $($_.Exception.Message)", "Red")
		# Include any captured output in the error if available
		if (Test-Path $testStdoutFile) { $Logger.WriteLog("ERROR", (Get-Content $testStdoutFile | Out-String), "DarkRed") }
		if (Test-Path $testStderrFile) { $Logger.WriteLog("ERROR", (Get-Content $testStderrFile | Out-String), "DarkRed") }
		return $false
	}
	finally {
		# Clean up all test files
		if (Test-Path $testGitCloneDir) { Remove-Item -Recurse -Force $testGitCloneDir -ErrorAction SilentlyContinue }
		if (Test-Path $testStdoutFile) { Remove-Item $testStdoutFile -ErrorAction SilentlyContinue }
		if (Test-Path $testStderrFile) { Remove-Item $testStderrFile -ErrorAction SilentlyContinue }
	}
}