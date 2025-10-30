# Setup/PowerShell/WSL-Utils.ps1


function Invoke-WSLCommand {
	param(
		[string]$DistroName,
		[string]$Username,
		[string]$Command,
		[string]$Description,
		[PSCustomObject]$Logger
	)
    
	$Logger.WritePhaseStatus("WSL_EXEC", "STARTING", $Description)
    
	try {
		# Use cmd /c to get proper exit codes
		$result = cmd /c "wsl -d $DistroName -u $Username -e bash -c `"$Command`" 2>&1 && echo WSL_SUCCESS || echo WSL_FAILED"
        
		# Convert to string and check for success marker
		$resultString = $result -join "`n"
        
		if ($resultString -match "WSL_SUCCESS") {
			$Logger.WritePhaseStatus("WSL_EXEC", "SUCCESS", $Description)
			return $true
		}
		else {
			$Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Output: $($result -join '; ')")
			return $false
		}
	}
	catch {
		$Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exception: $($_.Exception.Message)")
		return $false
	}
}

function Get-InstallationUserConfig {
	param(
		[string]$WslUsernameDefault,
		[string]$GitUserNameDefault,
		[string]$GitUserEmailDefault,
		[string]$PersonalRepoUrlDefault,
		[string]$HttpProxyDefault,
		[string]$HttpsProxyDefault
	)

	Write-Host "`n--- Collecting User Configuration ---" -ForegroundColor Yellow

	# Collect WSL Username
	$wslUsernameInput = Read-Host -Prompt "Please enter your desired username for Arch Linux (default: '$WslUsernameDefault')"
	$finalWslUsername = if ([string]::IsNullOrWhiteSpace($wslUsernameInput)) { $WslUsernameDefault } else { $wslUsernameInput }
	Write-Host "Using WSL Username: $finalWslUsername" -ForegroundColor DarkGreen

	# Collect Git Username
	$gitUserNameInput = Read-Host -Prompt "Enter your GitHub username (for commits and repo detection, default: '$GitUserNameDefault')"
	$finalGitUserName = if ([string]::IsNullOrWhiteSpace($gitUserNameInput)) { $GitUserNameDefault } else { $gitUserNameInput }
	Write-Host "Using Git Username: $finalGitUserName" -ForegroundColor DarkGreen

	# Collect Git Email
	$gitUserEmailInput = Read-Host -Prompt "Enter your Git email (for commits, default: '$GitUserEmailDefault')"
	$finalGitUserEmail = if ([string]::IsNullOrWhiteSpace($gitUserEmailInput)) { $GitUserEmailDefault } else { $gitUserEmailInput }
	Write-Host "Using Git Email: $finalGitUserEmail" -ForegroundColor DarkGreen

	$finalPersonalRepoUrl = $null # Initialize to null, we'll try to detect or ask
	
	Write-Host "`n--- GitHub SSH Setup ---" -ForegroundColor Yellow
	$sshKeySetupInput = Read-Host -Prompt "Have you generated an SSH key and added it to your GitHub account? (Y/N)"
	$finalSshKeyReady = if ($sshKeySetupInput -eq 'Y') { $true } else { $false }
    
	$sshKeyPath = $null
	if ($finalSshKeyReady) {
		Write-Host "`nLet's set up your SSH key for WSL." -ForegroundColor Cyan
		Write-Host "Common locations:" -ForegroundColor Gray
		Write-Host "  1. C:\Users\$env:USERNAME\.ssh" -ForegroundColor Gray
		Write-Host "  2. C:\Users\$env:USERNAME\Documents\.ssh" -ForegroundColor Gray
		Write-Host "  3. Custom location" -ForegroundColor Gray
        
		$sshChoice = Read-Host -Prompt "Choose location (1/2/3) or press Enter to skip"
        
		switch ($sshChoice) {
			"1" { $testPath = "C:\Users\$env:USERNAME\.ssh" }
			"2" { $testPath = "C:\Users\$env:USERNAME\Documents\.ssh" }
			"3" { 
				$testPath = Read-Host -Prompt "Enter the full path to your .ssh directory"
				$testPath = [System.Environment]::ExpandEnvironmentVariables($testPath)
			}
			default { $testPath = $null }
		}
        
		if ($testPath -and (Test-Path $testPath)) {
			# Check for common SSH key files
			$foundKeys = @()
			foreach ($keyFile in @("id_rsa", "id_ed25519", "id_ecdsa")) {
				if (Test-Path "$testPath\$keyFile") {
					$foundKeys += $keyFile
				}
			}
            
			if ($foundKeys.Count -gt 0) {
				Write-Host "Found SSH keys: $($foundKeys -join ', ')" -ForegroundColor Green
				$sshKeyPath = $testPath
			}
			else {
				Write-Host "No SSH keys found in $testPath" -ForegroundColor Yellow
			}
		}
		elseif ($testPath) {
			Write-Host "Path not found: $testPath" -ForegroundColor Red
		}
	}

	Write-Host "`n--- GitHub SSH Setup ---" -ForegroundColor Yellow
	$finalSshKeyReady = if ($sshKeySetupInput -eq 'Y') { $true } else { $false }
	if (-not $finalSshKeyReady) {
		Write-Host "WARNING: SSH key is highly recommended for Git operations. Please follow GitHub's guide to create an SSH key and add it to your account:" -ForegroundColor Yellow
		Write-Host "         https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent" -ForegroundColor Yellow
		Write-Host "         https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account" -ForegroundColor Yellow
		Write-Host "         You may encounter issues if your network interferes with HTTPS." -ForegroundColor Yellow
	}
	# Try to auto-detect the forked repository using GitHub CLI
	Write-Host "`nAttempting to auto-detect your forked repository on GitHub..." -ForegroundColor Cyan
	if (Get-Command gh -ErrorAction SilentlyContinue) {
		$ghStatus = gh auth status --hostname github.com 2>&1
		if ($ghStatus -match 'Logged in as') {
			Write-Host "GitHub CLI detected and authenticated." -ForegroundColor DarkGreen
			$originalRepoOwner = (Split-Path -Parent $PersonalRepoUrlDefault).Replace("https://github.com/", "")
			$originalRepoName = (Split-Path $PersonalRepoUrlDefault -Leaf).Replace(".git", "")

			try {
				$userForksJson = gh repo list $finalGitUserName --source --fork --json name, url, parent 2>$null | ConvertFrom-Json
				$foundFork = $userForksJson | Where-Object { $_.parent.nameWithOwner -eq "$originalRepoOwner/$originalRepoName" }

				if ($foundFork) {
					$finalPersonalRepoUrl = $foundFork.url
					Write-Host "Auto-detected forked repository: $($finalPersonalRepoUrl)" -ForegroundColor Green
				}
				else {
					Write-Host "No fork of '$originalRepoOwner/$originalRepoName' found under '$finalGitUserName'." -ForegroundColor Yellow
				}
			}
			catch {
				Write-Host "WARNING: Failed to query GitHub for forks. Error: $($_.Exception.Message)" -ForegroundColor Yellow
			}
		}
		else {
			Write-Host "GitHub CLI detected but not authenticated. Run 'gh auth login' first." -ForegroundColor Yellow
		}
	}
 else {
		Write-Host "GitHub CLI ('gh' command) not found. Cannot auto-detect forks." -ForegroundColor Yellow
	}

	# If auto-detection failed, prompt the user manually
	if ([string]::IsNullOrWhiteSpace($finalPersonalRepoUrl)) {
		$personalRepoUrlInput = Read-Host -Prompt "Enter your personal dotfiles GitHub repo URL (optional - default: '$PersonalRepoUrlDefault' or generated based on your GitHub username')"
		if ([string]::IsNullOrWhiteSpace($personalRepoUrlInput)) {
			# Fallback to default generated URL if manual input is also empty
			if ([string]::IsNullOrWhiteSpace($finalGitUserName)) {
				Write-Host "WARNING: Git username is empty. Cannot generate default personal repo URL, using hardcoded default." -ForegroundColor Yellow
				$finalPersonalRepoUrl = $PersonalRepoUrlDefault # Final fallback to hardcoded default
			}
			else {
				# Generated from user's GH name, ensuring $originalRepoName is available.
				$originalRepoName = (Split-Path $PersonalRepoUrlDefault -Leaf).Replace(".git", "")
				$finalPersonalRepoUrl = "https://github.com/$finalGitUserName/$originalRepoName.git"
			}
		}
		else {
			$finalPersonalRepoUrl = $personalRepoUrlInput
		}
	}
	Write-Host "`nUsing personal dotfiles repository: $($finalPersonalRepoUrl)" -ForegroundColor Green # Confirm final URL

	# Return all collected values as a custom object
	return [PSCustomObject]@{
		WslUsername     = $finalWslUsername
		GitUserName     = $finalGitUserName
		GitUserEmail    = $finalGitUserEmail
		PersonalRepoUrl = $finalPersonalRepoUrl
		SshKeyReady     = $finalSshKeyReady
	}
}

