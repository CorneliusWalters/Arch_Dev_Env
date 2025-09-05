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
