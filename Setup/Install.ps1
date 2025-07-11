# install.ps1 - Bootstrapper for configuring an existing WSL Arch Linux instance.

# --- CONFIGURATION: EDIT THESE VARIABLES ---
$githubRepoUrl = "https://github.com/CorneliusWalters/Arch_Dev_Env.git"
$localClonePath = "C:\wsl\wsl-dev-setup"
$wslDistroName = "Arch"
$wslUsername = "CHW"
$cleanArchTarballDefaultPath = "C:\wsl\tmp\arch_clean.tar" # Default for importing a clean distro
$configuredArchTarballExportPath = "C:\wsl\tmp\arch_configured.tar" # Default for exporting configured distro                                           # <-- VERY IMPORTANT: EDIT THIS to your default WSL username
# -------------------------------------------

# --- SCRIPT LOGIC ---
function Write-Header {
    param([string]$Message)
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "================================================================="
}

Write-Header "Starting WSL Arch Linux Configuration"

# 1. Prerequisite Checks

Write-Host "Checking WSL version..." -ForegroundColor Cyan
$wslVersionInfo = wsl --version | Select-String "WSL version:"
if ($wslVersionInfo -match "WSL version: (\d+\.\d+\.\d+\.\d+)") {
    $wslVersion = $matches[1]
    Write-Host "WSL Version: $wslVersion" -ForegroundColor Green
    
    # Convert version string to version object for comparison
    $wslVersionObj = [System.Version]$wslVersion
    $minRequiredVersion = [System.Version]"1.0.0.0"  # Set your minimum required version
    
    if ($wslVersionObj -lt $minRequiredVersion) {
        Write-Host "ERROR: WSL version $wslVersion is below the minimum required version $minRequiredVersion" -ForegroundColor Red
        Write-Host "Please update WSL by running 'wsl --update' in an elevated PowerShell prompt." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "WARNING: Could not determine WSL version using 'wsl --version'. Checking alternative method..." -ForegroundColor Yellow
    
    # Alternative check for older WSL installations
    $wslStatus = wsl --status 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: WSL appears to be outdated or not properly installed." -ForegroundColor Red
        Write-Host "Please run 'wsl --update' or reinstall WSL." -ForegroundColor Red
        exit 1
    }
}

# Check if WSL 2 is being used
$wslDefaultVersion = wsl --status | Select-String "Default Version"
if ($wslDefaultVersion -match "Default Version: (\d+)") {
    $defaultVersion = $matches[1]
    if ($defaultVersion -ne "2") {
        Write-Host "WARNING: WSL default version is not set to 2. This setup works best with WSL 2." -ForegroundColor Yellow
        Write-Host "It's strongly recommended to run 'wsl --set-default-version 2' in an elevated PowerShell prompt before continuing." -ForegroundColor Yellow
        
        $continueAnyway = Read-Host "Do you want to continue anyway? (Y/N)"
        if ($continueAnyway -ne "Y") {
            exit 1
        }
    } else {
        Write-Host "WSL 2 is correctly set as default. Good!" -ForegroundColor Green
    }
} else {
    Write-Host "WARNING: Could not determine default WSL version. Assuming it's properly configured." -ForegroundColor Yellow
}


Write-Host "Checking for prerequisites (git, wsl)..."
$gitExists = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitExists) {
    Write-Host "ERROR: Git is not installed or not in your PATH." -ForegroundColor Red
    Write-Host "Please install Git for Windows and try again: https://git-scm.com/download/win"
    exit 1
}

$wslDistro = wsl -l -v | Select-String $wslDistroName
if (-not $wslDistro) {
    Write-Host "ERROR: WSL distribution '$wslDistroName' not found." -ForegroundColor Red
    Write-Host "Please run 'wsl --install archlinux' first and complete the initial user setup."
    exit 1
}
Write-Host "Prerequisites found." -ForegroundColor Green

# 2. Check and/or Import WSL Distribution
Write-Header "Checking / Importing WSL Distribution '$wslDistroName'"
$wslDistroExists = (wsl -l -v | Select-String $wslDistroName -Quiet)

