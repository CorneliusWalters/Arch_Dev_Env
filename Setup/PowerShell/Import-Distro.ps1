# Import-Distro.ps1
function Import-ArchDistro {
    param (
        [PSCustomObject]$Logger,
        [string]$WslDistroName,
        [string]$WslUsername,
        [string]$DefaultTarballPath
    )
    
    $Logger.WriteHeader("Checking / Importing WSL Distribution '$WslDistroName'")
    $wslDistroExists = (wsl -l -v | Select-String $WslDistroName -Quiet)
    
    if (-not $wslDistroExists) {
        $Logger.WriteLog("WARNING", "WSL distribution '$WslDistroName' not found.", "Yellow")
        $Logger.WriteLog("INFO", "Attempting to import from '$DefaultTarballPath'.", "Cyan")
        
        if (-not (Test-Path $DefaultTarballPath)) {
            $Logger.WriteLog("ERROR", "Clean Arch tarball not found at '$DefaultTarballPath'.", "Red")
            throw "Clean Arch tarball not found."
        }

        $archInstallDir = "C:\WSL\$WslDistroName"
        if (-not (Test-Path $archInstallDir)) {
            New-Item -ItemType Directory -Path $archInstallDir -Force | Out-Null
        }
        
        $Logger.WriteLog("INFO", "Running wsl --import...", "Gray")
        wsl --import $WslDistroName $archInstallDir $DefaultTarballPath
        $Logger.WriteLog("SUCCESS", "WSL distribution '$WslDistroName' imported.", "Green")

        $Logger.WriteLog("INFO", "Setting default user to '$WslUsername'...", "Cyan")
        wsl -d $WslDistroName -u root -- bash -c "echo '[user]' | tee /etc/wsl.conf > /dev/null && echo 'default=$WslUsername' | tee -a /etc/wsl.conf > /dev/null"
        $Logger.WriteLog("SUCCESS", "Default user set.", "Green")
    } else {
        $Logger.WriteLog("SUCCESS", "WSL distribution '$WslDistroName' already exists.", "Green")
    }
    
    return $true
}