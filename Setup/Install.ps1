# Install.ps1 - Main entry point for Arch Linux WSL setup

$ErrorActionPreference = "Continue"

# --- CONFIGURATION ---
$wslDistroName = "Arch"
$cleanArchTarballDefaultPath = "C:\wsl\tmp\arch_clean.tar"
$configuredArchTarballExportPath = "C:\wsl\tmp\arch_configured.tar"
$ForceOverwrite = $true

# --- INTERACTIVE USERNAME PROMPT ---
$wslUsername = Read-Host -Prompt "Please enter your desired username for Arch Linux (e.g., 'UNAME')"
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

  $logger.WritePhaseStatus("USER_CONFIG", "STARTING", "Configuring default WSL user")

  # Create the wsl.conf file as root
  $wslCaptureRoot = [WSLProcessCapture]::new($logger, $wslDistroName, "root")
  $userConfigCommand = @"
echo '[user]' > /etc/wsl.conf && echo 'default=$wslUsername' >> /etc/wsl.conf && cat /etc/wsl.conf
"@

  if (-not $wslCaptureRoot.ExecuteCommand($userConfigCommand, "Set WSL user config")) {
    throw "Failed to set WSL user config"
  }

  # FULL WSL shutdown (not just terminate)
  $logger.WritePhaseStatus("USER_CONFIG", "STARTING", "Shutting down WSL to apply user settings")
  wsl --shutdown
  Start-Sleep -Seconds 5

  # Verify the user change worked
  $logger.WritePhaseStatus("USER_CONFIG", "STARTING", "Verifying user context")
  $verifyUserCommand = "whoami && pwd && echo 'User verification complete'"
  $wslCapture = [WSLProcessCapture]::new($logger, $wslDistroName, $wslUsername)
  if (-not $wslCapture.ExecuteCommand($verifyUserCommand, "Verify user context")) {
    throw "User context verification failed - still running as wrong user"
  }			
  ########################################################################################			
  ########################################################################################			
  $logger.WritePhaseStatus("DEBUG", "STARTING", "Testing WSL basic functionality")

  $debugCommands = @(
    "whoami",
    "pwd", 
    "echo `$HOME",
    "test -d '$wslRepoPath' && echo 'REPO_DIR_EXISTS' || echo 'REPO_DIR_MISSING'",
    "test -f '$wslRepoPath/Setup/1_sys_init.sh' && echo 'SCRIPT_EXISTS' || echo 'SCRIPT_MISSING'",
    "ls -la '$wslRepoPath/Setup/' | head -5"
  )

  foreach ($cmd in $debugCommands) {
    $result = wsl -d $wslDistroName -u $wslUsername bash -c $cmd
    $logger.WriteLog("DEBUG", "Command: $cmd", "Gray")
    $logger.WriteLog("DEBUG", "Result: $result", "Gray")
  }
  #  ########################################################################################			
  #  ########################################################################################			
  # Phase 6: Main Setup 
  $logger.WritePhaseStatus("MAIN_SETUP", "STARTING", "Executing main setup script")

  # First, verify the script exists
  $testScriptCommand = "test -f '$wslRepoPath/Setup/1_sys_init.sh' && echo 'SCRIPT_EXISTS' || echo 'SCRIPT_MISSING'"
  if (-not (Invoke-WSLCommand -DistroName $wslDistroName -Username $wslUsername -Command $testScriptCommand -Description "Verify script exists" -Logger $logger)) {
    throw "Setup script verification failed"
  }

  # Create a wrapper script for better control
  $wrapperScriptCommand = @"
cat > /tmp/setup_runner.sh << 'WRAPPER_EOF'
#!/bin/bash
set -e
export FORCE_OVERWRITE='true'
export SYSTEM_LOCALE='en_US.UTF-8'
export POWERSHELL_EXECUTION='true'

echo "=== WSL Setup Starting at \$(date) ==="
echo "Working directory: \$(pwd)"
echo "User: \$(whoami)"
echo "Repository path: $wslRepoPath"

cd '$wslRepoPath' || { echo "ERROR: Cannot cd to $wslRepoPath"; exit 1; }
echo "Changed to: \$(pwd)"

if [ ! -f Setup/1_sys_init.sh ]; then
    echo "ERROR: Setup/1_sys_init.sh not found"
    exit 1
fi

echo "Starting 1_sys_init.sh..."
exec bash Setup/1_sys_init.sh
WRAPPER_EOF
chmod +x /tmp/setup_runner.sh
"@

  if (-not (Invoke-WSLCommand -DistroName $wslDistroName -Username $wslUsername -Command $wrapperScriptCommand -Description "Create wrapper script" -Logger $logger)) {
    throw "Failed to create wrapper script"
  }

  # Execute the wrapper script with real-time output
  $logger.WriteLog("INFO", "Executing main setup script...", "Cyan")
  $wslArgs = @("-d", $wslDistroName, "-u", $wslUsername, "/tmp/setup_runner.sh")

  try {
    $process = Start-Process -FilePath "wsl" -ArgumentList $wslArgs -NoNewWindow -Wait -PassThru
    
    if ($process.ExitCode -eq 0) {
      $logger.WritePhaseStatus("MAIN_SETUP", "SUCCESS", "Main setup completed")
    }
    else {
      throw "Setup script failed with exit code: $($process.ExitCode)"
    }
  }
  catch {
    $logger.WritePhaseStatus("MAIN_SETUP", "ERROR", "Setup execution failed: $($_.Exception.Message)")
    throw
  }	
  # Phase 7: Export (optional)
  Export-WSLImage -Logger $logger -WslDistroName $wslDistroName -ExportPath $configuredArchTarballExportPath
	
  $logger.WritePhaseStatus("COMPLETE", "SUCCESS", "Setup completed successfully")
  $logger.WriteHeader("Setup Complete! Shutting down WSL to apply changes.")
  Start-Sleep -Seconds 5
  wsl --shutdown
	    
}
catch {
  $logger.WritePhaseStatus("FATAL", "ERROR", "Script failed: $($_.Exception.Message)")
  $logger.WriteRecoveryInfo($wslDistroName, $wslUsername, $wslRepoPath)
  exit 1
}