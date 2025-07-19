# Export-WSLImage.ps1
function Export-WSLImage {
    param (
        [PSCustomObject]$Logger,
        [string]$WslDistroName,
        [string]$ExportPath
    )
    
    $Logger.WriteHeader("Optional: Exporting Configured WSL Instance")
    $exportConfirm = Read-Host "Do you want to export this configured WSL instance to '$ExportPath'? (Y/N)"

    if ($exportConfirm -eq 'Y') {
        $Logger.WriteLog("INFO", "Exporting current state of '$WslDistroName'...", "Cyan")
        wsl --terminate $WslDistroName
        
        $exportDir = Split-Path $ExportPath -Parent
        if (-not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        
        wsl --export $WslDistroName $ExportPath
        $Logger.WriteLog("SUCCESS", "Configured WSL distribution exported successfully.", "Green")
    } else {
        $Logger.WriteLog("INFO", "Skipping export of configured WSL instance.", "Green")
    }
}