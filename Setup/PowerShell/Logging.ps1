# Initialize-Logging.ps1
function Initialize-WSLLogging {
    param (
        [string]$BasePath = "C:\wsl",
        [string]$TmpDir = "tmp\logs"
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logDir = "$BasePath\$TmpDir\$timestamp"
    $logFile = "$logDir\powershell_install.log"
    
    # Create log directories
    $directoriesToCreate = @("$BasePath", "$BasePath\tmp", "$BasePath\tmp\logs", $logDir)
    foreach ($dir in $directoriesToCreate) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    # Initialize log file with header
    "=== PowerShell Installation Log Started at $(Get-Date) ===" | Out-File -FilePath $logFile
    "=== System Information ===" | Out-File -FilePath $logFile -Append
    "User: $env:USERNAME" | Out-File -FilePath $logFile -Append
    "Computer: $env:COMPUTERNAME" | Out-File -FilePath $logFile -Append
    "PowerShell Version: $($PSVersionTable.PSVersion)" | Out-File -FilePath $logFile -Append
    "Windows Version: $([System.Environment]::OSVersion.Version)" | Out-File -FilePath $logFile -Append
    "Script Path: $PSCommandPath" | Out-File -FilePath $logFile -Append
    "==========================" | Out-File -FilePath $logFile -Append
    
    # Return a logging object with properties and methods
    return @{
        LogFile = $logFile
        LogDir = $logDir
        
        WriteLog = {
            param (
                [string]$Level,
                [string]$Message,
                [ConsoleColor]$ForegroundColor = "White"
            )
            
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logMessage = "[$timestamp] [$Level] $Message"
            
            # Write to console with color
            Write-Host $logMessage -ForegroundColor $ForegroundColor
            
            # Write to log file
            $logMessage | Out-File -FilePath $logFile -Append
        }
        
        WriteHeader = {
            param([string]$Message)
            $separator = "================================================================="
            & $this.WriteLog "HEADER" $separator "Cyan"
            & $this.WriteLog "HEADER" $Message "Cyan"
            & $this.WriteLog "HEADER" $separator "Cyan"
        }
    }
}