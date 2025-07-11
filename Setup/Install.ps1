# install.ps1 - Bootstrapper for configuring an existing WSL Arch Linux instance.

# --- CONFIGURATION: EDIT THESE VARIABLES ---
$githubRepoUrl = "https://github.com/CorneliusWalters/Arch_Dev_Env.git"
$localClonePath = "C:\wsl\wsl-dev-setup"
$wslDistroName = "Arch"
$wslUsername = "CHW"
$cleanArchTarballDefaultPath = "C:\wsl\tmp\arch_clean.tar" # Default for importing a clean distro
$configuredArchTarballExportPath = "C:\wsl\tmp\arch_configured.tar" # Default for exporting configured distro
# -------------------------------------------

# --- LOGGING SETUP ---
$wslBasePath = "C:\wsl"
$tmpPath = "$wslBasePath\tmp"
$logsPath = "$tmpPath\logs"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir = "$logsPath\$timestamp"
$logFile = "$logDir\powershell_install.log"

# Create log directories
$directoriesToCreate = @($wslBasePath, $tmpPath, $logsPath, $logDir)
foreach ($dir in $directoriesToCreate) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Initialize log file with header
"=== PowerShell Installation Log Started at $(Get-Date) ===" | Out-File -FilePath $logFile
"=== System Information ===" | Out-File -FilePath $logFile -Append
"User: $env:USERNAME" | Out-File -FilePath $logFile -Append
"Computer: $env:COMPUTERNAME" | Out-File -FilePath $logFile -Append
"PowerShell Version: $($PSVersionTable.PSVersion)" | Out-File -FilePath $logFile -Append
"Windows Version: $([System.Environment]::OSVersion.Version)" | Out-File -FilePath $logFile -Append
"Script Path: $PSCommandPath" | Out-File -FilePath $logFile -Append
"==========================" | Out-File -FilePath $logFile -Append

# Logging function
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Level,
        
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ConsoleColor]$ForegroundColor = "White"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console with color
    Write-Host $logMessage -ForegroundColor $ForegroundColor
    
    # Write to log file
    $logMessage | Out-File -FilePath $logFile -Append
}

function Write-Header {
    param([string]$Message)
    $separator = "================================================================="
    Write-Log "HEADER" $separator "Cyan"
    Write-Log "HEADER" $Message "Cyan"
    Write-Log "HEADER" $separator "Cyan"
}

# --- SCRIPT LOGIC ---
Write-Header "Starting WSL Arch Linux Configuration"
Write-Log "INFO" "Log file created at: $logFile" "Gray"

# 1. Prerequisite Checks
Write-Log "INFO" "Checking WSL version..." "Cyan"
$wslVersionInfo = wsl --version | Select-String "WSL version:"
if ($wslVersionInfo -match "WSL version: (\d+\.\d+\.\d+\.\d+)") {
    $wslVersion = $matches[1]
    Write-Log "SUCCESS" "WSL Version: $wslVersion" "Green"
    
    # Convert version string to version object for comparison
    $wslVersionObj = [System.Version]$wslVersion
    $minRequiredVersion = [System.Version]"1.0.0.0"  # Set your minimum required version
    
    if ($wslVersionObj -lt $minRequiredVersion) {
        Write-Log "ERROR" "WSL version $wslVersion is below the minimum required version $minRequiredVersion" "Red"
        Write-Log "ERROR" "Please update WSL by running 'wsl --update' in an elevated PowerShell prompt." "Red"
        exit 1
    }
} else {
    Write-Log "WARNING" "Could not determine WSL version using 'wsl --version'. Checking alternative method..." "Yellow"
    
    # Alternative check for older WSL installations
    wsl --status 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR" "WSL appears to be outdated or not properly installed." "Red"
        Write-Log "ERROR" "Please run 'wsl --update' or reinstall WSL." "Red"
        exit 1
    }
}

