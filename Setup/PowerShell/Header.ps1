# --- CONFIGURATION DEFAULTS ---
# This file should only contain static default values.

$wslDistroName = "Arch"
$cleanArchTarballDefaultPath = "C:\wsl\tmp\arch_clean.tar"
$configuredArchTarballExportPath = "C:\wsl\tmp\arch_configured.tar"
$ForceOverwrite = $true # Hardcoded true for setup runs to ensure a clean slate

# --- Default User Input Values ---
$wslUsernameDefault = "chw"
$gitUserNameDefault = "CorneliusWalters"
$gitUserEmailDefault = "seven.nomad@gmail.com"
$personalRepoUrlDefault = "https://github.com/CorneliusWalters/Arch_Dev_Env.git" # Your upstream repo
$httpProxyDefault = "" # e.g., "http://your.proxy.com:8080"
$httpsProxyDefault = "" # e.g., "http://your.proxy.com:8080"