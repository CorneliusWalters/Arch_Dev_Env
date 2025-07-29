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
    
    # --- SIMPLIFIED execution method - NO EVENT HANDLERS ---
    [bool] ExecuteCommand([string]$Command, [string]$Description) {
        $this.Logger.WritePhaseStatus("WSL_EXEC", "STARTING", $Description)
        
        try {
            # Simple approach using Start-Process with file redirection
            $enhancedCommand = "$Command && echo 'WSL_COMMAND_SUCCESS'"
            
            $wslArgs = @("-d", $this.DistroName, "-u", $this.Username, "-e", "bash", "-c", $enhancedCommand)
            
            # Use Start-Process with file redirection - NO EVENT HANDLERS
            $wslProcess = Start-Process -FilePath "wsl" -ArgumentList $wslArgs -RedirectStandardOutput $this.OutputLogFile -RedirectStandardError $this.ErrorLogFile -Wait -PassThru -NoNewWindow
            
            # Give it a moment to write files
            Start-Sleep -Milliseconds 300
            
            # Read and display the output files
            $stdout = @()
            $stderr = @()
            
            if (Test-Path $this.OutputLogFile) {
                $stdout = Get-Content $this.OutputLogFile -ErrorAction SilentlyContinue
                if (-not $stdout) { $stdout = @() }
            }
            
            if (Test-Path $this.ErrorLogFile) {
                $stderr = Get-Content $this.ErrorLogFile -ErrorAction SilentlyContinue
                if (-not $stderr) { $stderr = @() }
            }
            
            # Display output with proper formatting
            foreach ($line in $stdout) {
                if ($line) { 
                    $this.DisplayLine($line)
                    Add-Content -Path $this.Logger.LogFile -Value "WSL-OUT: $line" -Encoding UTF8
                }
            }
            
            foreach ($line in $stderr) {
                if ($line) { 
                    Write-Host "WSL-ERR: $line" -ForegroundColor Red
                    Add-Content -Path $this.Logger.LogFile -Value "WSL-ERR: $line" -Encoding UTF8
                }
            }
            
            $exitCode = $wslProcess.ExitCode
            
            # Debug information
            $this.Logger.WriteLog("DEBUG", "Exit code: $exitCode", "Gray")
            $this.Logger.WriteLog("DEBUG", "Output lines count: $($stdout.Count)", "Gray")
            $this.Logger.WriteLog("DEBUG", "Error lines count: $($stderr.Count)", "Gray")
            
            if ($exitCode -eq 0) {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "SUCCESS", $Description)
                return $true
            }
            else {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exit code: $exitCode")
                
                # Show recent errors if available
                if ($stderr.Count -gt 0) {
                    $this.Logger.WriteLog("ERROR", "Recent errors:", "Red")
                    $stderr | Select-Object -Last 5 | ForEach-Object {
                        if ($_) { $this.Logger.WriteLog("ERROR", "  $_", "Red") }
                    }
                }
                
                # Show recent output if available
                if ($stdout.Count -gt 0) {
                    $this.Logger.WriteLog("ERROR", "Recent output:", "Yellow")
                    $stdout | Select-Object -Last 5 | ForEach-Object {
                        if ($_) { $this.Logger.WriteLog("ERROR", "  $_", "Gray") }
                    }
                }
                
                return $false
            }
            
        }
        catch {
            $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exception: $($_.Exception.Message)")
            return $false
        }
        finally {
            # Clean up temp files
            if (Test-Path $this.ErrorLogFile) {
                Remove-Item $this.ErrorLogFile -ErrorAction SilentlyContinue
            }
        }
    }
    
    # --- Keep the DisplayLine method ---
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
    
    [void] Cleanup() {
        # Nothing to clean up in this simpler approach
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