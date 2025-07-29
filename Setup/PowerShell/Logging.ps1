# Setup/PowerShell/Logging.ps1

class WSLProcessCapture {
    # --- Properties ---
    [PSCustomObject]$Logger
    [string]$DistroName
    [string]$Username
    [string]$OutputLogFile
    [string]$ErrorLogFile
    
    # --- Constructor ---
    WSLProcessCapture([PSCustomObject]$Logger, [string]$DistroName, [string]$Username) {
        $this.Logger = $Logger
        $this.DistroName = $DistroName
        $this.Username = $Username
        $this.OutputLogFile = "$($Logger.LogDir)\wsl_output.log"
        $this.ErrorLogFile = "$($Logger.LogDir)\wsl_error.log"
    }
    
    # --- Enhanced execution method with both real-time AND file output ---

    [bool] ExecuteCommand([string]$Command, [string]$Description) {
        $this.Logger.WritePhaseStatus("WSL_EXEC", "STARTING", $Description)
    
        # Clear previous log files for this command
        if (Test-Path $this.OutputLogFile) { Clear-Content $this.OutputLogFile }
        if (Test-Path $this.ErrorLogFile) { Clear-Content $this.ErrorLogFile }
    
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "wsl"
            $psi.Arguments = "-d $($this.DistroName) -u $($this.Username) bash -c `"$Command`""
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
        
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
        
            # Real-time output handling WITH file logging - USING GetNewClosure()
            $process.add_OutputDataReceived({
                    param($processObject, $eventArgs)
                    if (-not [string]::IsNullOrEmpty($eventArgs.Data)) {
                        # Display to console with colors
                        $this.DisplayLine($eventArgs.Data)
                
                        # Write to file for persistent logging
                        Add-Content -Path $this.OutputLogFile -Value $eventArgs.Data -Encoding UTF8
                
                        # Also write to main log file
                        Add-Content -Path $this.Logger.LogFile -Value "WSL-OUT: $($eventArgs.Data)" -Encoding UTF8
                    }
                }.GetNewClosure())
        
            $process.add_ErrorDataReceived({
                    param($processObject, $eventArgs)
                    if (-not [string]::IsNullOrEmpty($eventArgs.Data)) {
                        # Display error to console
                        Write-Host "WSL-ERR: $($eventArgs.Data)" -ForegroundColor Red
                
                        # Write to error file
                        Add-Content -Path $this.ErrorLogFile -Value $eventArgs.Data -Encoding UTF8
                
                        # Also write to main log file
                        Add-Content -Path $this.Logger.LogFile -Value "WSL-ERR: $($eventArgs.Data)" -Encoding UTF8
                    }
                }.GetNewClosure())
        
            $process.Start()
            $process.BeginOutputReadLine()
            $process.BeginErrorReadLine()
            $process.WaitForExit()
        
            $exitCode = $process.ExitCode
        
            # Log command completion details
            $this.Logger.WriteLog("DEBUG", "Command completed with exit code: $exitCode", "Gray")
            $this.Logger.WriteLog("DEBUG", "Full output logged to: $($this.OutputLogFile)", "Gray")
            if (Test-Path $this.ErrorLogFile -PathType Leaf) {
                $errorSize = (Get-Item $this.ErrorLogFile).Length
                if ($errorSize -gt 0) {
                    $this.Logger.WriteLog("DEBUG", "Errors logged to: $($this.ErrorLogFile)", "Gray")
                }
            }
        
            if ($exitCode -eq 0) {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "SUCCESS", $Description)
                return $true
            }
            else {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exit code: $exitCode")
            
                # Show recent errors from file if available
                if (Test-Path $this.ErrorLogFile -PathType Leaf) {
                    $recentErrors = Get-Content $this.ErrorLogFile -Tail 5 -ErrorAction SilentlyContinue
                    if ($recentErrors) {
                        $this.Logger.WriteLog("ERROR", "Recent errors from log file:", "Red")
                        foreach ($errorLine in $recentErrors) {
                            $this.Logger.WriteLog("ERROR", "  $errorLine", "Red")
                        }
                    }
                }
            
                # Show recent output from file if available
                if (Test-Path $this.OutputLogFile -PathType Leaf) {
                    $recentOutput = Get-Content $this.OutputLogFile -Tail 5 -ErrorAction SilentlyContinue
                    if ($recentOutput) {
                        $this.Logger.WriteLog("ERROR", "Recent output from log file:", "Yellow")
                        foreach ($outputLine in $recentOutput) {
                            $this.Logger.WriteLog("ERROR", "  $outputLine", "Gray")
                        }
                    }
                }
            
                return $false
            }
        
        }
        catch {
            $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exception: $($_.Exception.Message)")
            return $false
        }
    }
    
    # --- Keep the existing DisplayLine method ---
    [void] DisplayLine([string]$Line) {
        if ($Line -match '\[ERROR\]') {
            Write-Host "WSL: $Line" -ForegroundColor Red
        }
        elseif ($Line -match '\[SUCCESS\]') {
            Write-Host "WSL: $Line" -ForegroundColor Green
        }
        elseif ($Line -match '\[STATUS\]') {
            Write-Host "WSL: $Line" -ForegroundColor Cyan
        }
        elseif ($Line -match '\[WARNING\]') {
            Write-Host "WSL: $Line" -ForegroundColor Yellow
        }
        else {
            Write-Host "WSL: $Line" -ForegroundColor White
        }
    }
    
    # --- Enhanced cleanup method ---
    [void] Cleanup() {
        # Optionally archive the log files instead of deleting them
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        if (Test-Path $this.OutputLogFile) {
            $archivePath = "$($this.OutputLogFile).$timestamp"
            Move-Item $this.OutputLogFile $archivePath -ErrorAction SilentlyContinue
        }
        
        if (Test-Path $this.ErrorLogFile) {
            $archivePath = "$($this.ErrorLogFile).$timestamp"
            Move-Item $this.ErrorLogFile $archivePath -ErrorAction SilentlyContinue
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