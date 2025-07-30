# Setup/PowerShell/Logging.ps1


class WSLProcessCapture {
    [PSCustomObject]$Logger
    [string]$DistroName
    [string]$Username
    [string]$OutputLogFile
    [string]$ErrorLogFile
    
    WSLProcessCapture([PSCustomObject]$Logger, [string]$DistroName, [string]$Username) {
        $this.Logger = $Logger
        $this.DistroName = $DistroName
        $this.Username = $Username
        $this.OutputLogFile = "$($Logger.LogDir)\wsl_output.log"
        $this.ErrorLogFile = "$($Logger.LogDir)\wsl_error.log"
    }
    
    [bool] ExecuteCommand([string]$Command, [string]$Description) {
        $this.Logger.WritePhaseStatus("WSL_EXEC", "STARTING", $Description)
        
        try {
            $this.Logger.WriteLog("INFO", "Starting: $Description", "Cyan")
            
            # Create process with streaming enabled
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "wsl.exe"
            $psi.Arguments = "-d $($this.DistroName) -u $($this.Username) bash -c `"$Command`""
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            
            # Store references for event handlers
            $logger = $this.Logger
            $outputLogFile = $this.OutputLogFile
            $errorLogFile = $this.ErrorLogFile
            $displayLineMethod = $this
            
            # Event handler for standard output with file logging
            $outputReceived = {
                param($sender, $e)
                if (-not [string]::IsNullOrEmpty($e.Data)) {
                    # Display to console
                    $displayLineMethod.DisplayLine($e.Data)
                    
                    # Log to main log file
                    try {
                        Add-Content -Path $logger.LogFile -Value "WSL-OUT: $($e.Data)" -Encoding UTF8 -ErrorAction SilentlyContinue
                    }
                    catch { }
                    
                    # Log to dedicated output file
                    try {
                        Add-Content -Path $outputLogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $($e.Data)" -Encoding UTF8 -ErrorAction SilentlyContinue
                    }
                    catch { }
                }
            }
            
            # Event handler for error output with file logging
            $errorReceived = {
                param($sender, $e)
                if (-not [string]::IsNullOrEmpty($e.Data)) {
                    # Display to console
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] WSL-ERR: $($e.Data)" -ForegroundColor Red
                    
                    # Log to main log file
                    try {
                        Add-Content -Path $logger.LogFile -Value "WSL-ERR: $($e.Data)" -Encoding UTF8 -ErrorAction SilentlyContinue
                    }
                    catch { }
                    
                    # Log to dedicated error file
                    try {
                        Add-Content -Path $errorLogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $($e.Data)" -Encoding UTF8 -ErrorAction SilentlyContinue
                    }
                    catch { }
                }
            }
            
            # Register event handlers
            Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $outputReceived | Out-Null
            Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $errorReceived | Out-Null
            
            # Start process and begin async reading
            $process.Start() | Out-Null
            $process.BeginOutputReadLine()
            $process.BeginErrorReadLine()
            
            # Wait for completion while showing progress
            $startTime = Get-Date
            while (!$process.HasExited) {
                Start-Sleep -Milliseconds 250
                
                # Optional: Show progress dots every 10 seconds for long-running commands
                $elapsed = (Get-Date) - $startTime
                if ($elapsed.TotalSeconds -gt 0 -and ($elapsed.TotalSeconds % 10) -lt 0.25) {
                    Write-Host "." -NoNewline -ForegroundColor DarkGray
                }
            }
            
            $process.WaitForExit()
            $exitCode = $process.ExitCode
            
            # Log completion
            $endTime = Get-Date
            $duration = $endTime - $startTime
            $this.Logger.WriteLog("INFO", "Command completed in $($duration.TotalSeconds.ToString('F1'))s with exit code: $exitCode", "Gray")
            
            # Clean up event handlers
            Get-EventSubscriber | Where-Object { $_.SourceObject -eq $process } | Unregister-Event -Force
            $process.Dispose()
            
            if ($exitCode -eq 0) {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "SUCCESS", $Description)
                return $true
            }
            else {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exit code: $exitCode")
                return $false
            }
            
        }
        catch {
            $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exception: $($_.Exception.Message)")
            # Clean up any remaining event handlers
            try {
                Get-EventSubscriber | Where-Object { $_.SourceObject.GetType().Name -eq "Process" } | Unregister-Event -Force
            }
            catch { }
            return $false
        }
    }
    
    [void] DisplayLine([string]$Line) {
        if ([string]::IsNullOrWhiteSpace($Line)) { return }
        
        $timestamp = Get-Date -Format "HH:mm:ss"
        $cleanLine = $Line.Trim()
        
        # Enhanced color coding for better readability
        switch -Regex ($cleanLine) {
            '^\[ERROR\]|ERROR:' { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor Red }
            '^\[SUCCESS\]|SUCCESS:' { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor Green }
            '^\[STATUS\]|STATUS:' { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor Cyan }
            '^\[WARNING\]|WARNING:' { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor Yellow }
            'downloading|retrieving packages' { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor Blue }
            'installing|upgrading' { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor Green }
            'Total.*Size:|Package.*New Version' { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor Cyan }
            'checking|resolving dependencies' { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor Yellow }
            '^===.*===|^---.*---' { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor Magenta }
            'completed.*\(\d+s\)' { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor Green }
            'Duration:\s*\d+s' { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor Green }
            default { Write-Host "[$timestamp] " -NoNewline; Write-Host "$cleanLine" -ForegroundColor White }
        }
        
        # Force immediate console update
        [Console]::Out.Flush()
    }
    
    [void] Cleanup() {
        # Summary of log files created
        if (Test-Path $this.OutputLogFile) {
            $this.Logger.WriteLog("INFO", "WSL output log: $($this.OutputLogFile)", "Gray")
        }
        if (Test-Path $this.ErrorLogFile) {
            $this.Logger.WriteLog("INFO", "WSL error log: $($this.ErrorLogFile)", "Gray")
        }
    }
}
class WslLogger {
    # --- Properties ---
    [string]$LogFile
    [string]$LogDir

    # --- Constructor ---
    WslLogger([string]$BasePath = "c:\wsl") {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $this.LogDir = "$BasePath\tmp\logs\$timestamp"
        $this.LogFile = "$($this.LogDir)\powershell_install.log"
        $directoriesToCreate = @("$BasePath", "$BasePath\tmp", "$BasePath\tmp\logs", $this.LogDir)
        foreach ($dir in $directoriesToCreate) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }
    }

    # --- Methods ---
    # The [void] has been removed from the method definitions for PS 5.1 compatibility.
    WriteLog([string]$Level, [string]$Message, [ConsoleColor]$ForegroundColor = "White") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $Message"
        Write-Host $logMessage -ForegroundColor $ForegroundColor
        Add-Content -Path $this.LogFile -Value $logMessage
    }

    WriteHeader([string]$Message) {
        $separator = "=" * 80
        $this.WriteLog("HEADER", $separator, "Cyan")
        $this.WriteLog("HEADER", $Message, "Cyan")
        $this.WriteLog("HEADER", $separator, "Cyan")
    }
    
    WritePhaseStatus([string]$Phase, [string]$Status, [string]$Details = "") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $message = "[$timestamp] [PHASE: $Phase] [$Status] $Details"
        
        $color = switch ($Status) {
            "SUCCESS" { "Green" }
            "ERROR" { "Red" }
            "STARTING" { "Cyan" }
            "TIMEOUT" { "Yellow" }
            default { "White" }
        }
        
        $this.WriteLog("PHASE", $message, $color)
        
        # Also write to a separate phase log for debugging
        $phaseLogPath = "$($this.LogDir)\phases.log"
        Add-Content -Path $phaseLogPath -Value $message
    }
    [bool] InvokeWSLWithRealTimeOutput([string]$DistroName, [string]$Username, [string]$Command, [string]$Description) {
        $this.WritePhaseStatus("WSL_REAL", "STARTING", $Description)
        
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "wsl"
            $psi.Arguments = "-d $DistroName -u $Username bash -c `"$Command`""
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            
            # Real-time output handling with proper coloring
            $process.add_OutputDataReceived({
                    param($processObject, $e)
                    if (-not [string]::IsNullOrEmpty($e.Data)) {
                        if ($e.Data -match '\[ERROR\]') {
                            Write-Host "WSL: $($e.Data)" -ForegroundColor Red
                        }
                        elseif ($e.Data -match '\[SUCCESS\]') {
                            Write-Host "WSL: $($e.Data)" -ForegroundColor Green
                        }
                        elseif ($e.Data -match '\[STATUS\]') {
                            Write-Host "WSL: $($e.Data)" -ForegroundColor Cyan
                        }
                        elseif ($e.Data -match '\[WARNING\]') {
                            Write-Host "WSL: $($e.Data)" -ForegroundColor Yellow
                        }
                        else {
                            Write-Host "WSL: $($e.Data)" -ForegroundColor White
                        }
                    
                        # Also write to log file
                        Add-Content -Path $this.LogFile -Value "WSL: $($e.Data)"
                    }
                })
            
            $process.add_ErrorDataReceived({
                    param($processObject, $e)
                    if (-not [string]::IsNullOrEmpty($e.Data)) {
                        Write-Host "WSL-ERR: $($e.Data)" -ForegroundColor Red
                        Add-Content -Path $this.LogFile -Value "WSL-ERR: $($e.Data)"
                    }
                })
            
            $process.Start()
            $process.BeginOutputReadLine()
            $process.BeginErrorReadLine()
            $process.WaitForExit()
            
            $exitCode = $process.ExitCode
            
            if ($exitCode -eq 0) {
                $this.WritePhaseStatus("WSL_REAL", "SUCCESS", $Description)
                return $true
            }
            else {
                $this.WritePhaseStatus("WSL_REAL", "ERROR", "$Description - Exit code: $exitCode")
                return $false
            }
            
        }
        catch {
            $this.WritePhaseStatus("WSL_REAL", "ERROR", "$Description - Exception: $($_.Exception.Message)")
            return $false
        }
    }
    # Enhanced error logging with recovery info
    WriteRecoveryInfo([string]$DistroName, [string]$Username, [string]$RepoPath) {
        $this.WriteLog("RECOVERY", "=== RECOVERY INSTRUCTIONS ===", "Yellow")
        $this.WriteLog("RECOVERY", "To continue manually, run:", "Yellow")
        $this.WriteLog("RECOVERY", "wsl -d $DistroName -u $Username", "Yellow")
        $this.WriteLog("RECOVERY", "cd $RepoPath && export FORCE_OVERWRITE=true && ./Setup/1_sys_init.sh", "Yellow")
        $this.WriteLog("RECOVERY", "=== END RECOVERY INSTRUCTIONS ===", "Yellow")
    }    
}