# Install.ps1 - Main entry point for Arch Linux WSL setup

$ErrorActionPreference = "Stop"

# --- CONFIGURATION ---
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
    $logger.WriteHeader("Starting WSL Arch Linux Configuration for user '$wslUsername'")
    Test-WSLPrerequisites -Logger $logger -WslDistroName $wslDistroName
    Import-ArchDistro -Logger $logger -WslDistroName $wslDistroName -WslUsername $wslUsername -DefaultTarballPath $cleanArchTarballDefaultPath

    #NEW: CLONE REPOSITORY ---
    $logger.WriteHeader("Cloning Repository")
    $gitCloneTarget = "C:\wsl\wsl-dev-setup"
    if ($ForceOverwrite -or -not (Test-Path $gitCloneTarget)) {
        $logger.WriteLog("INFO", "Cloning repository to $gitCloneTarget", "Cyan")
        if (Test-Path $gitCloneTarget) { Remove-Item -Recurse -Force $gitCloneTarget }
        git clone "https://github.com/CorneliusWalters/Arch_Dev_Env.git" $gitCloneTarget
    }
    $wslRepoPath = "/mnt/c/wsl/wsl-dev-setup"

    # --- PHASE 1: PREPARE ENVIRONMENT (as root) ---
    $logger.WriteHeader("Preparing pristine environment as root...")
    $prepScriptPath = "$wslRepoPath/Setup/lib/0_prepare_root.sh"  # Note capital S
    $prepProcess = Start-Process wsl -ArgumentList "-d $wslDistroName -u root -e bash $prepScriptPath $wslUsername" -Wait -PassThru -NoNewWindow
    if ($prepProcess.ExitCode -ne 0) {
        throw "The root preparation script failed with exit code $($prepProcess.ExitCode)."
    }

    # --- START: NEW COMMUNICATIVE RESTART BLOCK ---
    $logger.WriteHeader("Applying critical WSL settings...")
    $logger.WriteLog("INFO", "Shutting down '$wslDistroName' to apply new mount options from wsl.conf...", "Yellow")
    wsl --terminate $wslDistroName

    $timeoutSeconds = 30
    $elapsedSeconds = 0
    $logger.WriteLog("INFO", "Verifying that the WSL instance has stopped. This may take a few moments.", "Cyan")
    Write-Host "Verifying shutdown" -NoNewline
    
    while ($true) {
        $distroStatus = wsl -l -v | Where-Object { $_ -match $wslDistroName }
        if (-not ($distroStatus -match "Running")) {
            # The distro is stopped, break the loop.
            break
        }

        if ($elapsedSeconds -ge $timeoutSeconds) {
            throw "Timed out waiting for '$wslDistroName' to shut down."
        }
        
        Write-Host -NoNewline "."
        Start-Sleep -Seconds 2
        $elapsedSeconds += 2
    }
    
    Write-Host "" # Adds a newline after the dots.
    $logger.WriteLog("SUCCESS", "WSL instance terminated successfully. Settings applied. Continuing installation...", "Green")
    # --- END: NEW COMMUNICATIVE RESTART BLOCK ---

    # --- PHASE 2: CREATE CONFIG FILE ---
    $logger.WriteHeader("Creating WSL Configuration File")
    $configContent = "REPO_ROOT=`"$wslRepoPath`""
    $wslCommandForConfig = "echo '$configContent' | sudo tee /etc/arch-dev-env.conf > /dev/null"
    wsl -d $wslDistroName -u $wslUsername -e bash -c $wslCommandForConfig
    $logger.WriteLog("SUCCESS", "WSL configuration file created.", "Green")

    # --- PHASE 3: MAIN SETUP ---
    $logger.WriteHeader("Executing Main Setup Script inside WSL as '$wslUsername'")
    $env:WSLENV = "FORCE_OVERWRITE/u"
    $env:FORCE_OVERWRITE = if ($ForceOverwrite) { "true" } else { "false" }
    $wslScriptPath = "$wslRepoPath/Setup/1_sys_init.sh"  # Note capital S
    $wslCommandForSetup = "export FORCE_OVERWRITE='$($env:FORCE_OVERWRITE)' && chmod +x $wslScriptPath && $wslScriptPath"
    $setupProcess = Start-Process wsl -ArgumentList "-d $wslDistroName -u $wslUsername -e bash -c `"$wslCommandForSetup`"" -Wait -PassThru -NoNewWindow
    if ($setupProcess.ExitCode -ne 0) {
        throw "The main setup script failed with exit code $($setupProcess.ExitCode)."
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