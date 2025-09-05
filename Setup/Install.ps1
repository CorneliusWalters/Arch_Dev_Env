# Install.ps1 - Main entry point for Arch Linux WSL setup

$ErrorActionPreference = "Stop" # Set to Stop for better error propagation

# --- CONFIGURATION ---
$wslDistroName = "Arch"
$cleanArchTarballDefaultPath = "C:\wsl\tmp\arch_clean.tar"
$configuredArchTarballExportPath = "C:\wsl\tmp\arch_configured.tar"
$ForceOverwrite = $true # Hardcoded true for setup runs to ensure a clean slate

# --- Default Values (Used if user input is empty) ---
$wslUsernameDefault = "chw"
$gitUserNameDefault = "CorneliusWalters"
$gitUserEmailDefault = "seven.nomad@gmail.com"
$personalRepoUrlDefault = "https://github.com/CorneliusWalters/Arch_Dev_Env.git" # Your upstream repo
$httpProxyDefault = "" # e.g., "http://your.proxy.com:8080"
$httpsProxyDefault = "" # e.g., "http://your.proxy.com:8080"

# Import modules and create the logger
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\PowerShell\Logging.ps1"
. "$scriptPath\PowerShell\Test.ps1"
. "$scriptPath\PowerShell\Utils.ps1"
. "$scriptPath\PowerShell\Import-Distro.ps1"
. "$scriptPath\PowerShell\Export-Image.ps1"
$logger = [WslLogger]::new("C:\wsl")


# --- Call the consolidated user configuration function ---
$userConfig = Get-InstallationUserConfig `
  -WslUsernameDefault $wslUsernameDefault `
  -GitUserNameDefault $gitUserNameDefault `
  -GitUserEmailDefault $gitUserEmailDefault `
  -PersonalRepoUrlDefault $personalRepoUrlDefault `
  -HttpProxyDefault $httpProxyDefault `
  -HttpsProxyDefault $httpsProxyDefault

# Assign results to the main script variables
$wslUsername = $userConfig.WslUsername
$gitUserName = $userConfig.GitUserName
$gitUserEmail = $userConfig.GitUserEmail
$personalRepoUrl = $userConfig.PersonalRepoUrl
$sshKeyReady = $userConfig.SshKeyReady
$httpProxy = $userConfig.HttpProxy
$httpsProxy = $userConfig.HttpsProxy

