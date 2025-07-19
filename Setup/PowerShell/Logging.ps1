class WslLogger {
    # --- Properties ---
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
    # A method for writing standard log messages.
    [void]WriteLog([string]$Level, [string]$Message, [ConsoleColor]$ForegroundColor = "White") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $Message"

        Write-Host $logMessage -ForegroundColor $ForegroundColor

        # This will now work correctly because $this is a real object instance.
        $logMessage | Out-File -FilePath $this.LogFile -Append
    }

    # A method for writing formatted headers.
    [void]WriteHeader([string]$Message) {
        $separator = "================================================================="
        # Note: We no longer need the '&' call operator. These are direct method calls.
        $this.WriteLog("HEADER", $separator, "Cyan")
        $this.WriteLog("HEADER", $Message, "Cyan")
        $this.WriteLog("HEADER", $separator, "Cyan")
    }
}