if (-not $wslDistroExists) {
    Write-Host "WSL distribution '$wslDistroName' not found." -ForegroundColor Yellow
    Write-Host "You need a clean Arch Linux .tar file to import it." -ForegroundColor Yellow
    
    $tarPath = Read-Host "Enter the full path to your arch_clean.tar (or press Enter for default '$cleanArchTarballDefaultPath')"
    if ([string]::IsNullOrWhiteSpace($tarPath)) {
        $tarPath = $cleanArchTarballDefaultPath
    }

    if (-not (Test-Path $tarPath)) {
        Write-Host "ERROR: Clean Arch tarball not found at '$tarPath'." -ForegroundColor Red
        Write-Host "Please obtain a clean Arch Linux .tar file (e.g., from Arch Linux WSL project releases) and place it there, then re-run this script." -ForegroundColor Red
        exit 1
    }

    $archInstallDir = "C:\WSL\$wslDistroName"
    Write-Host "Importing '$wslDistroName' from '$tarPath' to '$archInstallDir'..." -ForegroundColor Cyan
    if (-not (Test-Path $archInstallDir)) {
        New-Item -ItemType Directory -Path $archInstallDir -Force | Out-Null
    }
    
    wsl --import $wslDistroName $archInstallDir $tarPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to import WSL distribution '$wslDistroName'." -ForegroundColor Red
        exit 1
    }
    Write-Host "WSL distribution '$wslDistroName' imported successfully." -ForegroundColor Green

    # Set the default user for the newly imported distro
    # This command creates or modifies /etc/wsl.conf to set the default user.
    Write-Host "Setting default user to '$wslUsername' for '$wslDistroName'..." -ForegroundColor Cyan
    wsl -d $wslDistroName -u root bash -c "echo '[user]' | tee /etc/wsl.conf > /dev/null && echo 'default=$wslUsername' | tee -a /etc/wsl.conf > /dev/null"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Failed to set default user for '$wslDistroName' in /etc/wsl.conf. You may need to set it manually by running 'Arch config --default-user $wslUsername' after the script." -ForegroundColor Yellow
    } else {
        Write-Host "Default user '$wslUsername' set for '$wslDistroName'. A WSL restart might be needed for this to fully apply on first run." -ForegroundColor Green
    }
} else {
    Write-Host "WSL distribution '$wslDistroName' found. Proceeding with configuration." -ForegroundColor Green
    # Ensure default user is set for existing distro too, gracefully handle if already set
    Write-Host "Ensuring default user is '$wslUsername' for '$wslDistroName'..." -ForegroundColor Cyan
    wsl -d $wslDistroName -u root bash -c "grep -q 'default=$wslUsername' /etc/wsl.conf || (echo '[user]' | tee -a /etc/wsl.conf > /dev/null && echo 'default=$wslUsername' | tee -a /etc/wsl.conf > /dev/null)"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Failed to ensure default user for '$wslDistroName'. Please verify manually." -ForegroundColor Yellow
    }
}

# 3. Clone the Git Repository
Write-Header "Cloning Setup Scripts"
if (Test-Path $localClonePath) {
    Write-Host "Setup directory already exists at '$localClonePath'. Removing for a clean clone."
    Remove-Item -Recurse -Force $localClonePath
}
Write-Host "Cloning repository from $githubRepoUrl to $localClonePath..."
git clone $githubRepoUrl $localClonePath
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to clone the Git repository." -ForegroundColor Red
    exit 1
}
Write-Host "Repository cloned successfully." -ForegroundColor Green

# 4. Execute the Main Setup Script inside WSL
Write-Header "Executing Main Setup Script inside WSL"
Write-Host "This will run '1_sys_init.sh' as user '$wslUsername' in the '$wslDistroName' distro."
Write-Host "You will see output from the script and may be prompted for your sudo password."

# Convert Windows path to WSL path
$wslScriptPath = "/mnt/" + ($localClonePath -replace ':', '').Replace('\', '/') + "/1_sys_init.sh"

# The command to run inside WSL. It makes the script executable, then runs it.
$wslCommand = "chmod +x $wslScriptPath && $wslScriptPath"

# Execute the command
wsl -d $wslDistroName -u $wslUsername -e bash -c $wslCommand

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: The setup script inside WSL failed. Check the terminal output above for details." -ForegroundColor Red
    exit 1
}

# 5. Optional: Export a "golden image" of the configured WSL instance
Write-Header "Optional: Exporting Configured WSL Instance"
$exportConfirm = Read-Host "Do you want to export this configured WSL instance as '$wslDistroName' to '$configuredArchTarballExportPath'? (Y/N)"
if ($exportConfirm -eq 'Y') {
    Write-Host "Exporting current state of '$wslDistroName' to '$configuredArchTarballExportPath'..." -ForegroundColor Cyan
    wsl --terminate $wslDistroName # Terminate to ensure consistent export
    # Ensure directory for export exists
    $exportDir = Split-Path $configuredArchTarballExportPath -Parent
    if (-not (Test-Path $exportDir)) {
        New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
    }
    wsl --export $wslDistroName $configuredArchTarballExportPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Failed to export configured WSL distribution." -ForegroundColor Yellow
    } else {
        Write-Host "Configured WSL distribution exported successfully." -ForegroundColor Green
        Write-Host "You can use this for future quick setups or backups." -ForegroundColor Green
        Write-Host "To re-import: wsl --import $wslDistroName C:\WSL\$wslDistroName $configuredArchTarballExportPath" -ForegroundColor Green
    }
} else {
    Write-Host "Skipping export of configured WSL instance." -ForegroundColor Green
}

Write-Header "Setup Complete!"
Write-Host "Please close this terminal and open a new Arch WSL terminal." -ForegroundColor Green
Write-Host "All changes should be applied."