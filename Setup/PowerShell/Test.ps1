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
    
	# --- FIX: Explicitly create and manage the base Git test directory ---
	# We will use 'C:\wsl\git' as the base, ensuring it exists and is logged.
	$gitTestBaseDirPath = "C:\wsl\git"
    
	try {
		if (-not (Test-Path $gitTestBaseDirPath -PathType Container)) {
			New-Item -Path $gitTestBaseDirPath -ItemType Directory -Force | Out-Null
			$Logger.WriteLog("INFO", "Created Git test base directory: '$gitTestBaseDirPath'", "DarkGray")
		}
		else {
			$Logger.WriteLog("INFO", "Git test base directory already exists: '$gitTestBaseDirPath'", "DarkGray")
		}

		# Log permissions of the base directory (useful for debugging if it's a permission issue)
		$Logger.WriteLog("INFO", "Permissions for '$gitTestBaseDirPath':", "DarkGray")
		(Get-Acl $gitTestBaseDirPath | Format-List -Property AccessToString, Owner, Group) | ForEach-Object {
			$Logger.WriteLog("INFO", $_, "DarkGray")
		}

		# Derive unique temporary paths within the managed base directory
		$testGitCloneDir = Join-Path $gitTestBaseDirPath "git_test_clone_$((Get-Random))"
		$testStdoutFile = Join-Path $gitTestBaseDirPath "git_test_stdout_$((Get-Random)).log"
		$testStderrFile = Join-Path $gitTestBaseDirPath "git_test_stderr_$((Get-Random)).log"

		$Logger.WriteLog("INFO", "Attempting Git clone into: '$testGitCloneDir'", "DarkGray")
		$Logger.WriteLog("INFO", "Git version: $((git --version 2>&1 | Out-String).Trim())", "DarkGray")
		$Logger.WriteLog("INFO", "Git global config (user.name): $((git config --global user.name 2>&1 | Out-String).Trim())", "DarkGray")
		$Logger.WriteLog("INFO", "Git global config (user.email): $((git config --global user.email 2>&1 | Out-String).Trim())", "DarkGray")
        
		# --- FIX: Ensure -v for verbose output is included in git clone ---
		Start-Process -FilePath "git" -ArgumentList "clone", "-v", "http://github.com/octocat/Spoon-Knife.git", $testGitCloneDir `
			-RedirectStandardOutput $testStdoutFile -RedirectStandardError $testStderrFile -NoNewWindow -Wait `
			-ErrorAction Stop
		$testExitCode = $LASTEXITCODE
        
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
		$Logger.WriteLog("ERROR", "Exception during Git functionality check: $($_.Exception.Message)", "Red")
		# Include any captured output in the error if available
		if (Test-Path $testStdoutFile) { $Logger.WriteLog("ERROR", (Get-Content $testStdoutFile | Out-String), "DarkRed") }
		if (Test-Path $testStderrFile) { $Logger.WriteLog("ERROR", (Get-Content $testStderrFile | Out-String), "DarkRed") }
		return $false
	}
	finally {
		# --- FIX: Robust cleanup of the test Git clone directory and temporary log files ---
		if (Test-Path $testGitCloneDir) {
			$Logger.WriteLog("INFO", "Cleaning up test Git clone directory: '$testGitCloneDir'", "DarkGray")
			Remove-Item -Recurse -Force $testGitCloneDir -ErrorAction SilentlyContinue
		}
		if (Test-Path $testStdoutFile) { Remove-Item $testStdoutFile -ErrorAction SilentlyContinue }
		if (Test-Path $testStderrFile) { Remove-Item $testStderrFile -ErrorAction SilentlyContinue }
		# Note: We do NOT remove $gitTestBaseDirPath (C:\wsl\git) here, as it's the intended base for future tests.
	}
}