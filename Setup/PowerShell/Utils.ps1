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
function Set-NeutralDirectory {
	try {
		$scriptFile = $MyInvocation.MyCommand.Path
		$setupDir = Split-Path -Parent $scriptFile
		$repoDir = Split-Path -Parent $setupDir
		$neutralBaseDir = Split-Path -Parent $repoDir

		Set-Location -Path $neutralBaseDir
		Write-Host "Working directory set to '$neutralBaseDir' to prevent file locks." -ForegroundColor Green
	}
	catch {
		Write-Host "WARNING: Could not automatically change directory. Please ensure you are running this script from a directory OUTSIDE of 'wsl_dev_setup'." -ForegroundColor Yellow
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