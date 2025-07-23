# Install.ps1 - Main entry point for Arch Linux WSL setup

$ErrorActionPreference = "Continue"

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
. "$scriptPath\PowerShell\Utils.ps1"
. "$scriptPath\PowerShell\Import-Distro.ps1"
. "$scriptPath\PowerShell\Export-Image.ps1"
$logger = [WslLogger]::new("C:\wsl")


	try {
	    $logger.WritePhaseStatus("INIT", "STARTING", "WSL Arch Linux Configuration for user '$wslUsername'")
	    
	    # Phase 1: Prerequisites and Import
	    if (-not (Test-WSLPrerequisites -Logger $logger -WslDistroName $wslDistroName)) {
	        throw "Prerequisites check failed"
	    }
	    $logger.WritePhaseStatus("PREREQ", "SUCCESS", "Prerequisites validated")
	    
	    if (-not (Import-ArchDistro -Logger $logger -WslDistroName $wslDistroName -WslUsername $wslUsername -DefaultTarballPath $cleanArchTarballDefaultPath)) {
	        throw "Distro import failed"
	    }
	    $logger.WritePhaseStatus("IMPORT", "SUCCESS", "Distro imported successfully")
	    
	    # Phase 2: Repository Clone
	    $logger.WritePhaseStatus("CLONE", "STARTING", "Cloning repository")
	    $gitCloneTarget = "C:\wsl\wsl_dev_setup"
	    if ($ForceOverwrite -or -not (Test-Path $gitCloneTarget)) {
	        if (Test-Path $gitCloneTarget) { 
	            Remove-Item -Recurse -Force $gitCloneTarget 
	        }
	        $result = git clone "https://github.com/CorneliusWalters/Arch_Dev_Env.git" $gitCloneTarget 2>&1
	        if ($LASTEXITCODE -ne 0) {
	            throw "Git clone failed: $result"
	        }
	    }
	    $wslRepoPath = "/mnt/c/wsl/wsl_dev_setup"
	    $logger.WritePhaseStatus("CLONE", "SUCCESS", "Repository cloned")
	    
	    # Phase 3: Root Preparation 
	    $logger.WritePhaseStatus("ROOT_PREP", "STARTING", "Preparing pristine environment as root")
	    $prepCommand = "$wslRepoPath/Setup/lib/0_prepare_root.sh $wslUsername"
	    if (-not (Invoke-WSLCommand -DistroName $wslDistroName -Username "root" -Command $prepCommand -Description "Root preparation" -Logger $logger)) {
	        throw "Root preparation failed"
	    }
	    $logger.WritePhaseStatus("ROOT_PREP", "SUCCESS", "Root preparation completed")
	    
	    # Phase 4: WSL Restart(using new reliable method)
	    $logger.WritePhaseStatus("WSL_RESTART", "STARTING", "Applying WSL settings")
	    wsl --terminate $wslDistroName
	    if (-not (Wait-WSLShutdown -DistroName $wslDistroName -Logger $logger)) {
	        throw "WSL shutdown timeout"
	    }
	    $logger.WritePhaseStatus("WSL_RESTART", "SUCCESS", "WSL restarted successfully")
	    
	    # Phase 5: Config File Creation 
	    $logger.WritePhaseStatus("CONFIG", "STARTING", "Creating WSL configuration file")
	    $configCommand = "echo 'REPO_ROOT=`"$wslRepoPath`"' | sudo tee /etc/arch-dev-env.conf > /dev/null"
	    if (-not (Invoke-WSLCommand -DistroName $wslDistroName -Username $wslUsername -Command $configCommand -Description "Config file creation" -Logger $logger)) {
	        throw "Config file creation failed"
	    }
	    $logger.WritePhaseStatus("CONFIG", "SUCCESS", "Config file created")
	    
	    # Phase 6: Main Setup 
	    $logger.WritePhaseStatus("MAIN_SETUP", "STARTING", "Executing main setup script")
	    $setupCommand = "export FORCE_OVERWRITE='true' && export EXISTING_LOG_DIR='$($logger.WslLogDir)' && cd '$wslRepoPath' &&  bash Setup/1_sys_init.sh"
	    if (-not (Invoke-WSLCommand -DistroName $wslDistroName -Username $wslUsername -Command $setupCommand -Description "Main setup script" -Logger $logger)) {
	        throw "Main setup script failed"
	    }
	    $logger.WritePhaseStatus("MAIN_SETUP", "SUCCESS", "Main setup completed")
	    
	    # Phase 7: Export (optional)
	    Export-WSLImage -Logger $logger -WslDistroName $wslDistroName -ExportPath $configuredArchTarballExportPath
	    
	    $logger.WritePhaseStatus("COMPLETE", "SUCCESS", "Setup completed successfully")
	    $logger.WriteHeader("Setup Complete! Shutting down WSL to apply changes.")
	    Start-Sleep -Seconds 5
	    wsl --shutdown
	    
	} catch {
	    $logger.WritePhaseStatus("FATAL", "ERROR", "Script failed: $($_.Exception.Message)")
	    $logger.WriteRecoveryInfo($wslDistroName, $wslUsername, $wslRepoPath)
	    exit 1
	}