# Check if WSL 2 is being used
$wslDefaultVersion = wsl --status | Select-String "Default Version"
if ($wslDefaultVersion -match "Default Version: (\d+)") {
    $defaultVersion = $matches[1]
    if ($defaultVersion -ne "2") {
        Write-Log "WARNING" "WSL default version is not set to 2. This setup works best with WSL 2." "Yellow"
        Write-Log "WARNING" "It's strongly recommended to run 'wsl --set-default-version 2' in an elevated PowerShell prompt before continuing." "Yellow"
        
        $continueAnyway = Read-Host "Do you want to continue anyway? (Y/N)"
        Write-Log "INFO" "User chose to continue with WSL version ${defaultVersion}: $continueAnyway" "Gray"
        if ($continueAnyway -ne "Y") {
            Write-Log "INFO" "Installation aborted by user" "Gray"
            exit 1
        }
    } else {
        Write-Log "SUCCESS" "WSL 2 is correctly set as default. Good!" "Green"
    }
} else {
    Write-Log "WARNING" "Could not determine default WSL version. Assuming it's properly configured." "Yellow"
}

Write-Log "INFO" "Checking for prerequisites (git, wsl)..." "White"
$gitExists = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitExists) {
    Write-Log "ERROR" "Git is not installed or not in your PATH." "Red"
    Write-Log "ERROR" "Please install Git for Windows and try again: https://git-scm.com/download/win" "Red"
    exit 1
}

$wslDistro = wsl -l -v | Select-String $wslDistroName
if (-not $wslDistro) {
    Write-Log "ERROR" "WSL distribution '$wslDistroName' not found." "Red"
    Write-Log "ERROR" "Please run 'wsl --install archlinux' first and complete the initial user setup." "Red"
    exit 1
}
Write-Log "SUCCESS" "Prerequisites found." "Green"

# 2. Check and/or Import WSL Distribution
Write-Header "Checking / Importing WSL Distribution '$wslDistroName'"
$wslDistroExists = (wsl -l -v | Select-String $wslDistroName -Quiet)

if (-not $wslDistroExists) {
    Write-Log "WARNING" "WSL distribution '$wslDistroName' not found." "Yellow"
    Write-Log "WARNING" "You need a clean Arch Linux .tar file to import it." "Yellow"
    
    $tarPath = Read-Host "Enter the full path to your arch_clean.tar (or press Enter for default '$cleanArchTarballDefaultPath')"
    Write-Log "INFO" "User provided tarball path: $tarPath" "Gray"
    
    if ([string]::IsNullOrWhiteSpace($tarPath)) {
        $tarPath = $cleanArchTarballDefaultPath
        Write-Log "INFO" "Using default tarball path: $tarPath" "Gray"
    }

    if (-not (Test-Path $tarPath)) {
        Write-Log "ERROR" "Clean Arch tarball not found at '$tarPath'." "Red"
        Write-Log "ERROR" "Please obtain a clean Arch Linux .tar file (e.g., from Arch Linux WSL project releases) and place it there, then re-run this script." "Red"
        exit 1
    }

    $archInstallDir = "C:\WSL\$wslDistroName"
    Write-Log "INFO" "Importing '$wslDistroName' from '$tarPath' to '$archInstallDir'..." "Cyan"
    if (-not (Test-Path $archInstallDir)) {
        New-Item -ItemType Directory -Path $archInstallDir -Force | Out-Null
        Write-Log "INFO" "Created directory: $archInstallDir" "Gray"
    }
    
    Write-Log "INFO" "Running wsl --import $wslDistroName $archInstallDir $tarPath" "Gray"
    wsl --import $wslDistroName $archInstallDir $tarPath
    if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR" "Failed to import WSL distribution '$wslDistroName'." "Red"
        exit 1
    }
    Write-Log "SUCCESS" "WSL distribution '$wslDistroName' imported successfully." "Green"

    # Set the default user for the newly imported distro
    Write-Log "INFO" "Setting default user to '$wslUsername' for '$wslDistroName'..." "Cyan"
    wsl -d $wslDistroName -u root bash -c "echo '[user]' | tee /etc/wsl.conf > /dev/null && echo 'default=$wslUsername' | tee -a /etc/wsl.conf > /dev/null"
    if ($LASTEXITCODE -ne 0) {
        Write-Log "WARNING" "Failed to set default user for '$wslDistroName' in /etc/wsl.conf. You may need to set it manually by running 'Arch config --default-user $wslUsername' after the script." "Yellow"
    } else {
        Write-Log "SUCCESS" "Default user '$wslUsername' set for '$wslDistroName'. A WSL restart might be needed for this to fully apply on first run." "Green"
    }
} else {
    Write-Log "SUCCESS" "WSL distribution '$wslDistroName' found. Proceeding with configuration." "Green"
    Write-Log "INFO" "Ensuring default user is '$wslUsername' for '$wslDistroName'..." "Cyan"
    wsl -d $wslDistroName -u root bash -c "grep -q 'default=$wslUsername' /etc/wsl.conf || (echo '[user]' | tee -a /etc/wsl.conf > /dev/null && echo 'default=$wslUsername' | tee -a /etc/wsl.conf > /dev/null)"
    if ($LASTEXITCODE -ne 0) {
        Write-Log "WARNING" "Failed to ensure default user for '$wslDistroName'. Please verify manually." "Yellow"
    }
}

