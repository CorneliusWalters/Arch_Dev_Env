# Install.ps1 - Main entry point for Arch Linux WSL setup

# --- START: PREREQUISITE CHECK ---
# Check for Git before doing anything else.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Git is not installed or not in your PATH." -ForegroundColor Red
    Write-Host "Please install Git for Windows and try again: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}
# --- END: PREREQUISITE CHECK ---


# --- CONFIGURATION: These can still be edited if needed ---
$githubRepoUrl = "https://github.com/CorneliusWalters/Arch_Dev_Env.git"
$localClonePath = "C:\wsl\wsl-dev-setup"
$wslDistroName = "Arch"
$cleanArchTarballDefaultPath = "C:\wsl\tmp\arch_clean.tar"
$configuredArchTarballExportPath = "C:\wsl\tmp\arch_configured.tar"
$ForceOverwrite = $true
# -------------------------------------------

# --- START: INTERACTIVE USERNAME PROMPT ---
# Ask the user for their desired username. This removes the need to edit the file.
$wslUsername = Read-Host -Prompt "Please enter your desired username for Arch Linux (e.g., 'corne')"
if ([string]::IsNullOrWhiteSpace($wslUsername)) {
    Write-Host "ERROR: Username cannot be empty." -ForegroundColor Red
    exit 1
}
# --- END: INTERACTIVE USERNAME PROMPT ---


# Import the module files (adjust paths if needed)
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\PowerShell\Logging.ps1"
. "$scriptPath\PowerShell\Test.ps1"
. "$scriptPath\PowerShell\Import-Distro.ps1"
. "$scriptPath\PowerShell\Export-Image.ps1"

# Initialize logging
$logger = Initialize-WSLLogging -BasePath "C:\wsl"

# ... (The rest of the script from "Welcome and start" to the end is mostly the same)

# Welcome and start
& $logger.WriteHeader "Starting WSL Arch Linux Configuration for user '$wslUsername'"
& $logger.WriteLog "INFO" "Log file created at: $($logger.LogFile)" "Gray"

# Check prerequisites
if (-not (Test-WSLPrerequisites -Logger $logger -WslDistroName $wslDistroName)) {
    & $logger.WriteLog "ERROR" "Prerequisite check failed. Exiting." "Red"
    exit 1
}

# Import or check WSL distro
if (-not (Import-ArchDistro -Logger $logger -WslDistroName $wslDistroName -WslUsername $wslUsername -DefaultTarballPath $cleanArchTarballDefaultPath)) {
    & $logger.WriteLog "ERROR" "Failed to properly import/configure WSL distribution. Exiting." "Red"
    exit 1
}

# The script already clones the repo to $localClonePath, which is now a fixed path.
# This is fine, as the user isn't expected to change it anymore.
& $logger.WriteHeader "Cloning Setup Scripts"
if (Test-Path $localClonePath) {
    & $logger.WriteLog "INFO" "Setup directory already exists at '$localClonePath'. Removing for a clean clone." "White"
    Remove-Item -Recurse -Force $localClonePath
}
& $logger.WriteLog "INFO" "Cloning repository from $githubRepoUrl to $localClonePath..." "White"
git clone $githubRepoUrl $localClonePath
# ... (rest of the git clone logic) ...

# ... (The rest of the script is the same until the very end) ...

# --- START: AUTOMATED SHUTDOWN ---
# Add this block at the very end of the file.
& $logger.WriteHeader "Setup Complete! Shutting down WSL to apply changes."
& $logger.WriteLog "SUCCESS" "Installation completed successfully." "Green"
& $logger.WriteLog "INFO" "Log file is available at: $($logger.LogFile)" "Gray"
& $logger.WriteLog "INFO" "The script will now automatically run 'wsl --shutdown'." "Yellow"
& $logger.WriteLog "INFO" "After it finishes, you can open your new Arch terminal." "Yellow"

# Give the user a moment to read the message
Start-Sleep -Seconds 5

# Automatically shut down WSL to activate systemd via distrod.
wsl --shutdown
# --- END: AUTOMATED SHUTDOWN ---
