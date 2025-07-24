# Setup/PowerShell/Logging.ps1

class WSLProcessCapture {
    # --- Properties ---
    [PSCustomObject]$Logger
    [string]$DistroName
    [string]$Username
    [string]$OutputLogFile
    [System.Diagnostics.Process]$Process
    
    # --- Constructor ---
    WSLProcessCapture([PSCustomObject]$Logger, [string]$DistroName, [string]$Username) {
        $this.Logger = $Logger
        $this.DistroName = $DistroName
        $this.Username = $Username
        $this.OutputLogFile = "$($Logger.LogDir)\wsl_output.log"
    }
    
    # --- Methods ---
    [bool] ExecuteCommand([string]$Command, [string]$Description) {
        $this.Logger.WritePhaseStatus("WSL_EXEC", "STARTING", $Description)
        
        try {
            # Simple approach - no nested bash
            $enhancedCommand = "$Command && echo 'WSL_COMMAND_SUCCESS'"
            
            # Execute and capture output directly
            $wslArgs = @("-d", $this.DistroName, "-u", $this.Username, "-e", "bash", "-c", $enhancedCommand)
            $wslProcess = Start-Process -FilePath "wsl" -ArgumentList $wslArgs -RedirectStandardOutput $this.OutputLogFile -RedirectStandardError "$($this.OutputLogFile).err" -Wait -PassThru -NoNewWindow
            
            # Read the output files
            Start-Sleep -Milliseconds 100
            
            $stdout = @()
            $stderr = @()
            
            if (Test-Path $this.OutputLogFile) {
                $stdout = Get-Content $this.OutputLogFile -ErrorAction SilentlyContinue
                if (-not $stdout) { $stdout = @() }
            }
            
            if (Test-Path "$($this.OutputLogFile).err") {
                $stderr = Get-Content "$($this.OutputLogFile).err" -ErrorAction SilentlyContinue
                if (-not $stderr) { $stderr = @() }
            }
            
            # Display output
            foreach ($line in $stdout) {
                if ($line) { $this.DisplayLine($line) }
            }
            foreach ($line in $stderr) {
                if ($line) { $this.DisplayLine($line) }
            }
            
            $exitCode = $wslProcess.ExitCode
            
            # Debug output
            $this.Logger.WriteLog("DEBUG", "Exit code: $exitCode", "Gray")
            $this.Logger.WriteLog("DEBUG", "Output lines count: $($stdout.Count)", "Gray")
            $this.Logger.WriteLog("DEBUG", "Error lines count: $($stderr.Count)", "Gray")
            
            # Check for success - more lenient check
            if ($exitCode -eq 0) {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "SUCCESS", $Description)
                return $true
            } else {
                $errorMsg = "$Description - Exit code: $exitCode"
                
                if ($stderr.Count -gt 0) {
                    $recentErrors = $stderr | Select-Object -Last 3
                    $errorMsg += " - Recent errors: $($recentErrors -join '; ')"
                }
                
                if ($stdout.Count -gt 0) {
                    $recentOutput = $stdout | Select-Object -Last 2
                    $errorMsg += " - Last output: $($recentOutput -join '; ')"
                }
                
                $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", $errorMsg)
                return $false
            }
        } catch {
            $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exception: $($_.Exception.Message)")
            return $false
        } finally {
            # Clean up temp files
            if (Test-Path "$($this.OutputLogFile).err") {
                Remove-Item "$($this.OutputLogFile).err" -ErrorAction SilentlyContinue
            }
        }
    }
    
    # --- ADD THIS METHOD BACK ---
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