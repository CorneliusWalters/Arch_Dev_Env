# Setup/PowerShell/Logging.ps1

class WslLogger {
    # --- Properties ---
    # These are the variables that each logger object will have.
    [string]$LogFile
    [string]$LogDir

    # --- Constructor ---
    # This method runs automatically when we create a new logger object.
    WslLogger([string]$BasePath = "C:\wsl") {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $logDir = "$BasePath\tmp\logs\$timestamp"

        # Set the object's own properties using $this
        $this.LogDir = $logDir
        $this.LogFile = "$logDir\powershell_install.log"

        # Create log directories
        $directoriesToCreate = @("$BasePath", "$BasePath\tmp", "$BasePath\tmp\logs", $this.LogDir)
        foreach ($dir in $directoriesToCreate) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        # Initialize the log file with a header
        "=== PowerShell Installation Log Started at $(Get-Date) ===" | Out-File -FilePath $this.LogFile
        "=== System Information ===" | Out-File -FilePath $this.LogFile -Append
        "User: $env:USERNAME" | Out-File -FilePath $this.LogFile -Append
        "Computer: $env:COMPUTERNAME" | Out-File -FilePath $this.LogFile -Append
        "PowerShell Version: $($PSVersionTable.PSVersion)" | Out-File -FilePath $this.LogFile -Append
        "Windows Version: $([System.Environment]::OSVersion.Version)" | Out-File -FilePath $this.LogFile -Append
        "==========================" | Out-File -FilePath $this.LogFile -Append
    }

    # --- Methods ---
    # These are the functions that the logger object can perform.
    # Note that the old "return @{...}" block is completely gone.

    [void]WriteLog([string]$Level, [string]$Message, [ConsoleColor]$ForegroundColor = "White") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $Message"

        Write-Host $logMessage -ForegroundColor $ForegroundColor

        # This now works correctly because $this is a real object instance.
        $logMessage | Out-File -FilePath $this.LogFile -Append
    }

    [void]WriteHeader([string]$Message) {
        $separator = "================================================================="
        # These are now direct method calls on the object.
        $this.WriteLog("HEADER", $separator, "Cyan")
        $this.WriteLog("HEADER", $Message, "Cyan")
        $this.WriteLog("HEADER", $separator, "Cyan")
    }
}
