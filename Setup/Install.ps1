# Install.ps1 - Main entry point for Arch Linux WSL setup

# --- CONFIGURATION: EDIT THESE VARIABLES ---
$githubRepoUrl = "https://github.com/CorneliusWalters/Arch_Dev_Env.git"
$localClonePath = "C:\wsl\wsl-dev-setup"
$wslDistroName = "Arch"
$wslUsername = "CHW"
$cleanArchTarballDefaultPath = "C:\wsl\tmp\arch_clean.tar" # Default for importing a clean distro
$configuredArchTarballExportPath = "C:\wsl\tmp\arch_configured.tar" # Default for exporting configured distro
# -------------------------------------------

# Import the module files (adjust paths if needed)
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\PowerShell\Logging.ps1"
. "$scriptPath\PowerShell\Test.ps1"
. "$scriptPath\PowerShell\Import-Distro.ps1"
. "$scriptPath\PowerShell\Export-Image.ps1"

# Initialize logging
$logger = Initialize-WSLLogging -BasePath "C:\wsl"

# Welcome and start
& $logger.WriteHeader "Starting WSL Arch Linux Configuration"
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

# Clone the Git Repository
& $logger.WriteHeader "Cloning Setup Scripts"
if (Test-Path $localClonePath) {
    & $logger.WriteLog "INFO" "Setup directory already exists at '$localClonePath'. Removing for a clean clone." "White"
    Remove-Item -Recurse -Force $localClonePath
}
& $logger.WriteLog "INFO" "Cloning repository from $githubRepoUrl to $localClonePath..." "White"
git clone $githubRepoUrl $localClonePath
if ($LASTEXITCODE -ne 0) {
    & $logger.WriteLog "ERROR" "Failed to clone the Git repository." "Red"
    exit 1
}
& $logger.WriteLog "SUCCESS" "Repository cloned successfully." "Green"

# Execute the Main Setup Script inside WSL
& $logger.WriteHeader "Executing Main Setup Script inside WSL"
& $logger.WriteLog "INFO" "This will run '1_sys_init.sh' as user '$wslUsername' in the '$wslDistroName' distro." "White"
& $logger.WriteLog "INFO" "You will see output from the script and may be prompted for your sudo password." "White"

# Convert Windows path to WSL path
$wslScriptPath = "/mnt/" + ($localClonePath -replace ':', '').Replace('\', '/') + "/Setup/1_sys_init.sh"
& $logger.WriteLog "INFO" "WSL script path: $wslScriptPath" "Gray"

# The command to run inside WSL. It makes the script executable, then runs it.
$wslCommand = "chmod +x $wslScriptPath && $wslScriptPath"
& $logger.WriteLog "INFO" "Executing in WSL: $wslCommand" "Gray"

# Execute the command
& $logger.WriteLog "INFO" "Running script in WSL..." "Cyan"
wsl -d $wslDistroName -u $wslUsername -e bash -c $wslCommand

if ($LASTEXITCODE -ne 0) {
    & $logger.WriteLog "ERROR" "The setup script inside WSL failed. Check the terminal output above for details." "Red"
    exit 1
}
& $logger.WriteLog "SUCCESS" "WSL setup script completed successfully." "Green"

# Export the configured distro if requested
Export-WSLImage -Logger $logger -WslDistroName $wslDistroName -ExportPath $configuredArchTarballExportPath

& $logger.WriteHeader "Setup Complete!"
& $logger.WriteLog "SUCCESS" "Installation completed successfully." "Green" 
& $logger.WriteLog "INFO" "Please close this terminal and open a new Arch WSL terminal." "Green"
& $logger.WriteLog "INFO" "All changes should be applied." "White"
& $logger.WriteLog "INFO" "Log file is available at: $($logger.LogFile)" "Gray"