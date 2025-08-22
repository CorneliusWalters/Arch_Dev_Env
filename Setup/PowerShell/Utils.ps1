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
function set-neutral-dir {    
	try {
		$setupDir = $PSScriptRoot
		$repoDir = Split-Path -Parent $setupDir
		$neutralDir = Split-Path -Parent $repoDir

		Set-Location -Path $neutralDir
		Write-Host "Working directory set to '$($neutralDir)' to prevent file locks." -ForegroundColor Green
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