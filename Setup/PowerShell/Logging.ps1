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
            
            # Create process with streaming enabled and unbuffered output
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "wsl.exe"
            # Add stdbuf to disable buffering + force line buffering
            $psi.Arguments = "-d $($this.DistroName) -u $($this.Username) -- stdbuf -oL -eL bash -c `"$Command`""
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            
            # Capture instance references in local scope
            $loggerRef = $this.Logger
            $outputLogRef = $this.OutputLogFile
            $errorLogRef = $this.ErrorLogFile
            $thisRef = $this
            
            # Shared variable for tracking last output time
            $lastOutputTime = [ref](Get-Date)
            
            # Event handler for standard output
            $outputAction = {
                param($sender, $e)
                if (-not [string]::IsNullOrEmpty($e.Data)) {
                    $lastOutputTime.Value = Get-Date
                    
                    # Immediately display to console
                    $thisRef.DisplayLine($e.Data)
                    
                    # Force console flush
                    [Console]::Out.Flush()
                    
                    # Log to files (non-blocking)
                    try {
                        Add-Content -Path $loggerRef.LogFile -Value "WSL-OUT: $($e.Data)" -Encoding UTF8 -ErrorAction SilentlyContinue
                        Add-Content -Path $outputLogRef -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $($e.Data)" -Encoding UTF8 -ErrorAction SilentlyContinue
                    }
                    catch { }
                }
            }.GetNewClosure()
            
            # Event handler for error output
            $errorAction = {
                param($sender, $e)
                if (-not [string]::IsNullOrEmpty($e.Data)) {
                    $lastOutputTime.Value = Get-Date
                    
                    # Immediately display to console
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] WSL-ERR: $($e.Data)" -ForegroundColor Red
                    [Console]::Out.Flush()
                    
                    # Log to files (non-blocking)
                    try {
                        Add-Content -Path $loggerRef.LogFile -Value "WSL-ERR: $($e.Data)" -Encoding UTF8 -ErrorAction SilentlyContinue
                        Add-Content -Path $errorLogRef -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $($e.Data)" -Encoding UTF8 -ErrorAction SilentlyContinue
                    }
                    catch { }
                }
            }.GetNewClosure()
            
            # Register event handlers
            $outputEventJob = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $outputAction
            $errorEventJob = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $errorAction
            
            # Start process and begin async reading
            $process.Start() | Out-Null
            $process.BeginOutputReadLine()
            $process.BeginErrorReadLine()
            
            # Wait for completion with more frequent checks
            $startTime = Get-Date
            $lastProgressDot = Get-Date
            
            while (!$process.HasExited) {
                Start-Sleep -Milliseconds 100  # Check more frequently
                
                $now = Get-Date
                $timeSinceLastOutput = $now - $lastOutputTime.Value
                
                # Show progress dots if no output for 5 seconds
                if ($timeSinceLastOutput.TotalSeconds -gt 5 -and ($now - $lastProgressDot).TotalSeconds -gt 2) {
                    Write-Host "." -NoNewline -ForegroundColor DarkGray
                    [Console]::Out.Flush()
                    $lastProgressDot = $now
                }
            }
            
            # Wait a bit more for any final output
            Start-Sleep -Milliseconds 500
            $process.WaitForExit()
            $exitCode = $process.ExitCode
            
            # Log completion
            $endTime = Get-Date
            $duration = $endTime - $startTime
            $this.Logger.WriteLog("INFO", "Command completed in $($duration.TotalSeconds.ToString('F1'))s with exit code: $exitCode", "Gray")
            
            # Clean up event handlers
            try {
                Unregister-Event -SourceIdentifier $outputEventJob.Name -Force -ErrorAction SilentlyContinue
                Unregister-Event -SourceIdentifier $errorEventJob.Name -Force -ErrorAction SilentlyContinue
                Remove-Job -Job $outputEventJob -Force -ErrorAction SilentlyContinue
                Remove-Job -Job $errorEventJob -Force -ErrorAction SilentlyContinue
            }
            catch { }
            
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
                Get-EventSubscriber | Where-Object { $_.SourceObject -eq $process } | Unregister-Event -Force -ErrorAction SilentlyContinue
                Get-Job | Where-Object { $_.Name -like "Event.*" } | Remove-Job -Force -ErrorAction SilentlyContinue
            }
            catch { }
            return $false
        }
    }
    
    [void] DisplayLine([string]$Line) {
        if ([string]::IsNullOrWhiteSpace($Line)) { return }
        
        $timestamp = Get-Date -Format "HH:mm:ss"
        $cleanLine = $Line.Trim()
        
        # Enhanced color coding with immediate flush after each write
        switch -Regex ($cleanLine) {
            '^\[ERROR\]|ERROR:' { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                Write-Host "$cleanLine" -ForegroundColor Red
            }
            '^\[SUCCESS\]|SUCCESS:' { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                Write-Host "$cleanLine" -ForegroundColor Green
            }
            '^\[STATUS\]|STATUS:' { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                Write-Host "$cleanLine" -ForegroundColor Cyan
            }
            '^\[WARNING\]|WARNING:' { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                Write-Host "$cleanLine" -ForegroundColor Yellow
            }
            'downloading|retrieving packages' { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                Write-Host "$cleanLine" -ForegroundColor Blue
            }
            'installing|upgrading' { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                Write-Host "$cleanLine" -ForegroundColor Green
            }
            'Total.*Size:|Package.*New Version' { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                Write-Host "$cleanLine" -ForegroundColor Cyan
            }
            'checking|resolving dependencies' { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                Write-Host "$cleanLine" -ForegroundColor Yellow
            }
            '^===.*===|^---.*---' { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                Write-Host "$cleanLine" -ForegroundColor Magenta
            }
            'completed.*\(\d+s\)' { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                Write-Host "$cleanLine" -ForegroundColor Green
            }
            'Duration:\s*\d+s' { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                Write-Host "$cleanLine" -ForegroundColor Green
            }
            default { 
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
                Write-Host "$cleanLine" -ForegroundColor White
            }
        }
        
        # Force immediate console update after each line
        [Console]::Out.Flush()
    }
    
    [void] Cleanup() {
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