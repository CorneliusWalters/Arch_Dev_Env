# Test-Prerequisites.ps1
function Test-WSLPrerequisites {
    param (
        [PSCustomObject]$Logger,
        [string]$WslDistroName
    )
    
    & $Logger.WriteLog "INFO" "Checking WSL version..." "Cyan"
    $wslVersionInfo = wsl --version | Select-String "WSL version:"
    if ($wslVersionInfo -match "WSL version: (\d+\.\d+\.\d+\.\d+)") {
        $wslVersion = $matches[1]
        & $Logger.WriteLog "SUCCESS" "WSL Version: $wslVersion" "Green"
        
        # Convert version string to version object for comparison
        $wslVersionObj = [System.Version]$wslVersion
        $minRequiredVersion = [System.Version]"1.0.0.0"  # Set your minimum required version
        
        if ($wslVersionObj -lt $minRequiredVersion) {
            & $Logger.WriteLog "ERROR" "WSL version $wslVersion is below the minimum required version $minRequiredVersion" "Red"
            & $Logger.WriteLog "ERROR" "Please update WSL by running 'wsl --update' in an elevated PowerShell prompt." "Red"
            return $false
        }
    } else {
        & $Logger.WriteLog "WARNING" "Could not determine WSL version using 'wsl --version'. Checking alternative method..." "Yellow"
        
        # Alternative check for older WSL installations
        wsl --status 2>$null
        if ($LASTEXITCODE -ne 0) {
            & $Logger.WriteLog "ERROR" "WSL appears to be outdated or not properly installed." "Red"
            & $Logger.WriteLog "ERROR" "Please run 'wsl --update' or reinstall WSL." "Red"
            return $false
        }
    }
    
    # Check if WSL 2 is being used
    $wslDefaultVersion = wsl --status | Select-String "Default Version"
    if ($wslDefaultVersion -match "Default Version: (\d+)") {
        $defaultVersion = $matches[1]
        if ($defaultVersion -ne "2") {
            & $Logger.WriteLog "WARNING" "WSL default version is not set to 2. This setup works best with WSL 2." "Yellow"
            & $Logger.WriteLog "WARNING" "It's strongly recommended to run 'wsl --set-default-version 2' in an elevated PowerShell prompt before continuing." "Yellow"
            
            $continueAnyway = Read-Host "Do you want to continue anyway? (Y/N)"
            & $Logger.WriteLog "INFO" "User chose to continue with WSL version ${defaultVersion}: $continueAnyway" "Gray"
            if ($continueAnyway -ne "Y") {
                & $Logger.WriteLog "INFO" "Installation aborted by user" "Gray"
                return $false
            }
        } else {
            & $Logger.WriteLog "SUCCESS" "WSL 2 is correctly set as default. Good!" "Green"
        }
    } else {
        & $Logger.WriteLog "WARNING" "Could not determine default WSL version. Assuming it's properly configured." "Yellow"
    }
    
    & $Logger.WriteLog "INFO" "Checking for prerequisites (git, wsl)..." "White"
    $gitExists = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitExists) {
        & $Logger.WriteLog "ERROR" "Git is not installed or not in your PATH." "Red"
        & $Logger.WriteLog "ERROR" "Please install Git for Windows and try again: https://git-scm.com/download/win" "Red"
        return $false
    }
    
    $wslDistro = wsl -l -v | Select-String $WslDistroName
    if (-not $wslDistro) {
        & $Logger.WriteLog "ERROR" "WSL distribution '$WslDistroName' not found." "Red"
        & $Logger.WriteLog "ERROR" "This might be expected if you're planning to import it." "Red"
    }
    
    & $Logger.WriteLog "SUCCESS" "Prerequisites check completed." "Green"
    return $true
}