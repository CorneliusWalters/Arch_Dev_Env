# install.ps1 - Bootstrapper for configuring an existing WSL Arch Linux instance.

# --- CONFIGURATION: EDIT THESE VARIABLES ---
$githubRepoUrl = "https://github.com/CorneliusWalters/Arch_Dev_Env.git" 
#$localClonePath = "C:\wsl-dev-setup"                               # <-- Optional: Change clone location
$wslDistroName = "Arch"                                            # <-- Your WSL distribution name
$wslUsername = "CHW"                                               # <-- VERY IMPORTANT: EDIT THIS to your default WSL username
# -------------------------------------------

# --- SCRIPT LOGIC ---
function Write-Header {
    param([string]$Message)
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "================================================================="
}

Write-Header "Starting WSL Arch Linux Configuration"

# 1. Prerequisite Checks
Write-Host "Checking for prerequisites (git, wsl)..."
$gitExists = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitExists) {
    Write-Host "ERROR: Git is not installed or not in your PATH." -ForegroundColor Red
    Write-Host "Please install Git for Windows and try again: https://git-scm.com/download/win"
    exit 1
}

$wslDistro = wsl -l -v | Select-String $wslDistroName
if (-not $wslDistro) {
    Write-Host "ERROR: WSL distribution '$wslDistroName' not found." -ForegroundColor Red
    Write-Host "Please run 'wsl --install archlinux' first and complete the initial user setup."
    exit 1
}
Write-Host "Prerequisites found." -ForegroundColor Green

# 2. Clone the Git Repository
Write-Header "Cloning Setup Scripts"
if (Test-Path $localClonePath) {
    Write-Host "Setup directory already exists at '$localClonePath'. Removing for a clean clone."
    Remove-Item -Recurse -Force $localClonePath
}
Write-Host "Cloning repository from $githubRepoUrl to $localClonePath..."
git clone $githubRepoUrl $localClonePath
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to clone the Git repository." -ForegroundColor Red
    exit 1
}
Write-Host "Repository cloned successfully." -ForegroundColor Green

# 3. Execute the Main Setup Script inside WSL
Write-Header "Executing Main Setup Script inside WSL"
Write-Host "This will run '1_sys_init.sh' as user '$wslUsername' in the '$wslDistroName' distro."
Write-Host "You will see output from the script and may be prompted for your sudo password."

# Convert Windows path to WSL path
$wslScriptPath = "/mnt/" + ($localClonePath -replace ':', '').Replace('\', '/') + "/1_sys_init.sh"

# The command to run inside WSL. It makes the script executable, then runs it.
$wslCommand = "chmod +x $wslScriptPath && $wslScriptPath"

# Execute the command
wsl -d $wslDistroName -u $wslUsername -e bash -c $wslCommand

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: The setup script inside WSL failed. Check the terminal output above for details." -ForegroundColor Red
    exit 1
}

Write-Header "Setup Complete!"
Write-Host "Please close this terminal and open a new Arch WSL terminal." -ForegroundColor Green
Write-Host "All changes should be applied."