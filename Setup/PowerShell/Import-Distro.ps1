# Import-Distro.ps1

function Import-ArchDistro {
    param (
        [PSCustomObject]$Logger,
        [string]$WslDistroName,
        [string]$WslUsername,
        [string]$DefaultTarballPath
    )

    # --- PHASE 1: CREATE PRISTINE IMAGE IF NEEDED ---
    $Logger.WriteHeader("Checking for Pristine Arch Image")
    if (-not (Test-Path $DefaultTarballPath)) {
        $baseDistroName = "ArchLinux"
        if (-not (wsl -l -v | Select-String -Quiet $baseDistroName)) {
            $Logger.WriteLog("INFO", "Attempting to install '$baseDistroName' from the Microsoft Store...", "Cyan")
            wsl --install -d $baseDistroName
        }
        $Logger.WriteLog("INFO", "Now waiting for you to complete the initial setup in the '$baseDistroName' window...", "Cyan")
        while (wsl -l -v | Select-String -Quiet "$baseDistroName\s+Running") {
            Write-Host -NoNewline "."
            Start-Sleep -Seconds 5
        }
        Write-Host ""
        $Logger.WriteLog("SUCCESS", "Initial setup complete. Now creating the pristine image...", "Green")
        $tmpDir = Split-Path $DefaultTarballPath -Parent
        if (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null }
        wsl --export $baseDistroName $DefaultTarballPath
        $Logger.WriteLog("SUCCESS", "Successfully created pristine image at '$DefaultTarballPath'.", "Green")
        wsl --unregister $baseDistroName
    }

    # --- PHASE 2: IMPORT DISTRO FOR AUTOMATED SETUP ---
    $Logger.WriteHeader("Importing '$WslDistroName' for Automated Setup")
    
    # Aggressive Cleanup: Forcefully unregister any old distro with the same name.
    try {
        $Logger.WriteLog("INFO", "Attempting to unregister any existing '$WslDistroName' distro to ensure a clean slate...", "Yellow")
        wsl --unregister $WslDistroName
        $Logger.WriteLog("INFO", "Cleanup successful.", "Gray")
    } catch {
        # This is expected if the distro doesn't exist. We can ignore this error.
        $Logger.WriteLog("INFO", "No pre-existing distro to clean up.", "Gray")
    }

    $archInstallDir = "C:\WSL\$WslDistroName"
    if (-not (Test-Path $archInstallDir)) {
        New-Item -ItemType Directory -Path $archInstallDir -Force | Out-Null
    }
    
    $Logger.WriteLog("INFO", "Importing '$WslDistroName' from '$DefaultTarballPath'...", "Cyan")
    wsl --import $WslDistroName $archInstallDir $DefaultTarballPath
    
    # Definitive Verification: Check if the virtual disk was actually created.
    $vhdxPath = "$archInstallDir\ext4.vhdx"
    if (-not (Test-Path $vhdxPath)) {
        throw "FATAL: 'wsl --import' failed to create the virtual disk at '$vhdxPath'. Cannot continue."
    }
    $Logger.WriteLog("SUCCESS", "Virtual disk verified. Import was successful.", "Green")

    $Logger.WriteLog("INFO", "Setting default user to '$WslUsername'...", "Cyan")
    wsl -d $WslDistroName -u root -- bash -c "echo '[user]' | tee /etc/wsl.conf > /dev/null && echo 'default=$WslUsername' | tee -a /etc/wsl.conf > /dev/null"
    
    $Logger.WriteLog("SUCCESS", "Distro imported and configured. Proceeding with setup.", "Green")
    return $true
}