# Setup/PowerShell/Logging.ps1

class WSLProcessCapture {
    # --- Properties ---
    [PSCustomObject]$Logger
    [string]$DistroName
    [string]$Username
    [string]$OutputLogFile
    [System.Diagnostics.Process]$Process
    [System.Collections.ArrayList]$OutputLines
    [System.Collections.ArrayList]$ErrorLines
    
    # --- Constructor ---
    WSLProcessCapture([PSCustomObject]$Logger, [string]$DistroName, [string]$Username) {
        $this.Logger = $Logger
        $this.DistroName = $DistroName
        $this.Username = $Username
        $this.OutputLogFile = "$($Logger.LogDir)\wsl_output.log"
        $this.OutputLines = New-Object System.Collections.ArrayList
        $this.ErrorLines = New-Object System.Collections.ArrayList
    }
    
    # --- Methods ---
    [bool] ExecuteCommand([string]$Command, [string]$Description) {
        $this.Logger.WritePhaseStatus("WSL_EXEC", "STARTING", $Description)
        
        # Clear previous output
        $this.OutputLines.Clear()
        $this.ErrorLines.Clear()
        
        try {
            # Add verbose error capturing
            $enhancedCommand = "set -euo pipefail; $Command; echo 'WSL_COMMAND_SUCCESS'"
        
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "wsl"
            $psi.Arguments = "-d $($this.DistroName) -u $($this.Username) -e bash -c `"$enhancedCommand`""
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $this.Process = New-Object System.Diagnostics.Process
            $this.Process.StartInfo = $psi
            
            # Create output handlers with proper variable capture
            $outputHandler = {
                $line = $Event.SourceEventArgs.Data
                if ($line) {
                    $this.OutputLines.Add($line) | Out-Null
                    Add-Content -Path $this.OutputLogFile -Value "STDOUT: $line"
                    $this.DisplayLine($line)
                }
            }.GetNewClosure()
            
            $errorHandler = {
                $line = $Event.SourceEventArgs.Data
                if ($line) {
                    $this.ErrorLines.Add($line) | Out-Null
                    Add-Content -Path $this.OutputLogFile -Value "STDERR: $line"
                    $this.DisplayLine($line)
                }
            }.GetNewClosure()

            # Register separate handlers for stdout and stderr
            Register-ObjectEvent -InputObject $this.Process -EventName OutputDataReceived -Action $outputHandler | Out-Null
            Register-ObjectEvent -InputObject $this.Process -EventName ErrorDataReceived -Action $errorHandler | Out-Null
            
            # Start process
            $this.Process.Start() | Out-Null
            $this.Process.BeginOutputReadLine()
            $this.Process.BeginErrorReadLine()
            $this.Process.WaitForExit()
            
            $exitCode = $this.Process.ExitCode
            
            # Give event handlers time to process remaining output
            Start-Sleep -Milliseconds 100
            
            if ($exitCode -eq 0 -and ($this.OutputLines -contains "WSL_COMMAND_SUCCESS")) {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "SUCCESS", $Description)
                return $true
            } else {
                $errorMsg = "$Description - Exit code: $exitCode"
                
                # Add recent error lines to the message
                if ($this.ErrorLines.Count -gt 0) {
                    $recentErrors = $this.ErrorLines | Select-Object -Last 3
                    $errorMsg += " - Recent errors: $($recentErrors -join '; ')"
                }
                
                # Also add last few output lines for context
                if ($this.OutputLines.Count -gt 0) {
                    $recentOutput = $this.OutputLines | Select-Object -Last 2
                    $errorMsg += " - Last output: $($recentOutput -join '; ')"
                }
                
                $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", $errorMsg)
                
                # Log full output for debugging
                $this.Logger.WriteLog("DEBUG", "Full stdout: $($this.OutputLines -join '`n')", "Gray")
                $this.Logger.WriteLog("DEBUG", "Full stderr: $($this.ErrorLines -join '`n')", "Gray")
                
                return $false
            }
        } catch {
            $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exception: $($_.Exception.Message)")
            return $false
        } finally {
            $this.Cleanup()
        }
    }
    
    [void] DisplayLine([string]$Line) {
        if ($Line -match '\[ERROR\]') {
            Write-Host "WSL: $Line" -ForegroundColor Red
        } elseif ($Line -match '\[SUCCESS\]') {
            Write-Host "WSL: $Line" -ForegroundColor Green
        } elseif ($Line -match '\[STATUS\]') {
            Write-Host "WSL: $Line" -ForegroundColor Cyan
        } elseif ($Line -match '\[WARNING\]') {
            Write-Host "WSL: $Line" -ForegroundColor Yellow
        } else {
            Write-Host "WSL: $Line" -ForegroundColor White
        }
    }
    
    [void] Cleanup() {
        if ($this.Process) {
            try {
                if (-not $this.Process.HasExited) {
                    $this.Process.Kill()
                }
                $this.Process.Close()
            } catch {
                # Ignore cleanup errors
            }
        }
        
        # Unregister event handlers
        Get-EventSubscriber | Where-Object SourceObject -eq $this.Process | Unregister-Event
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
        
        $color = switch($Status) {
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

    # Enhanced error logging with recovery info
    WriteRecoveryInfo([string]$DistroName, [string]$Username, [string]$RepoPath) {
        $this.WriteLog("RECOVERY", "=== RECOVERY INSTRUCTIONS ===", "Yellow")
        $this.WriteLog("RECOVERY", "To continue manually, run:", "Yellow")
        $this.WriteLog("RECOVERY", "wsl -d $DistroName -u $Username", "Yellow")
        $this.WriteLog("RECOVERY", "cd $RepoPath && export FORCE_OVERWRITE=true && ./Setup/1_sys_init.sh", "Yellow")
        $this.WriteLog("RECOVERY", "=== END RECOVERY INSTRUCTIONS ===", "Yellow")
    }    
}