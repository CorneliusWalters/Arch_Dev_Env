# Import-Distro.ps1

function Import-ArchDistro {
    param (
        [PSCustomObject]$Logger,
        [string]$WslDistroName,
        [string]$WslUsername,
        [string]$DefaultTarballPath
    )

    $Logger.WriteHeader("Checking for Pristine Arch Image")

    # If the pristine tarball doesn't exist, we create it.
    if (-not (Test-Path $DefaultTarballPath)) {
        
        # Check if a base distro is already installed (from a previous failed run)
        $baseDistroName = "ArchLinux" # The name from the Microsoft Store
        if (-not (wsl -l -v | Select-String -Quiet $baseDistroName)) {
            $Logger.WriteLog("WARNING", "No pristine image or base WSL distro found.", "Yellow")
            $Logger.WriteLog("INFO", "Attempting to install '$baseDistroName' from the Microsoft Store...", "Cyan")
            $Logger.WriteLog("IMPORTANT", "An Arch Linux window will now open. Please complete the setup (create a user, set a password).", "Yellow")
            $Logger.WriteLog("IMPORTANT", "This script will wait for you to finish.", "Yellow")
            
            try {
                wsl --install -d $baseDistroName
            } catch {
                $Logger.WriteLog("ERROR", "Failed to install Arch Linux via 'wsl --install'.", "Red")
                throw "Failed to create a base image."
            }
        }

        # --- THE WATCHER LOOP ---
        $Logger.WriteLog("INFO", "Now waiting for you to complete the initial setup in the '$baseDistroName' window...", "Cyan")
        while (wsl -l -v | Select-String -Quiet "$baseDistroName\s+Running") {
            Write-Host -NoNewline "."
            Start-Sleep -Seconds 5
        }
        Write-Host "" # Newline after the dots.

        $Logger.WriteLog("SUCCESS", "Initial setup complete. Now creating the pristine image...", "Green")
        
        $tmpDir = Split-Path $DefaultTarballPath -Parent
        if (-not (Test-Path $tmpDir)) {
            New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        }

        wsl --export $baseDistroName $DefaultTarballPath
        $Logger.WriteLog("SUCCESS", "Successfully created pristine image at '$DefaultTarballPath'.", "Green")
        
        # We are done with the base image, unregister it to keep things clean.
        wsl --unregister $baseDistroName
    }

    # --- The Original Import Logic ---
    $Logger.WriteHeader("Importing '$WslDistroName' for Automated Setup")

    if (wsl -l -v | Select-String -Quiet $WslDistroName) {
        $Logger.WriteLog("INFO", "Unregistering existing '$WslDistroName' to ensure a clean import.", "Yellow")
        wsl --unregister $WslDistroName
    }

    $archInstallDir = "C:\WSL\$WslDistroName"
    if (-not (Test-Path $archInstallDir)) {
        New-Item -ItemType Directory -Path $archInstallDir -Force | Out-Null
    }
    
    $Logger.WriteLog("INFO", "Importing '$WslDistroName' from '$DefaultTarballPath'...", "Cyan")
    wsl --import $WslDistroName $archInstallDir $DefaultTarballPath
    
    $Logger.WriteLog("INFO", "Setting default user to '$WslUsername'...", "Cyan")
    wsl -d $WslDistroName -u root -- bash -c "echo '[user]' | tee /etc/wsl.conf > /dev/null && echo 'default=$WslUsername' | tee -a /etc/wsl.conf > /dev/null"
    
    $Logger.WriteLog("SUCCESS", "Distro imported and configured. Proceeding with setup.", "Green")
    return $true
}
