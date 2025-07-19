# Import-Distro.ps1

function Import-ArchDistro {
    param (
        [PSCustomObject]$Logger,
        [string]$WslDistroName,
        [string]$WslUsername,
        [string]$DefaultTarballPath
    )

    $Logger.WriteHeader("Checking for Pristine Arch Image")

    # --- The Critical Part: The Logic You Described ---

    # SCENARIO 1: The pristine tarball already exists. This is the fast path for re-runs.
    if (Test-Path $DefaultTarballPath) {
        $Logger.WriteLog("SUCCESS", "Pristine '$DefaultTarballPath' found.", "Green")
        # Proceed to the import logic at the end of the function.
    }
    # SCENARIO 2: The tarball is missing, but a base Arch distro IS installed.
    elseif (wsl -l -v | Select-String -Quiet $WslDistroName) {
        $Logger.WriteLog("INFO", "Pristine tarball not found, but a base '$WslDistroName' distro exists.", "Cyan")
        $Logger.WriteLog("INFO", "Exporting the existing distro to create the pristine image...", "Cyan")
        
        $tmpDir = Split-Path $DefaultTarballPath -Parent
        if (-not (Test-Path $tmpDir)) {
            New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        }

        wsl --export $WslDistroName $DefaultTarballPath
        $Logger.WriteLog("SUCCESS", "Successfully created pristine image at '$DefaultTarballPath'.", "Green")
        $Logger.WriteLog("INFO", "Please re-run the script to continue the installation using the new image.", "Yellow")
        exit 0 # Exit successfully, prompting the user to re-run.
    }
    # SCENARIO 3: Nothing exists. This is a true first run.
    else {
        $Logger.WriteLog("WARNING", "No pristine image or base WSL distro found.", "Yellow")
        $Logger.WriteLog("INFO", "Attempting to install Arch Linux from the Microsoft Store...", "Cyan")
        $Logger.WriteLog("INFO", "This may require user interaction (creating a user, setting a password).", "Cyan")
        
        try {
            wsl --install -d ArchLinux
            $Logger.WriteLog("SUCCESS", "Base Arch Linux installation complete.", "Green")
            $Logger.WriteLog("IMPORTANT", "The script will now exit. Please complete the initial Arch Linux setup (create user, set password).", "Yellow")
            $Logger.WriteLog("IMPORTANT", "Once you are done, CLOSE the Arch window and RE-RUN THIS SCRIPT.", "Yellow")
            $Logger.WriteLog("IMPORTANT", "The next run will export your new installation as the pristine image.", "Yellow")
        } catch {
            $Logger.WriteLog("ERROR", "Failed to install Arch Linux via 'wsl --install'.", "Red")
            $Logger.WriteLog("ERROR", "Please manually obtain an 'arch_clean.tar' file and place it at '$DefaultTarballPath'.", "Red")
            throw "Failed to create a base image."
        }
        exit 0 # Exit successfully, as the user needs to take manual steps.
    }

    # --- The Original Import Logic ---
    # This part only runs if Scenario 1 was met.
    $Logger.WriteHeader("Importing Distro for Automated Setup")

    # Unregister any existing "automated" distro to ensure a clean slate.
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
    
    $Logger.WriteLog("SUCCESS", "Distro imported and configured for automated setup.", "Green")
    return $true
}
