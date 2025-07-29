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
            # Use Start-Process for better control
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "wsl.exe"
            $psi.Arguments = "-d $($this.DistroName) -u $($this.Username) -- bash -c `"$Command`""
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
	            
            $process = [System.Diagnostics.Process]::Start($psi)
	            
            # Read output in real-time using simple loops (no events)
            $standardOutput = @()
            $standardError = @()  # Changed from $error to $standardError
	            
            while (!$process.HasExited) {
                if (!$process.StandardOutput.EndOfStream) {
                    $line = $process.StandardOutput.ReadLine()
                    if ($line) {
                        $this.DisplayLine($line)
                        $standardOutput += $line
                        # Also log to file
                        Add-Content -Path $this.OutputLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
                    }
                }
                if (!$process.StandardError.EndOfStream) {
                    $errorLine = $process.StandardError.ReadLine()
                    if ($errorLine) {
                        Write-Host "WSL-ERR: $errorLine" -ForegroundColor Red
                        $standardError += $errorLine
                        # Also log to file
                        Add-Content -Path $this.ErrorLogFile -Value $errorLine -Encoding UTF8 -ErrorAction SilentlyContinue
                    }
                }
                Start-Sleep -Milliseconds 50
            }
	            
            # Read any remaining output
            $remainingOutput = $process.StandardOutput.ReadToEnd()
            $remainingError = $process.StandardError.ReadToEnd()
	            
            if ($remainingOutput) {
                $remainingOutput.Split("`n") | ForEach-Object {
                    if ($_.Trim()) { 
                        $this.DisplayLine($_)
                        $standardOutput += $_
                        Add-Content -Path $this.OutputLogFile -Value $_ -Encoding UTF8 -ErrorAction SilentlyContinue
                    }
                }
            }
            if ($remainingError) {
                $remainingError.Split("`n") | ForEach-Object {
                    if ($_.Trim()) { 
                        Write-Host "WSL-ERR: $_" -ForegroundColor Red
                        $standardError += $_
                        Add-Content -Path $this.ErrorLogFile -Value $_ -Encoding UTF8 -ErrorAction SilentlyContinue
                    }
                }
            }
	            
            $process.WaitForExit()
            $exitCode = $process.ExitCode
            $process.Dispose()
	            
            # Log summary to main log
            $this.Logger.WriteLog("DEBUG", "Command completed with exit code: $exitCode", "Gray")
            if ($standardOutput.Count -gt 0) {
                $this.Logger.WriteLog("DEBUG", "Standard output lines: $($standardOutput.Count)", "Gray")
            }
            if ($standardError.Count -gt 0) {
                $this.Logger.WriteLog("WARNING", "Standard error lines: $($standardError.Count)", "Yellow")
            }
	            
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
            return $false
        }
    }
	    
    [void] DisplayLine([string]$Line) {
        if ([string]::IsNullOrWhiteSpace($Line)) { return }
	        
        switch -Regex ($Line) {
            '\[ERROR\]' { Write-Host "WSL: $Line" -ForegroundColor Red }
            '\[SUCCESS\]' { Write-Host "WSL: $Line" -ForegroundColor Green }
            '\[STATUS\]' { Write-Host "WSL: $Line" -ForegroundColor Cyan }
            '\[WARNING\]' { Write-Host "WSL: $Line" -ForegroundColor Yellow }
            'ERROR:' { Write-Host "WSL: $Line" -ForegroundColor Red }
            'WARNING:' { Write-Host "WSL: $Line" -ForegroundColor Yellow }
            'SUCCESS:' { Write-Host "WSL: $Line" -ForegroundColor Green }
            default { Write-Host "WSL: $Line" -ForegroundColor White }
        }
    }
	    
    [void] Cleanup() {
        # Clean up any resources if needed
        if (Test-Path $this.OutputLogFile) {
            $this.Logger.WriteLog("INFO", "WSL output log available at: $($this.OutputLogFile)", "Gray")
        }
        if (Test-Path $this.ErrorLogFile) {
            $this.Logger.WriteLog("INFO", "WSL error log available at: $($this.ErrorLogFile)", "Gray")
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