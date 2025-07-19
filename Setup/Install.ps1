# Install.ps1 - Main entry point for Arch Linux WSL setup

$ErrorActionPreference = "Stop"

# --- PREREQUISITE CHECK ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Git is not installed..." -ForegroundColor Red; exit 1
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
    Write-Host "ERROR: Username cannot be empty." -ForegroundColor Red; exit 1
}

# Import modules and create the logger
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\PowerShell\Logging.ps1"
. "$scriptPath\PowerShell\Test.ps1"
. "$scriptPath\PowerShell\Import-Distro.ps1"
. "$scriptPath\PowerShell\Export-Image.ps1"
$logger = [WslLogger]::new("C:\wsl")

try {
    # Write the log header
    $logger.WriteLog("HEADER", "=== PowerShell Installation Log Started at $(Get-Date) ===", "Gray")
    $logger.WriteLog("HEADER", "User: $env:USERNAME", "Gray")

    $logger.WriteHeader("Starting WSL Arch Linux Configuration for user '$wslUsername'")
    Test-WSLPrerequisites -Logger $logger -WslDistroName $wslDistroName
    Import-ArchDistro -Logger $logger -WslDistroName $wslDistroName -WslUsername $wslUsername -DefaultTarballPath $cleanArchTarballDefaultPath

    $logger.WriteHeader("Creating user '$wslUsername' inside WSL")
    $createUserCommand = "useradd -m -G wheel -s /bin/bash $wslUsername && echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel"
    wsl -d $wslDistroName -u root -e bash -c $createUserCommand
    $logger.WriteLog("SUCCESS", "User '$wslUsername' created and granted sudo privileges.", "Green")

    $logger.WriteHeader("Cloning Setup Scripts")
    if (Test-Path $localClonePath) { Remove-Item -Recurse -Force $localClonePath }
    git clone $githubRepoUrl $localClonePath
    $logger.WriteLog("SUCCESS", "Repository cloned successfully.", "Green")

    $logger.WriteHeader("Creating WSL Configuration File")
    $wslRepoPath = "/mnt/" + ($localClonePath -replace ':', '').Replace('\', '/')
    $wslCommandForConfig = "echo 'REPO_ROOT=`"$wslRepoPath`"' | sudo tee /etc/arch-dev-env.conf"
    wsl -d $wslDistroName -u $wslUsername -e bash -c $wslCommandForConfig
    $logger.WriteLog("SUCCESS", "WSL configuration file created.", "Green")

    # --- PHASE 2 - MAIN SETUP (with live output) ---
    $logger.WriteHeader("Executing Main Setup Script inside WSL as '$wslUsername'")
    $env:WSLENV = "FORCE_OVERWRITE/u"
    $env:FORCE_OVERWRITE = if ($ForceOverwrite) { "true" } else { "false" }
    $wslScriptPath = $wslRepoPath + "/Setup/1_sys_init.sh"
    $wslCommandForSetup = "chmod +x $wslScriptPath && $wslScriptPath"
    
    $logger.WriteLog("INFO", "Starting setup inside WSL. You will now see the live output from the script.", "Cyan")
    
    # This new block runs the command and streams its output to this window.
    $process = Start-Process wsl -ArgumentList "-d $wslDistroName -u $wslUsername -e bash -c $wslCommandForSetup" -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        throw "The setup script inside WSL failed with exit code $($process.ExitCode)."
    }

    $logger.WriteLog("SUCCESS", "WSL setup script completed successfully.", "Green")

    Export-WSLImage -Logger $logger -WslDistroName $wslDistroName -ExportPath $configuredArchTarballExportPath

    $logger.WriteHeader("Setup Complete! Shutting down WSL to apply changes.")
    Start-Sleep -Seconds 5
    wsl --shutdown

} catch {
    $logger.WriteLog("FATAL", "The script encountered a critical error: $($_.Exception.Message)", "Red")
    exit 1
}