# 3. Clone the Git Repository
Write-Header "Cloning Setup Scripts"
if (Test-Path $localClonePath) {
    Write-Log "INFO" "Setup directory already exists at '$localClonePath'. Removing for a clean clone." "White"
    Remove-Item -Recurse -Force $localClonePath
}
Write-Log "INFO" "Cloning repository from $githubRepoUrl to $localClonePath..." "White"
git clone $githubRepoUrl $localClonePath
if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR" "Failed to clone the Git repository." "Red"
    exit 1
}
Write-Log "SUCCESS" "Repository cloned successfully." "Green"

# 4. Execute the Main Setup Script inside WSL
Write-Header "Executing Main Setup Script inside WSL"
Write-Log "INFO" "This will run '1_sys_init.sh' as user '$wslUsername' in the '$wslDistroName' distro." "White"
Write-Log "INFO" "You will see output from the script and may be prompted for your sudo password." "White"

# Convert Windows path to WSL path
$wslScriptPath = "/mnt/" + ($localClonePath -replace ':', '').Replace('\', '/') + "/Setup/1_sys_init.sh"
Write-Log "INFO" "WSL script path: $wslScriptPath" "Gray"

# The command to run inside WSL. It makes the script executable, then runs it.
$wslCommand = "chmod +x $wslScriptPath && $wslScriptPath"
Write-Log "INFO" "Executing in WSL: $wslCommand" "Gray"

# Execute the command
Write-Log "INFO" "Running script in WSL..." "Cyan"
wsl -d $wslDistroName -u $wslUsername -e bash -c $wslCommand

if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR" "The setup script inside WSL failed. Check the terminal output above for details." "Red"
    exit 1
}
Write-Log "SUCCESS" "WSL setup script completed successfully." "Green"

# 5. Optional: Export a "golden image" of the configured WSL instance
Write-Header "Optional: Exporting Configured WSL Instance"
$exportConfirm = Read-Host "Do you want to export this configured WSL instance as '$wslDistroName' to '$configuredArchTarballExportPath'? (Y/N)"
Write-Log "INFO" "User chose to export configured WSL instance: $exportConfirm" "Gray"

if ($exportConfirm -eq 'Y') {
    Write-Log "INFO" "Exporting current state of '$wslDistroName' to '$configuredArchTarballExportPath'..." "Cyan"
    Write-Log "INFO" "Terminating WSL instance before export..." "Gray"
    wsl --terminate $wslDistroName # Terminate to ensure consistent export
    
    # Ensure directory for export exists
    $exportDir = Split-Path $configuredArchTarballExportPath -Parent
    if (-not (Test-Path $exportDir)) {
        New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        Write-Log "INFO" "Created export directory: $exportDir" "Gray"
    }
    
    Write-Log "INFO" "Running wsl --export $wslDistroName $configuredArchTarballExportPath" "Gray"
    wsl --export $wslDistroName $configuredArchTarballExportPath
    if ($LASTEXITCODE -ne 0) {
        Write-Log "WARNING" "Failed to export configured WSL distribution." "Yellow"
    } else {
        Write-Log "SUCCESS" "Configured WSL distribution exported successfully." "Green"
        Write-Log "INFO" "You can use this for future quick setups or backups." "Green"
        Write-Log "INFO" "To re-import: wsl --import $wslDistroName C:\WSL\$wslDistroName $configuredArchTarballExportPath" "Green"
    }
} else {
    Write-Log "INFO" "Skipping export of configured WSL instance." "Green"
}

Write-Header "Setup Complete!"
Write-Log "SUCCESS" "Installation completed successfully." "Green" 
Write-Log "INFO" "Please close this terminal and open a new Arch WSL terminal." "Green"
Write-Log "INFO" "All changes should be applied." "White"
Write-Log "INFO" "Log file is available at: $logFile" "Gray"