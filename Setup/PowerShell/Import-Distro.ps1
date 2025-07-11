# Import-ArchDistro.ps1
function Import-ArchDistro {
    param (
        [PSCustomObject]$Logger,
        [string]$WslDistroName,
        [string]$WslUsername,
        [string]$DefaultTarballPath
    )
    
    & $Logger.WriteHeader "Checking / Importing WSL Distribution '$WslDistroName'"
    $wslDistroExists = (wsl -l -v | Select-String $WslDistroName -Quiet)
    
    if (-not $wslDistroExists) {
        & $Logger.WriteLog "WARNING" "WSL distribution '$WslDistroName' not found." "Yellow"
        & $Logger.WriteLog "WARNING" "You need a clean Arch Linux .tar file to import it." "Yellow"
        
        $tarPath = Read-Host "Enter the full path to your arch_clean.tar (or press Enter for default '$DefaultTarballPath')"
        & $Logger.WriteLog "INFO" "User provided tarball path: $tarPath" "Gray"
        
        if ([string]::IsNullOrWhiteSpace($tarPath)) {
            $tarPath = $DefaultTarballPath
            & $Logger.WriteLog "INFO" "Using default tarball path: $tarPath" "Gray"
        }

        if (-not (Test-Path $tarPath)) {
            & $Logger.WriteLog "ERROR" "Clean Arch tarball not found at '$tarPath'." "Red"
            & $Logger.WriteLog "ERROR" "Please obtain a clean Arch Linux .tar file and place it there, then re-run this script." "Red"
            return $false
        }

        $archInstallDir = "C:\WSL\$WslDistroName"
        & $Logger.WriteLog "INFO" "Importing '$WslDistroName' from '$tarPath' to '$archInstallDir'..." "Cyan"
        if (-not (Test-Path $archInstallDir)) {
            New-Item -ItemType Directory -Path $archInstallDir -Force | Out-Null
            & $Logger.WriteLog "INFO" "Created directory: $archInstallDir" "Gray"
        }
        
        & $Logger.WriteLog "INFO" "Running wsl --import $WslDistroName $archInstallDir $tarPath" "Gray"
        wsl --import $WslDistroName $archInstallDir $tarPath
        if ($LASTEXITCODE -ne 0) {
            & $Logger.WriteLog "ERROR" "Failed to import WSL distribution '$WslDistroName'." "Red"
            return $false
        }
        & $Logger.WriteLog "SUCCESS" "WSL distribution '$WslDistroName' imported successfully." "Green"

        # Set the default user for the newly imported distro
        & $Logger.WriteLog "INFO" "Setting default user to '$WslUsername' for '$WslDistroName'..." "Cyan"
        wsl -d $WslDistroName -u root bash -c "echo '[user]' | tee /etc/wsl.conf > /dev/null && echo 'default=$WslUsername' | tee -a /etc/wsl.conf > /dev/null"
        if ($LASTEXITCODE -ne 0) {
            & $Logger.WriteLog "WARNING" "Failed to set default user for '$WslDistroName' in /etc/wsl.conf." "Yellow"
            return $false
        } else {
            & $Logger.WriteLog "SUCCESS" "Default user '$WslUsername' set for '$WslDistroName'." "Green"
        }
    } else {
        & $Logger.WriteLog "SUCCESS" "WSL distribution '$WslDistroName' found. Proceeding with configuration." "Green"
        & $Logger.WriteLog "INFO" "Ensuring default user is '$WslUsername' for '$WslDistroName'..." "Cyan"
        wsl -d $WslDistroName -u root bash -c "grep -q 'default=$WslUsername' /etc/wsl.conf || (echo '[user]' | tee -a /etc/wsl.conf > /dev/null && echo 'default=$WslUsername' | tee -a /etc/wsl.conf > /dev/null)"
        if ($LASTEXITCODE -ne 0) {
            & $Logger.WriteLog "WARNING" "Failed to ensure default user for '$WslDistroName'. Please verify manually." "Yellow"
        }
    }
    
    return $true
}