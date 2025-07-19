# Setup/PowerShell/Logging.ps1

class WslLogger {
    # --- Properties ---
    [string]$LogFile
    [string]$LogDir

    # --- Constructor ---
    WslLogger([string]$BasePath = "C:\wsl") {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

        # --- THE FIX IS HERE ---
        # We assign directly to the object's properties ($this) instead of creating
        # temporary variables like $logDir or $logFile first. This satisfies the
        # stricter parser in older PowerShell versions.
        $this.LogDir = "$BasePath\tmp\logs\$timestamp"
        $this.LogFile = "$($this.LogDir)\powershell_install.log"

        # Create log directories
        $directoriesToCreate = @("$BasePath", "$BasePath\tmp", "$BasePath\tmp\logs", $this.LogDir)
        foreach ($dir in $directoriesToCreate) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        # Initialize the log file with a header, using the object's property directly.
        "=== PowerShell Installation Log Started at $(Get-Date) ===" | Out-File -FilePath $this.LogFile
        "=== System Information ===" | Out-File -FilePath $this.LogFile -Append
        "User: $env:USERNAME" | Out-File -FilePath $this.LogFile -Append
        "Computer: $env:COMPUTERNAME" | Out-File -FilePath $this.LogFile -Append
        "PowerShell Version: $($PSVersionTable.PSVersion)" | Out-File -FilePath $this.LogFile -Append
        "Windows Version: $([System.Environment]::OSVersion.Version)" | Out-File -FilePath $this.LogFile -Append
        "==========================" | Out-File -FilePath $this.LogFile -Append
    }

    # --- Methods ---
    [void]WriteLog([string]$Level, [string]$Message, [ConsoleColor]$ForegroundColor = "White") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $Message"
        Write-Host $logMessage -ForegroundColor $ForegroundColor
        $logMessage | Out-File -FilePath $this.LogFile -Append
    }

    [void]WriteHeader([string]$Message) {
        $separator = "================================================================="
        $this.WriteLog("HEADER", $separator, "Cyan")
        $this.WriteLog("HEADER", $Message, "Cyan")
        $this.WriteLog("HEADER", $separator, "Cyan")
    }
}
