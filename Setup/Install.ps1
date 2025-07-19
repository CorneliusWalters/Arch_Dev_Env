# Install.ps1 - Main entry point for Arch Linux WSL setup

# --- START: PREREQUISITE CHECK ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Git is not installed or not in your PATH." -ForegroundColor Red
    Write-Host "Please install Git for Windows and try again: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}
# --- END: PREREQUISITE CHECK ---

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

# Import the module files. This loads the WslLogger class definition.
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\PowerShell\Logging.ps1"
. "$scriptPath\PowerShell\Test.ps1"
. "$scriptPath\PowerShell\Import-Distro.ps1"
. "$scriptPath\PowerShell\Export-Image.ps1"

# Create a new instance of our WslLogger class.
$logger = [WslLogger]::new("C:\wsl")

# --- MAIN EXECUTION ---
$logger.WriteHeader("Starting WSL Arch Linux Configuration for user '$wslUsername'")
$logger.WriteLog("INFO", "Log file created at: $($logger.LogFile)", "Gray")

if (-not (Test-WSLPrerequisites -Logger $logger -WslDistroName $wslDistroName)) {
    $logger.WriteLog("ERROR", "Prerequisite check failed. Exiting.", "Red")
    exit 1
}

if (-not (Import-ArchDistro -Logger $logger -WslDistroName $wslDistroName -WslUsername $wslUsername -DefaultTarballPath $cleanArchTarballDefaultPath)) {
    $logger.WriteLog("ERROR", "Failed to properly import/configure WSL distribution. Exiting.", "Red")
    exit 1
}

$logger.WriteHeader("Cloning Setup Scripts")
if (Test-Path $localClonePath) {
    $logger.WriteLog("INFO", "Setup directory already exists at '$localClonePath'. Removing for a clean clone.", "White")
    Remove-Item -Recurse -Force $localClonePath
}
$logger.WriteLog("INFO", "Cloning repository from $githubRepoUrl to $localClonePath...", "White")
git clone $githubRepoUrl $localClonePath
if ($LASTEXITCODE -ne 0) {
    $logger.WriteLog("ERROR", "Failed to clone the Git repository.", "Red")
    exit 1
}
$logger.WriteLog("SUCCESS", "Repository cloned successfully.", "Green")

$logger.WriteHeader("Creating WSL Configuration File")
$wslRepoPath = "/mnt/" + ($localClonePath -replace ':', '').Replace('\', '/')
$commandTemplate = "echo 'REPO_ROOT=`"{0}`"' | sudo tee /etc/arch-dev-env.conf"
$wslCommandForConfig = $commandTemplate -f $wslRepoPath
$logger.WriteLog("INFO", "Creating repo config file at /etc/arch-dev-env.conf inside WSL.", "Gray")
wsl -d $wslDistroName -u $wslUsername -e bash -c $wslCommandForConfig
if ($LASTEXITCODE -ne 0) {
    $logger.WriteLog("ERROR", "Failed to create /etc/arch-dev-env.conf inside WSL.", "Red")
    exit 1
}
$logger.WriteLog("SUCCESS", "WSL configuration file created.", "Green")

$logger.WriteHeader("Executing Main Setup Script inside WSL")
$env:WSLENV = "FORCE_OVERWRITE/u"
$env:FORCE_OVERWRITE = if ($ForceOverwrite) { "true" } else { "false" }
$wslScriptPath = $wslRepoPath + "/Setup/1_sys_init.sh"
$wslCommandForSetup = "chmod +x $wslScriptPath && $wslScriptPath"
$logger.WriteLog("INFO", "Executing in WSL: $wslCommandForSetup", "Gray")
wsl -d $wslDistroName -u $wslUsername -e bash -c $wslCommandForSetup
if ($LASTEXITCODE -ne 0) {
    $logger.WriteLog("ERROR", "The setup script inside WSL failed. Check the terminal output above for details.", "Red")
    exit 1
}
$logger.WriteLog("SUCCESS", "WSL setup script completed successfully.", "Green")

Export-WSLImage -Logger $logger -WslDistroName $wslDistroName -ExportPath $configuredArchTarballExportPath

$logger.WriteHeader("Setup Complete! Shutting down WSL to apply changes.")
$logger.WriteLog("INFO", "The script will now automatically run 'wsl --shutdown'.", "Yellow")
$logger.WriteLog("INFO", "After it finishes, you can open your new Arch terminal.", "Yellow")
Start-Sleep -Seconds 5
wsl --shutdown
