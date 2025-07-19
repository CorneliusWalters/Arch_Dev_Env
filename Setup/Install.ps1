# Install.ps1 - Main entry point for Arch Linux WSL setup

# --- SCRIPT-WIDE SETTINGS ---
# This is the most important line. It tells PowerShell to stop immediately on any error.
$ErrorActionPreference = "Stop"

# --- PREREQUISITE CHECK ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Git is not installed or not in your PATH." -ForegroundColor Red
    Write-Host "Please install Git for Windows and try again: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

# --- CONFIGURATION ---
$githubRepoUrl = "https://github.com/CorneliusWalters/Arch_Dev_Env.git"
$localClonePath = "C:\wsl\wsl-dev-setup"
$wslDistroName = "Arch"
$cleanArchTarballDefaultPath = "C:\wsl\tmp\arch_clean.tar"
$configuredArchTarballExportPath = "C:\wsl\tmp\arch_configured.tar"
$ForceOverwrite = $true

# --- INTERACTIVE USERNAME PROMPT ---
$wslUsername = Read-Host -Prompt "Please enter your desired username for Arch Linux (e.g., 'corne')"
if ([string]::IsNullOrWhiteSpace($wslUsername)) {
    Write-Host "ERROR: Username cannot be empty." -ForegroundColor Red
    exit 1
}

# Import the module files.
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\PowerShell\Logging.ps1"
. "$scriptPath\PowerShell\Test.ps1"
. "$scriptPath\PowerShell\Import-Distro.ps1"
. "$scriptPath\PowerShell\Export-Image.ps1"

# Create a new instance of our WslLogger class.
$logger = [WslLogger]::new("C:\wsl")

# --- MAIN EXECUTION WITH SAFETY NET ---
try {
    # Write the log header
    $logger.WriteLog("HEADER", "=== PowerShell Installation Log Started at $(Get-Date) ===", "Gray")
    $logger.WriteLog("HEADER", "User: $env:USERNAME", "Gray")
    $logger.WriteLog("HEADER", "Computer: $env:COMPUTERNAME", "Gray")
    $logger.WriteLog("HEADER", "PowerShell Version: $($PSVersionTable.PSVersion)", "Gray")
    $logger.WriteLog("HEADER", "Windows Version: $([System.Environment]::OSVersion.Version)", "Gray")
    $logger.WriteLog("HEADER", "==========================", "Gray")

    $logger.WriteHeader("Starting WSL Arch Linux Configuration for user '$wslUsername'")

    # Run prerequisite checks. If any fail, the script will stop and jump to the catch block.
    Test-WSLPrerequisites -Logger $logger -WslDistroName $wslDistroName
    Import-ArchDistro -Logger $logger -WslDistroName $wslDistroName -WslUsername $wslUsername -DefaultTarballPath $cleanArchTarballDefaultPath

    # Clone the repository
    $logger.WriteHeader("Cloning Setup Scripts")
    if (Test-Path $localClonePath) {
        $logger.WriteLog("INFO", "Setup directory already exists at '$localClonePath'. Removing for a clean clone.", "White")
        Remove-Item -Recurse -Force $localClonePath
    }
    $logger.WriteLog("INFO", "Cloning repository from $githubRepoUrl to $localClonePath...", "White")
    git clone $githubRepoUrl $localClonePath
    $logger.WriteLog("SUCCESS", "Repository cloned successfully.", "Green")

    # Create the config file inside WSL
    $logger.WriteHeader("Creating WSL Configuration File")
    $wslRepoPath = "/mnt/" + ($localClonePath -replace ':', '').Replace('\', '/')
    $wslCommandForConfig = "echo 'REPO_ROOT=`"$wslRepoPath`"' | sudo tee /etc/arch-dev-env.conf"
    wsl -d $wslDistroName -u $wslUsername -e bash -c $wslCommandForConfig
    $logger.WriteLog("SUCCESS", "WSL configuration file created.", "Green")

    # Execute the main setup script
    $logger.WriteHeader("Executing Main Setup Script inside WSL")
    $env:WSLENV = "FORCE_OVERWRITE/u"
    $env:FORCE_OVERWRITE = if ($ForceOverwrite) { "true" } else { "false" }
    $wslScriptPath = $wslRepoPath + "/Setup/1_sys_init.sh"
    $wslCommandForSetup = "chmod +x $wslScriptPath && $wslScriptPath"
    wsl -d $wslDistroName -u $wslUsername -e bash -c $wslCommandForSetup
    $logger.WriteLog("SUCCESS", "WSL setup script completed successfully.", "Green")

    # Export the final image
    Export-WSLImage -Logger $logger -WslDistroName $wslDistroName -ExportPath $configuredArchTarballExportPath

    # Final success message and shutdown
    $logger.WriteHeader("Setup Complete! Shutting down WSL to apply changes.")
    $logger.WriteLog("INFO", "The script will now automatically run 'wsl --shutdown'.", "Yellow")
    $logger.WriteLog("INFO", "After it finishes, you can open your new Arch terminal.", "Yellow")
    Start-Sleep -Seconds 5
    wsl --shutdown

} catch {
    # This block only runs if ANY command in the 'try' block fails.
    $logger.WriteLog("FATAL", "The script encountered a critical error and has stopped.", "Red")
    $logger.WriteLog("FATAL", "Error Details: $($_.Exception.Message)", "Red")
    $logger.WriteLog("INFO", "Please check the log file for more details: $($logger.LogFile)", "Yellow")
    exit 1
}