# Export-WSLImage.ps1
function Export-WSLImage {
    param (
        [PSCustomObject]$Logger,
        [string]$WslDistroName,
        [string]$ExportPath
    )
    
    & $Logger.WriteHeader "Optional: Exporting Configured WSL Instance"
    $exportConfirm = Read-Host "Do you want to export this configured WSL instance as '$WslDistroName' to '$ExportPath'? (Y/N)"
    & $Logger.WriteLog "INFO" "User chose to export configured WSL instance: $exportConfirm" "Gray"

    if ($exportConfirm -eq 'Y') {
        & $Logger.WriteLog "INFO" "Exporting current state of '$WslDistroName' to '$ExportPath'..." "Cyan"
        & $Logger.WriteLog "INFO" "Terminating WSL instance before export..." "Gray"
        wsl --terminate $WslDistroName # Terminate to ensure consistent export
        
        # Ensure directory for export exists
        $exportDir = Split-Path $ExportPath -Parent
        if (-not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            & $Logger.WriteLog "INFO" "Created export directory: $exportDir" "Gray"
        }
        
        & $Logger.WriteLog "INFO" "Running wsl --export $WslDistroName $ExportPath" "Gray"
        wsl --export $WslDistroName $ExportPath
        if ($LASTEXITCODE -ne 0) {
            & $Logger.WriteLog "WARNING" "Failed to export configured WSL distribution." "Yellow"
            return $false
        } else {
            & $Logger.WriteLog "SUCCESS" "Configured WSL distribution exported successfully." "Green"
            & $Logger.WriteLog "INFO" "You can use this for future quick setups or backups." "Green"
            & $Logger.WriteLog "INFO" "To re-import: wsl --import $WslDistroName C:\WSL\$WslDistroName $ExportPath" "Green"
            return $true
        }
    } else {
        & $Logger.WriteLog "INFO" "Skipping export of configured WSL instance." "Green"
        return $true
    }
}