$scriptWindowsRepoRoot = (Convert-Path $PSScriptRoot | Get-Item).Parent.FullName
$wslRepoPath = $scriptWindowsRepoRoot.Replace('C:\', '/mnt/c/').Replace('\', '/')

try {
  # --- Step 1: Ensure execution environment is clean ---
  $repoPathToManage = Split-Path -Parent $PSScriptRoot
  $currentWorkingDir = (Get-Location).Path

  if ($currentWorkingDir -like "$repoPathToManage*" -or $currentWorkingDir -eq $repoPathToManage) {
    Write-Host "Current directory ('$currentWorkingDir') is inside or equal to the target repository path ('$repoPathToManage'). Setting a neutral directory..." -ForegroundColor Yellow
    Set-NeutralDirectory
  }

  $logger.WritePhaseStatus("INIT", "STARTING", "WSL Arch Linux Configuration for user '$wslUsername'")
	  
  # --- Step 2: Prerequisites Validation ---
  # 2a. Check fundamental WSL and local Git command prerequisites.
  if (-not (Test-WSLPrerequisites -Logger $logger -WslDistroName $wslDistroName)) {
    throw "Prerequisites check failed."
  }
  $logger.WritePhaseStatus("PREREQ", "SUCCESS", "WSL prerequisites validated.")
  
  # 2b. Configure Git for Windows (safe.directory, global user, protocol, proxy).
  if (-not (Set-GitGlobalConfig -Logger $logger `
        -GitUserName $gitUserName `
        -GitUserEmail $gitUserEmail `
        -SshKeyReady $sshKeyReady `
        -HttpProxy $httpProxy `
        -HttpsProxy $httpsProxy `
        -PSScriptRootContext $PSScriptRoot)) {
    # Pass $PSScriptRoot for path derivation
    throw "Git for Windows global configuration failed."
  }
  $logger.WritePhaseStatus("GIT_CONFIG_COMPLETE", "SUCCESS", "Git for Windows global configuration applied.")

  # 2c. Final check of Git functionality (after all configurations are applied).
  if (-not (Test-GitFunctionality -Logger $logger)) {
    throw "Git for Windows is not functional (post-configuration check failed)."
  }
  $logger.WritePhaseStatus("GIT_CHECK_COMPLETE", "SUCCESS", "Git for Windows functionality verified (post-configuration).")

  # --- Step 3: Distro Import ---
  if (-not (Import-ArchDistro -Logger $logger -WslDistroName $wslDistroName -WslUsername $wslUsername -DefaultTarballPath $cleanArchTarballDefaultPath)) {
    throw "Distro import failed."
  }
  $logger.WritePhaseStatus("IMPORT", "SUCCESS", "Distro imported successfully.")
	  
  # --- Step 4: Clone the Setup Repository ---
  # SourceRepoUrl is always https://github.com/CorneliusWalters/Arch_Dev_Env.git for this specific clone.
  if (-not (Clone-SetupRepository -Logger $logger `
        -GitCloneTarget "C:\wsl\wsl_dev_setup" `
        -SourceRepoUrl "https://github.com/CorneliusWalters/Arch_Dev_Env.git" `
        -ForceOverwrite $ForceOverwrite)) {
    throw "Cloning of setup repository failed."
  }
  $logger.WritePhaseStatus("CLONE_SETUP_REPO", "SUCCESS", "Setup repository cloned to '$wslRepoPath'")
	  
  # --- Step 5: Root Preparation (basic OS config, user creation, sudoers) ---
  $logger.WritePhaseStatus("ROOT_PREP", "STARTING", "Preparing pristine environment as root (user, sudo, basic packages)...")
  $prepCommand = "$wslRepoPath/Setup/lib/0_prepare_root.sh $wslUsername"
  if (-not (Invoke-WSLCommand -DistroName $wslDistroName -Username "root" -Command $prepCommand -Description "Root preparation" -Logger $logger)) {
    throw "Root preparation failed"
  }
  $logger.WritePhaseStatus("ROOT_PREP", "SUCCESS", "Root preparation completed")

  # --- Step 6: Initial WSL Configuration (sets default user, systemd in /etc/wsl.conf) ---
  # Initialize WSL capture for the main setup execution
  $wslCapture = [WSLProcessCapture]::new($logger, $wslDistroName, $wslUsername)
  
  if (-not (Set-WslConfDefaults -Logger $logger -DistroName $wslDistroName -Username $wslUsername -WslRepoPath $wslRepoPath)) {
    throw "Initial WSL configuration in /etc/wsl.conf failed."
  }
  $logger.WritePhaseStatus("WSL_CONF", "SUCCESS", "Initial /etc/wsl.conf set.")
	  
  # --- Step 7: WSL Restart (applies /etc/wsl.conf changes) ---
  $logger.WritePhaseStatus("WSL_RESTART_CONF", "STARTING", "Applying /etc/wsl.conf settings (terminating distro)...")
  wsl --terminate $wslDistroName
  if (-not (Wait-WSLShutdown -DistroName $wslDistroName -Logger $logger)) {
    throw "WSL shutdown timeout during /etc/wsl.conf application."
  }
  $logger.WritePhaseStatus("WSL_RESTART_CONF", "SUCCESS", "WSL restarted with new /etc/wsl.conf settings.")

  # --- Step 8: Export REPO_ROOT to a /etc/ file for Bash scripts ---
  $logger.WritePhaseStatus("EXPORT_REPO_PATH", "STARTING", "Creating /etc/arch-dev-env.conf for REPO_ROOT export...")
  $configCommand = "echo 'REPO_ROOT=`"$wslRepoPath`"' | sudo tee /etc/arch-dev-env.conf > /dev/null"
  if (-not (Invoke-WSLCommand -DistroName $wslDistroName -Username $wslUsername -Command $configCommand -Description "Config file creation (REPO_ROOT)" -Logger $logger)) {
    throw "Config file creation failed (REPO_ROOT)"
  }
  $logger.WritePhaseStatus("EXPORT_REPO_PATH", "SUCCESS", "/etc/arch-dev-env.conf created with REPO_ROOT")

  # --- Step 9: Final WSL shutdown for config application and user verification setup ---
  $logger.WritePhaseStatus("WSL_RESTART_FINAL", "STARTING", "Shutting down WSL for final config application and user verification prep...")
  wsl --shutdown
  Start-Sleep -Seconds 5 # Give ample time for shutdown
  
  # --- Step 10: User Verification ---
  if (-not (Test-WslBasicFunctionality -Logger $logger -DistroName $wslDistroName -Username $wslUsername -WslRepoPath $wslRepoPath)) {
    throw "User context verification or basic WSL functionality failed."
  }
  $logger.WritePhaseStatus("USER_VERIFY_COMPLETE", "SUCCESS", "User context and basic WSL functionality verified.")

  # --- Step 11: Main Setup (using the robust WSLProcessCapture for the long-running Bash script) ---
  $logger.WritePhaseStatus("MAIN_SETUP", "STARTING", "Executing main setup script via repository wrapper...")

  # Exporting git and personal repo variables to the WSL environment for the wrapper script.
  $environmentVars = "export GIT_USER_NAME='$gitUserName' && export GIT_USER_EMAIL='$gitUserEmail'"
  if (-not [string]::IsNullOrWhiteSpace($personalRepoUrl)) {
    $environmentVars += " && export PERSONAL_REPO_URL='$personalRepoUrl'"
  }
  if (-not [string]::IsNullOrWhiteSpace($httpProxy)) {
    $environmentVars += " && export HTTP_PROXY='$httpProxy'"
  }
  if (-not [string]::IsNullOrWhiteSpace($httpsProxy)) {
    $environmentVars += " && export HTTPS_PROXY='$httpsProxy'"
  }
  
  $wrapperPath = "$wslRepoPath/Setup/lib/99_wrapper.sh"
  $fullCommand = "$environmentVars && bash '$wrapperPath'"
  
  if (-not $wslCapture.ExecuteCommand($fullCommand, "Execute main setup script")) {
    throw "Main setup script execution failed"
  }
  $logger.WritePhaseStatus("MAIN_SETUP", "SUCCESS", "Main setup completed.")
	
  # --- Step 12: Export Configured Image (optional) ---
  Export-WSLImage -Logger $logger -WslDistroName $wslDistroName -ExportPath $configuredArchTarballExportPath
	
  $logger.WritePhaseStatus("COMPLETE", "SUCCESS", "Setup completed successfully.")
  $logger.WriteHeader("Setup Complete! Shutting down WSL to apply changes.")
  Start-Sleep -Seconds 10
  wsl --shutdown # Final shutdown
	    
}
catch {
  $logger.WritePhaseStatus("FATAL", "ERROR", "Script failed: $($_.Exception.Message)")
  $logger.WriteRecoveryInfo($wslDistroName, $wslUsername, $wslRepoPath)
  exit 1
}