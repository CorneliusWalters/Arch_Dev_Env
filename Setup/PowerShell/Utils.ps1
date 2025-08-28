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
		[string]$PersonalRepoUrlDefault
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
	}
}


function Set-NeutralDirectory {
 # Using canonical capitalization
	try {
		$setupDir = $PSScriptRoot
		$repoDir = Split-Path -Parent $setupDir
		$neutralBaseDir = Split-Path -Parent $repoDir 

		# Ensure the path exists before attempting to set location
		if (-not (Test-Path $neutralBaseDir -PathType Container)) {
			throw "Neutral directory path '$neutralBaseDir' does not exist or is not a container."
		}
		# This handles cases where PowerShell might be in a non-filesystem provider path.
		Set-Location -Path $neutralBaseDir -Provider FileSystem -ErrorAction Stop -PassThru | Out-Null
        
		Write-Host "Working directory set to '$neutralBaseDir' to prevent file locks." -ForegroundColor Green
	}
	catch {
		# This prevents the script from proceeding if it cannot successfully change directory,
		# which would inevitably lead to the 'Remove-Item' failing due to a file lock.
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
    
	$elapsed = 0
	while ($elapsed -lt $TimeoutSeconds) {
		try {
			$status = wsl -l -v | Where-Object { $_ -match $DistroName }
			if (-not ($status -match "Running")) {
				$Logger.WritePhaseStatus("WSL_SHUTDOWN", "SUCCESS", "WSL instance stopped")
				return $true
			}
		}
		catch {
			$Logger.WritePhaseStatus("WSL_SHUTDOWN", "SUCCESS", "WSL command failed (assuming stopped)")
			return $true
		}
        
		Start-Sleep -Seconds 2
		$elapsed += 2
		Write-Host "." -NoNewline
	}
    
	$Logger.WritePhaseStatus("WSL_SHUTDOWN", "TIMEOUT", "Timed out waiting for shutdown")
	return $false
}

function Set-WslConfDefaults {
	param (
		[PSCustomObject]$Logger,
		[string]$DistroName,
		[string]$Username,
		[string]$WslRepoPath # Need this for context, although not used in wsl.conf directly
	)

	$Logger.WritePhaseStatus("WSL_CONF", "STARTING", "Creating initial /etc/wsl.conf with user and systemd defaults...")

	# The content for /etc/wsl.conf
	$wslConfContent = @"
[user]
default=$Username

[boot]
systemd=true

[interop]
enabled=true
appendWindowsPath=true
"@

	# Construct the command to write wsl.conf as root inside WSL
	# Use printf for safety against special characters in $Username, though not strictly needed here
	$writeWslConfCommand = "printf '%s' '$wslConfContent' | sudo tee /etc/wsl.conf > /dev/null"

	# Execute this command as root using Invoke-WSLCommand
	if (-not (Invoke-WSLCommand -DistroName $DistroName -Username "root" -Command $writeWslConfCommand -Description "Write initial /etc/wsl.conf" -Logger $Logger)) {
		throw "Failed to write initial /etc/wsl.conf."
	}
	$Logger.WritePhaseStatus("WSL_CONF", "SUCCESS", "Initial /etc/wsl.conf created with user '$Username' and systemd enabled.")
	return $true
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