function Test-IsGitSafeDirectory {
	param(
		[string]$PathToCheck # The path, e.g., "C:/wsl/git" or "C:/wsl/wsl_dev_setup"
	)

	# Git expects forward slashes for safe.directory entries
	$gitFormattedPath = $PathToCheck.Replace('\', '/')

	try {
		# Get all global safe.directory entries
		$safeDirs = Start-Process -FilePath "git" -ArgumentList "config", "--global", "--get-all", "safe.directory" `
			-NoNewWindow -Wait -PassThru -ErrorAction Stop | Select-Object -ExpandProperty StandardOutput | Out-String | ConvertFrom-Csv -Header Value

		if ($safeDirs -is [System.Array]) {
			# Handle multiple entries
			foreach ($entry in $safeDirs) {
				# Check for exact match or wildcard match (e.g., C:/foo vs C:/foo/*)
				if ($entry.Value -eq $gitFormattedPath -or $entry.Value -eq "$gitFormattedPath/*") {
					return $true
				}
			}
		}
		elseif ($safeDirs -is [PSCustomObject]) {
			# Handle single entry
			if ($safeDirs.Value -eq $gitFormattedPath -or $safeDirs.Value -eq "$gitFormattedPath/*") {
				return $true
			}
		}
		return $false
	}
	catch {
		# Git config will error if safe.directory is not set at all, which means it's not safe.
		# So we catch and return false, or log a more specific error if needed.
		Write-Host "WARNING: Could not check Git safe.directory status for '$PathToCheck'. Error: $($_.Exception.Message)" -ForegroundColor Yellow
		return $false
	}
}


function Set-NeutralDirectory {
	try {
		$setupDir = $PSScriptRoot
		$repoDir = Split-Path -Parent $setupDir
		$neutralBaseDir = Split-Path -Parent $repoDir 

		# Ensure the path exists before attempting to set location
		if (-not (Test-Path $neutralBaseDir -PathType Container)) {
			throw "Neutral directory path '$neutralBaseDir' does not exist or is not a container."
		}

		Set-Location -Path $neutralBaseDir -ErrorAction Stop -PassThru | Out-Null
        
		Write-Host "Working directory set to '$neutralBaseDir' to prevent file locks." -ForegroundColor Green
	}
	catch {
		Write-Host "ERROR: Critical failure to set neutral directory. $($_.Exception.Message)" -ForegroundColor Red
		throw "Failed to set neutral directory: $($_.Exception.Message). Please ensure C:\wsl exists and is writable, and that no other process is locking it."
	}
}

function Wait-WSLShutdown {
	param(
		[string]$DistroName, 
		[int]$TimeoutSeconds = 60,
		[PSCustomObject]$Logger
	)
    
	$Logger.WritePhaseStatus("WSL_SHUTDOWN", "STARTING", "Waiting for $DistroName to shut down")
    
	$startTime = Get-Date
	do {
		Start-Sleep -Seconds 2
		try {
			$null = wsl -d $DistroName -e echo "test" 2>$null
			$isRunning = $LASTEXITCODE -eq 0
		}
		catch {
			$isRunning = $false
		}
	} while ($isRunning -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds)
    

    
	$Logger.WritePhaseStatus("WSL_SHUTDOWN", "TIMEOUT", "Timed out waiting for shutdown")
	return -not $isRunning
}

function Set-WslConfDefaults {
	param (
		[PSCustomObject]$Logger,
		[string]$DistroName,
		[string]$Username,
		[string]$WslRepoPath
	)

	$Logger.WritePhaseStatus("WSL_CONF", "STARTING", "Creating initial /etc/wsl.conf with user and systemd defaults...")

	try {
		# Create wsl.conf content with proper variable substitution
		$wslConfContent = @"
[user]
default=$Username

[boot]
systemd=true

[interop]
enabled=true
appendWindowsPath=true
"@

		# Write to a temporary file first
		$tempFile = [System.IO.Path]::GetTempFileName()
		$wslConfContent | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline

		# Get the WSL path for the temp file
		$tempFileWSLPath = "/mnt/c" + ($tempFile.Replace('\', '/').Substring(2))

		$Logger.WriteLog("INFO", "Creating /etc/wsl.conf with default user: $Username", "Cyan")

		# Copy the temp file to /etc/wsl.conf in one command
		$copyResult = wsl -d $DistroName -u root -- bash -c "cp '$tempFileWSLPath' /etc/wsl.conf && echo 'SUCCESS' || echo 'FAILED'"

		if ($copyResult -contains "SUCCESS") {
			$Logger.WritePhaseStatus("WSL_CONF", "SUCCESS", "Initial /etc/wsl.conf created with user '$Username' and systemd enabled.")
			
			# Verify the content was written correctly
			$verifyResult = wsl -d $DistroName -u root -- bash -c "cat /etc/wsl.conf"
			$Logger.WriteLog("INFO", "Verification - /etc/wsl.conf contents:", "Gray")
			$verifyResult | ForEach-Object { $Logger.WriteLog("INFO", $_, "Gray") }
			
			return $true
		}
		else {
			throw "Failed to copy wsl.conf to /etc/wsl.conf"
		}
	}
	catch {
		$Logger.WritePhaseStatus("WSL_CONF", "ERROR", "Exception: $($_.Exception.Message)")
		throw "Failed to write initial /etc/wsl.conf."
	}
	finally {
		# Clean up temp file
		if (Test-Path $tempFile) {
			Remove-Item $tempFile -Force
		}
	}
}

#function Test-WSLDistroExists {
#    param([string]$DistroName)
#    
#    try {
#        $distros = wsl -l -v
#        return ($null -ne ($distros | Where-Object { $_ -match $DistroName })) 
#    } catch {
#        return $false
#    }
#}

# --- NEW: Function to configure all Git for Windows global settings ---
# This includes safe.directory, user info, protocol, and proxy.
function Set-GitGlobalConfig {
	param(
		[PSCustomObject]$Logger,
		[string]$GitUserName,
		[string]$GitUserEmail,
		[bool]$SshKeyReady,
		[string]$HttpProxy,
		[string]$HttpsProxy,
		[string]$PSScriptRootContext # Pass $PSScriptRoot so utility can derive mainRepoWindowsPath
	)

	$logger.WritePhaseStatus("GIT_SECURITY", "STARTING", "Configuring Git 'safe.directory' exceptions...")
	$gitTestBasePath = "C:/wsl/git" # Git prefers forward slashes

	# Ensure C:\wsl\git (for test clones) is safe
	if (-not (Test-IsGitSafeDirectory -PathToCheck $gitTestBasePath)) {
		$Logger.WriteLog("INFO", "Adding '$gitTestBasePath' to Git's safe.directory list (for test clones).", "DarkGreen")
		Start-Process -FilePath "git" -ArgumentList "config", "--global", "--add", "safe.directory", $gitTestBasePath `
			-NoNewWindow -Wait -ErrorAction Stop | Out-Null
	}
 else {
		$Logger.WriteLog("INFO", "'$gitTestBasePath' already in Git's safe.directory list.", "DarkGreen")
	}

	# Ensure the main setup repository path (C:\wsl\wsl_dev_setup) is safe
	$mainRepoWindowsPath = (Convert-Path $PSScriptRootContext | Get-Item).Parent.FullName
	$mainRepoGitFormattedPath = $mainRepoWindowsPath.Replace('\', '/')
	if (-not (Test-IsGitSafeDirectory -PathToCheck $mainRepoGitFormattedPath)) {
		$Logger.WriteLog("INFO", "Adding '$mainRepoGitFormattedPath' to Git's safe.directory list (for setup repo).", "DarkGreen")
		Start-Process -FilePath "git" -ArgumentList "config", "--global", "--add", "safe.directory", $mainRepoGitFormattedPath `
			-NoNewWindow -Wait -ErrorAction Stop | Out-Null
	}
 else {
		$Logger.WriteLog("INFO", "'$mainRepoGitFormattedPath' already in Git's safe.directory list.", "DarkGreen")
	}

	# Also add the wildcard version for subdirectories within C:/wsl/git, but only if needed
	if (-not (Test-IsGitSafeDirectory -PathToCheck "$gitTestBasePath/*")) {
		$Logger.WriteLog("INFO", "Adding '$gitTestBasePath/*' to Git's safe.directory list (for subdirectories).", "DarkGreen")
		Start-Process -FilePath "git" -ArgumentList "config", "--global", "--add", "safe.directory", "$gitTestBasePath/*" `
			-NoNewWindow -Wait -ErrorAction Stop | Out-Null
	}
 else {
		$Logger.WriteLog("INFO", "'$gitTestBasePath/*' already in Git's safe.directory list.", "DarkGreen")
	}
	$logger.WritePhaseStatus("GIT_SECURITY", "SUCCESS", "Git 'safe.directory' configuration completed.")

	# Set global Git user.name and user.email.
	$logger.WritePhaseStatus("GIT_GLOBAL_CONFIG", "STARTING", "Setting Git for Windows global user.name and user.email...")
	Start-Process -FilePath "git" -ArgumentList "config", "--global", "user.name", "'$GitUserName'" `
		-NoNewWindow -Wait -ErrorAction Stop | Out-Null
	Start-Process -FilePath "git" -ArgumentList "config", "--global", "user.email", "'$GitUserEmail'" `
		-NoNewWindow -Wait -ErrorAction Stop | Out-Null
	$logger.WritePhaseStatus("GIT_GLOBAL_CONFIG", "SUCCESS", "Git global user.name and user.email set to '$GitUserName' <$GitUserEmail>.")

	# Configure Git's SSH/HTTPS protocol.
	if ($SshKeyReady) {
		$logger.WritePhaseStatus("GIT_PROTOCOL", "STARTING", "Configuring Git to use SSH for GitHub automatically...")
		Start-Process -FilePath "git" -ArgumentList "config", "--global", "url.git@github.com:.insteadOf", "https://github.com/" `
			-NoNewWindow -Wait -ErrorAction Stop | Out-Null
		$logger.WritePhaseStatus("GIT_PROTOCOL", "SUCCESS", "Git configured to use SSH for GitHub.com.")
	}
 else {
		$Logger.WriteLog("WARNING", "SSH key not confirmed. Git will continue to use HTTPS, which may fail in restrictive networks.", "Yellow")
	}
	$logger.WritePhaseStatus("GIT_PROTOCOL", "SUCCESS", "Git protocol configured.")

	# Configure Git's HTTP/S proxy.
	$logger.WritePhaseStatus("GIT_PROXY", "STARTING", "Configuring Git for Windows proxy settings...")
	if (-not [string]::IsNullOrWhiteSpace($HttpProxy)) {
		Start-Process -FilePath "git" -ArgumentList "config", "--global", "http.proxy", "'$HttpProxy'" `
			-NoNewWindow -Wait -ErrorAction Stop | Out-Null
		$Logger.WriteLog("INFO", "Git http.proxy set to '$HttpProxy'.", "DarkGreen")
	}
 else {
		Start-Process -FilePath "git" -ArgumentList "config", "--global", "--unset", "http.proxy" `
			-NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
		$Logger.WriteLog("INFO", "Git http.proxy not set.", "DarkGray")
	}
	if (-not [string]::IsNullOrWhiteSpace($HttpsProxy)) {
		Start-Process -FilePath "git" -ArgumentList "config", "--global", "https.proxy", "'$HttpsProxy'" `
			-NoNewWindow -Wait -ErrorAction Stop | Out-Null
		$Logger.WriteLog("INFO", "Git https.proxy set to '$HttpsProxy'.", "DarkGreen")
	}
 else {
		Start-Process -FilePath "git" -ArgumentList "config", "--global", "--unset", "https.proxy" `
			-NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
		$Logger.WriteLog("INFO", "Git https.proxy not set.", "DarkGray")
	}
	$logger.WritePhaseStatus("GIT_PROXY", "SUCCESS", "Git proxy configuration completed.")
	return $true
}

# --- NEW: Function to clone the main setup repository (Arch_Dev_Env) ---
function Clone-SetupRepository {
	param(
		[PSCustomObject]$Logger,
		[string]$GitCloneTarget, # The Windows path where the repo will be cloned
		[string]$SourceRepoUrl, # The URL of the upstream repo
		[bool]$ForceOverwrite # Whether to forcibly delete existing target
	)

	$Logger.WritePhaseStatus("CLONE_SETUP_REPO", "STARTING", "Cloning setup repository into Windows path '$GitCloneTarget' from '$SourceRepoUrl'...")
    
	if ($ForceOverwrite -or -not (Test-Path $GitCloneTarget)) {
		if (Test-Path $GitCloneTarget) { 
			Remove-Item -Recurse -Force $GitCloneTarget 
		}

		$cloneOutput = ""
		$cloneExitCode = 0
		# --- FIX: Use separate temporary files for StandardOutput and StandardError ---
		$tempStdoutFile = Join-Path $env:TEMP "git_clone_stdout_$((Get-Random)).log"
		$tempStderrFile = Join-Path $env:TEMP "git_clone_stderr_$((Get-Random)).log"

		try {
			Start-Process -FilePath "git" -ArgumentList "clone", $SourceRepoUrl, $GitCloneTarget `
				-RedirectStandardOutput $tempStdoutFile -RedirectStandardError $tempStderrFile -NoNewWindow -Wait `
				-ErrorAction Stop
			$cloneExitCode = $LASTEXITCODE
            
			# Combine output from both files
			if (Test-Path $tempStdoutFile) { $cloneOutput += (Get-Content $tempStdoutFile | Out-String) }
			if (Test-Path $tempStderrFile) { $cloneOutput += (Get-Content $tempStderrFile | Out-String) }
		}
		catch {
			# Catch exceptions during Start-Process itself
			$Logger.WriteLog("ERROR", "Exception during setup repository clone: $($_.Exception.Message)", "Red")
			# Include any captured output in the error if available
			if (Test-Path $tempStdoutFile) { $Logger.WriteLog("ERROR", (Get-Content $tempStdoutFile | Out-String), "DarkRed") }
			if (Test-Path $tempStderrFile) { $Logger.WriteLog("ERROR", (Get-Content $tempStderrFile | Out-String), "DarkRed") }
			throw # Re-throw to propagate the original error
		}
		finally {
			# Clean up all temporary files
			if (Test-Path $tempStdoutFile) { Remove-Item $tempStdoutFile -ErrorAction SilentlyContinue }
			if (Test-Path $tempStderrFile) { Remove-Item $tempStderrFile -ErrorAction SilentlyContinue }
		}

		if ($cloneExitCode -ne 0) {
			$Logger.WriteLog("ERROR", "Git clone of setup repository failed (Exit Code: $cloneExitCode). Full output:", "Red")
			$cloneOutput.Split("`n") | ForEach-Object { $Logger.WriteLog("ERROR", $_, "DarkRed") }
			$Logger.WriteLog("RECOVERY", "--- MANUAL GIT CLONE TROUBLESHOOTING ---", "Yellow")
			$Logger.WriteLog("RECOVERY", "Attempted to clone: $SourceRepoUrl", "Yellow")
			$Logger.WriteLog("RECOVERY", "Target directory: $GitCloneTarget", "Yellow")
			$Logger.WriteLog("RECOVERY", "Possible causes:", "Yellow")
			$Logger.WriteLog("RECOVERY", "1. Network/Proxy interference with HTTPS. Ensure Git proxy settings are correct.", "Yellow")
			$Logger.WriteLog("RECOVERY", "2. Git 'safe.directory' issue (ensure C:/wsl/git and C:/wsl/wsl_dev_setup are added globally).", "Yellow")
			$Logger.WriteLog("RECOVERY", "3. Missing/incorrect SSH key if using SSH protocol.", "Yellow")
			$Logger.WriteLog("RECOVERY", "To manually test, open PowerShell as Administrator and run:", "Yellow")
			$Logger.WriteLog("RECOVERY", "   git clone $SourceRepoUrl C:\\test_clone_manual", "Yellow")
			$Logger.WriteLog("RECOVERY", "--- END MANUAL GIT CLONE TROUBLESHOOTING ---", "Yellow")
			throw "Git clone of setup repository failed with exit code $cloneExitCode. Check logs for full output and manual troubleshooting steps."
		}
	}
 else {
		$Logger.WriteLog("INFO", "Setup repository '$GitCloneTarget' already exists. Skipping clone.", "Green")
	}
	return $true
}

# --- NEW: Function to run basic WSL functionality debug commands ---
function Test-WslBasicFunctionality {
	param(
		[PSCustomObject]$Logger,
		[string]$DistroName,
		[string]$Username,
		[string]$WslRepoPath # Path to the repo inside WSL
	)

	$Logger.WritePhaseStatus("CONF_STATUS", "STARTING", "Running basic WSL functionality and repository access tests...")
	$confCommands = @(
		"whoami",
		"pwd", 
		"echo `$HOME",
		"test -d '$WslRepoPath' && echo 'REPO_DIR_EXISTS' || echo 'REPO_DIR_MISSING'",
		"test -f '$WslRepoPath/Setup/1_sys_init.sh' && echo 'SCRIPT_EXISTS' || echo 'SCRIPT_MISSING'",
		"ls -la '$WslRepoPath/Setup/' | head -5"
	)
	foreach ($cmd in $confCommands) {
		# Use Invoke-WSLCommand for consistent logging and error handling
		if (-not (Invoke-WSLCommand -DistroName $DistroName -Username $Username -Command $cmd -Description "Debug command: $cmd" -Logger $Logger)) {
			$Logger.WriteLog("Conf_Status", "Debug command FAILED: $cmd", "Red")
		}
	}
	$logger.WritePhaseStatus("CONF_STATUS", "SUCCESS", "Basic WSL functionality tests completed.")
	return $true
}
function Find-WindowsSSHKeys {
	param([PSCustomObject]$Logger)
    
	$Logger.WriteLog("INFO", "Searching for SSH keys on Windows...", "Cyan")
    
	# Common SSH key locations
	$searchPaths = @(
		"$env:USERPROFILE\.ssh",
		"$env:USERPROFILE\Documents\.ssh",
		"$env:USERPROFILE\OneDrive\Documents\.ssh",
		"$env:USERPROFILE\Desktop\.ssh"
	)
    
	$foundPaths = @()
    
	foreach ($path in $searchPaths) {
		if (Test-Path $path) {
			$keyFiles = Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue | Where-Object {
				$_.Name -match '^(id_rsa|id_ed25519|id_ecdsa|id_dsa)$'
			}
            
			if ($keyFiles.Count -gt 0) {
				$Logger.WriteLog("SUCCESS", "Found SSH keys in: $path", "Green")
				$Logger.WriteLog("INFO", "Keys found: $($keyFiles.Name -join ', ')", "Gray")
				$foundPaths += $path
			}
		}
	}
    
	return $foundPaths
}

function Copy-SSHKeysToWSL {
	param(
		[PSCustomObject]$Logger,
		[string]$WindowsSshPath,
		[string]$WslDistroName,
		[string]$WslUsername
	)
    
	if ([string]::IsNullOrWhiteSpace($WindowsSshPath) -or -not (Test-Path $WindowsSshPath)) {
		$Logger.WriteLog("ERROR", "SSH path not found: $WindowsSshPath", "Red")
		return $false
	}
    
	$Logger.WritePhaseStatus("SSH_COPY", "STARTING", "Copying SSH keys from $WindowsSshPath to WSL")
    
	try {
		# Create WSL .ssh directory first
		$createSshCmd = @"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
"@
        
		if (-not (Invoke-WSLCommand -DistroName $WslDistroName -Username $WslUsername `
					-Command $createSshCmd -Description "Create .ssh directory" -Logger $Logger)) {
			throw "Failed to create .ssh directory"
		}
        
		# Get files to copy
		$filesToCopy = Get-ChildItem -Path $WindowsSshPath -File | Where-Object {
			$_.Name -match '^(id_|config$|known_hosts$|authorized_keys$)'
		}
        
		if ($filesToCopy.Count -eq 0) {
			$Logger.WriteLog("WARNING", "No SSH files found in $WindowsSshPath", "Yellow")
			return $false
		}
        
		foreach ($file in $filesToCopy) {
			$Logger.WriteLog("INFO", "Processing: $($file.Name)", "Cyan")
            
			# Read content and fix line endings
			$content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
			if ($null -eq $content) { continue }
            
			$content = $content.Replace("`r`n", "`n").TrimEnd() + "`n"
            
			# Pipe directly to WSL to create the file
			$content | wsl -d $WslDistroName -u $WslUsername -- bash -c "cat > ~/.ssh/$($file.Name)"
	
			# Set permissions in a separate command
			$permCmd = "chmod $permissions ~/.ssh/$($file.Name) && chown `$USER:`$USER ~/.ssh/$($file.Name)"
			Invoke-WSLCommand -DistroName $WslDistroName -Username $WslUsername -Command $permCmd -Description "Set permissions for $($file.Name)" -Logger $Logger
			
			if (-not (Invoke-WSLCommand -DistroName $WslDistroName -Username $WslUsername `
						-Command $copyCmd -Description "Copy $($file.Name)" -Logger $Logger)) {
				$Logger.WriteLog("ERROR", "Failed to copy $($file.Name)", "Red")
				Remove-Item $tempFile -Force
				continue
			}
            
			Remove-Item $tempFile -Force
			$Logger.WriteLog("SUCCESS", "Copied $($file.Name) with permissions $permissions", "Green")
		}
        
		# Add GitHub to known hosts to prevent prompt
		$addKnownHostCmd = @"
ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null || true
"@
		Invoke-WSLCommand -DistroName $WslDistroName -Username $WslUsername `
			-Command $addKnownHostCmd -Description "Add GitHub to known hosts" -Logger $Logger | Out-Null
        
		# Test SSH
		$Logger.WriteLog("INFO", "Testing SSH connection to GitHub...", "Cyan")
		$testResult = wsl -d $WslDistroName -u $WslUsername -- bash -c "ssh -T git@github.com 2>&1 || true"
        
		if ($testResult -match "successfully authenticated") {
			$Logger.WritePhaseStatus("SSH_COPY", "SUCCESS", "SSH keys copied and GitHub access verified")
			return $true
		}
		else {
			$Logger.WriteLog("WARNING", "SSH test output: $testResult", "Yellow")
			$Logger.WriteLog("INFO", "SSH keys copied but GitHub authentication not verified", "Yellow")
			return $true # Still return true as keys were copied
		}
	}
	catch {
		$Logger.WritePhaseStatus("SSH_COPY", "ERROR", "Exception: $($_.Exception.Message)")
		return $false
	}
}

# Update your existing Get-InstallationUserConfig function
function Get-InstallationUserConfig {
	param(
		[string]$WslUsernameDefault,
		[string]$GitUserNameDefault,
		[string]$GitUserEmailDefault,
		[string]$PersonalRepoUrlDefault,
		[string]$HttpProxyDefault = "",
		[string]$HttpsProxyDefault = ""
	)

	Write-Host "`n--- Collecting User Configuration ---" -ForegroundColor Yellow

	# ... existing username, git name, email collection code ...

	# SSH Configuration Section
	Write-Host "`n--- SSH Key Configuration ---" -ForegroundColor Yellow
    
	# Auto-detect SSH keys first
	$tempLogger = [PSCustomObject]@{
		WriteLog = { param($level, $msg, $color) Write-Host "[$level] $msg" -ForegroundColor $color }
	}
	$detectedPaths = Find-WindowsSSHKeys -Logger $tempLogger
    
	$sshKeyPath = $null
	$sshKeyReady = $false
    
	if ($detectedPaths.Count -gt 0) {
		Write-Host "`nFound SSH keys in the following locations:" -ForegroundColor Green
		for ($i = 0; $i -lt $detectedPaths.Count; $i++) {
			Write-Host "  $($i + 1). $($detectedPaths[$i])" -ForegroundColor Cyan
		}
		Write-Host "  0. Enter custom path" -ForegroundColor Gray
		Write-Host "  S. Skip SSH setup (use HTTPS)" -ForegroundColor Gray
        
		$choice = Read-Host "Select location (1-$($detectedPaths.Count)/0/S)"
        
		if ($choice -match '^\d+$') {
			$choiceNum = [int]$choice
			if ($choiceNum -gt 0 -and $choiceNum -le $detectedPaths.Count) {
				$sshKeyPath = $detectedPaths[$choiceNum - 1]
				$sshKeyReady = $true
			}
			elseif ($choiceNum -eq 0) {
				$customPath = Read-Host "Enter full path to .ssh directory"
				if (Test-Path $customPath) {
					$sshKeyPath = $customPath
					$sshKeyReady = $true
				}
				else {
					Write-Host "Path not found: $customPath" -ForegroundColor Red
				}
			}
		}
	}
 else {
		Write-Host "No SSH keys found in common locations." -ForegroundColor Yellow
		$manualChoice = Read-Host "Would you like to specify a custom path? (Y/N)"
        
		if ($manualChoice -eq 'Y') {
			$customPath = Read-Host "Enter full path to .ssh directory"
			if (Test-Path $customPath) {
				$sshKeyPath = $customPath
				$sshKeyReady = $true
			}
		}
	}
    
	# Proxy configuration
	Write-Host "`n--- Network Configuration ---" -ForegroundColor Yellow
	$httpProxyInput = Read-Host "HTTP Proxy (blank for none, default: '$httpProxyDefault')"
	$finalHttpProxy = if ([string]::IsNullOrWhiteSpace($httpProxyInput)) { $httpProxyDefault } else { $httpProxyInput }
    
	$httpsProxyInput = Read-Host "HTTPS Proxy (blank for none, default: '$httpsProxyDefault')"
	$finalHttpsProxy = if ([string]::IsNullOrWhiteSpace($httpsProxyInput)) { $httpsProxyDefault } else { $httpsProxyInput }
    
	# ... rest of your existing personal repo detection code ...
    
	return [PSCustomObject]@{
		WslUsername     = $finalWslUsername
		GitUserName     = $finalGitUserName
		GitUserEmail    = $finalGitUserEmail
		PersonalRepoUrl = $finalPersonalRepoUrl
		SshKeyReady     = $sshKeyReady
		SshKeyPath      = $sshKeyPath
		HttpProxy       = $finalHttpProxy
		HttpsProxy      = $finalHttpsProxy
	}
}