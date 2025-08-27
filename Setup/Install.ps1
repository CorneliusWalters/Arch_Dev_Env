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

# --- INTERACTIVE USERNAME PROMPT (Corrected Logic) ---
$wslUsernameInput = Read-Host -Prompt "Please enter your desired username for Arch Linux (default: '$wslUsernameDefault')"
$wslUsername = if ([string]::IsNullOrWhiteSpace($wslUsernameInput)) { $wslUsernameDefault } else { $wslUsernameInput }

$gitUserNameInput = Read-Host -Prompt "Enter your GitHub username (for commits and repo detection, default: '$gitUserNameDefault')"
$gitUserName = if ([string]::IsNullOrWhiteSpace($gitUserNameInput)) { $gitUserNameDefault } else { $gitUserNameInput }

$gitUserEmailInput = Read-Host -Prompt "Enter your Git email (for commits, default: '$gitUserEmailDefault')"
$gitUserEmail = if ([string]::IsNullOrWhiteSpace($gitUserEmailInput)) { $gitUserEmailDefault } else { $gitUserEmailInput }

$personalRepoUrl = $null # Initialize to null, we'll try to detect or ask

# Try to auto-detect the forked repository
Write-Host "`nAttempting to auto-detect your forked repository on GitHub..." -ForegroundColor Cyan
if (Get-Command gh -ErrorAction SilentlyContinue) {
  # Check if github-cli is installed
  $ghStatus = gh auth status --hostname github.com 2>&1
  if ($ghStatus -match 'Logged in as') {
    Write-Host "GitHub CLI detected and authenticated." -ForegroundColor DarkGreen
    $originalRepoOwner = (Split-Path -Parent $personalRepoUrlDefault).Replace("https://github.com/", "")
    $originalRepoName = (Split-Path $personalRepoUrlDefault -Leaf).Replace(".git", "")

    try {
      $userForksJson = gh repo list $gitUserName --source --fork --json name, url, parent 2>$null | ConvertFrom-Json
      $foundFork = $userForksJson | Where-Object { $_.parent.nameWithOwner -eq "$originalRepoOwner/$originalRepoName" }

      if ($foundFork) {
        $personalRepoUrl = $foundFork.url
        Write-Host "Auto-detected forked repository: $($personalRepoUrl)" -ForegroundColor Green
      }
      else {
        Write-Host "No fork of '$originalRepoOwner/$originalRepoName' found under '$gitUserName'." -ForegroundColor Yellow
      }
    }
    catch {
      Write-Host "WARNING: Failed to query GitHub for forks. Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }
  else {
    Write-Host "GitHub CLI detected but not authenticated. Run 'gh auth login' first." -ForegroundColor Yellow
  }
}
else {
  Write-Host "GitHub CLI ('gh' command) not found. Cannot auto-detect forks." -ForegroundColor Yellow
}

# If auto-detection failed, prompt the user manually
if ([string]::IsNullOrWhiteSpace($personalRepoUrl)) {
  $personalRepoUrlInput = Read-Host -Prompt "Enter your personal dotfiles GitHub repo URL (optional - default: '$personalRepoUrlDefault' or generated based on your GitHub username')"
  if ([string]::IsNullOrWhiteSpace($personalRepoUrlInput)) {
    # Fallback to default generated URL if manual input is also empty
    if ([string]::IsNullOrWhiteSpace($gitUserName)) {
      Write-Host "WARNING: Git username is empty. Cannot generate default personal repo URL, using hardcoded default." -ForegroundColor Yellow
      $personalRepoUrl = $personalRepoUrlDefault # Final fallback to hardcoded default
    }
    else {
      $personalRepoUrl = "https://github.com/$gitUserName/$originalRepoName.git" # Generated from user's GH name
    }
  }
  else {
    $personalRepoUrl = $personalRepoUrlInput
  }
}
Write-Host "`nUsing personal dotfiles repository: $($personalRepoUrl)" -ForegroundColor Green # Confirm final URL
# --- END INTERACTIVE USERNAME PROMPT ---

# Import modules and create the logger
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\PowerShell\Logging.ps1"
. "$scriptPath\PowerShell\Test.ps1"
. "$scriptPath\PowerShell\Utils.ps1" # Contains Set-NeutralDirectory and (no Add-VSCodeToPath now)
. "$scriptPath\PowerShell\Import-Distro.ps1"
. "$scriptPath\PowerShell\Export-Image.ps1"
$logger = [WslLogger]::new("C:\wsl")

try {
  # The repository root directory that will be cloned/deleted (e.g., C:\wsl\wsl_dev_setup)
  $repoPathToManage = Split-Path -Parent $PSScriptRoot
  # The current working directory of the PowerShell terminal
  $currentWorkingDir = (Get-Location).Path

  # If the current directory is inside (or equal to) the repo that needs to be managed (cloned/deleted)...
  if ($currentWorkingDir -like "$repoPathToManage*" -or $currentWorkingDir -eq $repoPathToManage) {
    Write-Host "Current directory ('$currentWorkingDir') is inside or equal to the target repository path ('$repoPathToManage'). Setting a neutral directory..." -ForegroundColor Yellow
    Set-NeutralDirectory # Call the parameter-less function
  }

  $logger.WritePhaseStatus("INIT", "STARTING", "WSL Arch Linux Configuration for user '$wslUsername'")
	  
  # Phase 1: Prerequisites and Import
  if (-not (Test-GitFunctionality -Logger $logger)) {
    # Call the new function
    throw "Git for Windows is not functional."
  }

  if (-not (Import-ArchDistro -Logger $logger -WslDistroName $wslDistroName -WslUsername $wslUsername -DefaultTarballPath $cleanArchTarballDefaultPath)) {
    throw "Distro import failed"
  }
  $logger.WritePhaseStatus("IMPORT", "SUCCESS", "Distro imported successfully")
	  
  # Phase 2: Repository Clone (This clones the setup repo itself)
  $logger.WritePhaseStatus("CLONE", "STARTING", "Cloning setup repository into Windows path...")
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
  $wslRepoPath = "/mnt/c/wsl/wsl_dev_setup" # Path to the cloned repo *inside* WSL
  $logger.WritePhaseStatus("CLONE", "SUCCESS", "Setup repository cloned to '$wslRepoPath'")
	  
  # Phase 3: Root Preparation (basic OS config, user creation, sudoers)
  $logger.WritePhaseStatus("ROOT_PREP", "STARTING", "Preparing pristine environment as root (user, sudo, basic packages)...")
  $prepCommand = "$wslRepoPath/Setup/lib/0_prepare_root.sh $wslUsername"
  if (-not (Invoke-WSLCommand -DistroName $wslDistroName -Username "root" -Command $prepCommand -Description "Root preparation" -Logger $logger)) {
    throw "Root preparation failed"
  }
  $logger.WritePhaseStatus("ROOT_PREP", "SUCCESS", "Root preparation completed")

  # Phase 4: Initial WSL Configuration ---
  # This sets the default user and enables systemd, which requires a WSL restart.
  if (-not (Set-WslConfDefaults -Logger $logger -DistroName $wslDistroName -Username $wslUsername -WslRepoPath $wslRepoPath)) {
    throw "Initial WSL configuration in /etc/wsl.conf failed."
  }
  $logger.WritePhaseStatus("WSL_CONF", "SUCCESS", "Initial /etc/wsl.conf set.")

  # Phase 5: WSL Restart to apply core WSL settings (e.g., /etc/wsl.conf changes)
  $logger.WritePhaseStatus("WSL_RESTART", "STARTING", "Applying initial WSL settings (terminating distro)...")
  wsl --terminate $wslDistroName
  if (-not (Wait-WSLShutdown -DistroName $wslDistroName -Logger $logger)) {
    throw "WSL shutdown timeout"
  }
  $logger.WritePhaseStatus("WSL_RESTART", "SUCCESS", "WSL restarted successfully")

  # Phase 6: Export REPO_ROOT to a /etc/ file for Bash scripts
  $logger.WritePhaseStatus("EXPORT_REPO_PATH", "STARTING", "Creating /etc/arch-dev-env.conf for REPO_ROOT export...")
  $configCommand = "echo 'REPO_ROOT=`"$wslRepoPath`"' | sudo tee /etc/arch-dev-env.conf > /dev/null"
  if (-not (Invoke-WSLCommand -DistroName $wslDistroName -Username $wslUsername -Command $configCommand -Description "Config file creation (REPO_ROOT)" -Logger $logger)) {
    throw "Config file creation failed (REPO_ROOT)"
  }
  $logger.WritePhaseStatus("EXPORT_REPO_PATH", "SUCCESS", "/etc/arch-dev-env.conf created with REPO_ROOT")

  # Phase 7: Final WSL shutdown for config application and user verification setup
  $logger.WritePhaseStatus("WSL_RESTART_FINAL", "STARTING", "Shutting down WSL to apply wsl.conf settings and prepare for user verification...")
  wsl --shutdown
  Start-Sleep -Seconds 5 # Give ample time for shutdown
  
  # -- Phase 8: User Verification ---
  $logger.WritePhaseStatus("USER_VERIFY", "STARTING", "Verifying user context and sudo permissions after wsl.conf changes...")
  $verifyUserCommand = "whoami && pwd && echo 'User verification complete'"
  if (-not (Invoke-WSLCommand -DistroName $wslDistroName -Username $wslUsername -Command $verifyUserCommand -Description "Verify user context" -Logger $logger)) {
    throw "User context verification failed. The default user might not be set correctly in /etc/wsl.conf."
  }
  $logger.WritePhaseStatus("USER_VERIFY", "SUCCESS", "User context verified. Running as '$wslUsername'.")

  # Phase 9: Debug commands (to confirm environment is ready)
  $logger.WritePhaseStatus("CONF_STATUS", "STARTING", "Running basic WSL functionality and repository access tests...")
  $confCommands = @(
    "whoami",
    "pwd", 
    "echo `$HOME",
    "test -d '$wslRepoPath' && echo 'REPO_DIR_EXISTS' || echo 'REPO_DIR_MISSING'",
    "test -f '$wslRepoPath/Setup/1_sys_init.sh' && echo 'SCRIPT_EXISTS' || echo 'SCRIPT_MISSING'",
    "ls -la '$wslRepoPath/Setup/' | head -5"
  )
  foreach ($cmd in $confCommands) {
    if (-not (Invoke-WSLCommand -DistroName $wslDistroName -Username $wslUsername -Command $cmd -Description "Debug command: $cmd" -Logger $logger)) {
      $logger.WriteLog("Conf_Status", "Debug command FAILED: $cmd", "Red")
    }
  }
  $logger.WritePhaseStatus("CONF_STATUS", "SUCCESS", "Basic WSL functionality tests completed.")

  # Phase 10: Main Setup (using the robust WSLProcessCapture for the long-running Bash script)
  $logger.WritePhaseStatus("MAIN_SETUP", "STARTING", "Executing main setup script via repository wrapper...")

  # Exporting git and personal repo variables to the WSL environment for the wrapper script.
  $environmentVars = "export GIT_USER_NAME='$gitUserName' && export GIT_USER_EMAIL='$gitUserEmail'"
  if (-not [string]::IsNullOrWhiteSpace($personalRepoUrl)) {
    $environmentVars += " && export PERSONAL_REPO_URL='$personalRepoUrl'"
  }
  
  $wrapperPath = "$wslRepoPath/Setup/lib/99_wrapper.sh"
  $fullCommand = "$environmentVars && bash '$wrapperPath'"
  
  if (-not $wslCapture.ExecuteCommand($fullCommand, "Execute main setup script")) {
    throw "Main setup script execution failed"
  }
  $logger.WritePhaseStatus("MAIN_SETUP", "SUCCESS", "Main setup completed.")
	
  # Phase 11: Export Configured Image (optional)
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