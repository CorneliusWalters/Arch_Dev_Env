function Test-WSLPrerequisites {
    param (
        [PSCustomObject]$Logger,
        [string]$WslDistroName
    )
    
    $Logger.WriteLog("INFO", "Checking WSL version...", "Cyan")
    $wslVersionInfo = wsl --version | Select-String "WSL version:"
    if ($wslVersionInfo -match "WSL version: (\d+\.\d+\.\d+\.\d+)") {
        $wslVersion = $matches[1]
        $Logger.WriteLog("SUCCESS", "WSL Version: $wslVersion", "Green")
    } else {
        $Logger.WriteLog("WARNING", "Could not determine WSL version. Assuming modern WSL.", "Yellow")
    }
    
    $Logger.WriteLog("INFO", "Checking for prerequisites (git)...", "White")
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $Logger.WriteLog("ERROR", "Git is not installed or not in your PATH.", "Red")
        throw "Git is not installed."
    }
    
    $Logger.WriteLog("SUCCESS", "Prerequisites check completed.", "Green")
    return $true
}