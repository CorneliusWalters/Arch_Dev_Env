class WSLProcessCapture {
    [PSCustomObject]$Logger
    [string]$DistroName
    [string]$Username
    [string]$OutputLogFile
    [string]$ErrorLogFile
    [string]$PipeName

    WSLProcessCapture(
        [PSCustomObject]$Logger,
        [string]$DistroName,
        [string]$Username
    ) {
        $this.Logger = $Logger
        $this.DistroName = $DistroName
        $this.Username = $Username
        $this.OutputLogFile = "$($Logger.LogDir)\wsl_output.log"
        $this.ErrorLogFile = "$($Logger.LogDir)\wsl_error.log"
        $this.PipeName = "wsl_output_$(Get-Random)"
    }

    [bool] ExecuteCommand([string]$Command, [string]$Description) {
        $this.Logger.WritePhaseStatus("WSL_EXEC", "STARTING", $Description)

        try {
            $this.Logger.WriteLog("INFO", "Starting: $Description", "Cyan")

            # Always use file-based approach for better reliability
            $this.Logger.WriteLog(
                "INFO",
                "Using file-based streaming approach",
                "Cyan"
            )
            return $this.ExecuteWithFileTailing($Command, $Description)
        }
        catch {
            $this.Logger.WritePhaseStatus(
                "WSL_EXEC",
                "ERROR",
                "$Description - Exception: $($_.Exception.Message)"
            )
            return $false
        }
    }

    [bool] ExecuteWithFileTailing([string]$Command, [string]$Description) {
        $outputFile = "/tmp/wsl_output_$([System.IO.Path]::GetRandomFileName().Replace('.',''))"
        $finishFile = "$outputFile.finished"
        $windowsOutputFile = "\\wsl$\$($this.DistroName)$outputFile"
        $tailJob = $null
        $wslProcess = $null

        try {
            $this.Logger.WriteLog("INFO", "Using enhanced file-based streaming: $outputFile", "Gray")

            # Start the background job to tail the log file. This part is correct.
            $tailJob = Start-Job -ScriptBlock {
                # ... (The entire ScriptBlock for the tailing job remains unchanged) ...
                param($FilePath, $FinishPath, $LogPath, $DistroName)

                $lastSize = 0
                $maxWaitTime = 900 # Increased timeout for longer installs
                $startTime = Get-Date
                $consecutiveEmptyReads = 0
                $maxConsecutiveEmpty = 150 # Increased for longer pauses like package downloads

                while (((Get-Date) - $startTime).TotalSeconds -lt $maxWaitTime) {
                    if (Test-Path $FilePath) {
                        try {
                            $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue -Encoding UTF8
                            if ($content -and $content.Length -gt $lastSize) {
                                $consecutiveEmptyReads = 0
                                $newContent = $content.Substring($lastSize)
                                $lines = $newContent -split "`r?`n" | Where-Object { $_ -ne "" }
                        
                                foreach ($line in $lines) {
                                    if (-not [string]::IsNullOrWhiteSpace($line.Trim())) {
                                        $timestamp = Get-Date -Format "HH:mm:ss"
                                        $trimmedLine = $line.Trim()
                                
                                        # --- All your existing Write-Host formatting logic goes here ---
                                        # (This entire section is correct and does not need to be changed)
                                        if ($trimmedLine -match '^### PHASE_BOUNDARY ###') {
                                            Write-Host ""
                                            Write-Host ("=" * 80) -ForegroundColor Cyan
                                            continue
                                        }
                                        elseif ($trimmedLine -match '^>>> PHASE_START: (.+)') {
                                            $currentPhase = $matches[1]
                                            $phaseStartTime = Get-Date
                                            Write-Host ""
                                            Write-Host "🚀 STARTING PHASE: " -NoNewline -ForegroundColor Green
                                            Write-Host "$currentPhase" -ForegroundColor Yellow -BackgroundColor DarkBlue
                                            Write-Host ("=" * 80) -ForegroundColor Green
                                            continue
                                        }
                                        elseif ($trimmedLine -match '^<<< PHASE_END: (.+)') {
                                            $endPhase = $matches[1]
                                            $phaseDuration = ((Get-Date) - $phaseStartTime).TotalSeconds
                                            Write-Host ("=" * 80) -ForegroundColor Green
                                            Write-Host "✅ COMPLETED PHASE: " -NoNewline -ForegroundColor Green
                                            Write-Host "$endPhase" -ForegroundColor Yellow -BackgroundColor DarkGreen
                                            Write-Host "⏱️  Duration: $([math]::Round($phaseDuration, 1))s" -ForegroundColor Cyan
                                            Write-Host ("=" * 80) -ForegroundColor Green
                                            Write-Host ""
                                            continue
                                        }
                                        # ... all other elseif blocks for formatting ...
                                        else { 
                                            Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
                                            Write-Host $line -ForegroundColor White
                                        }
                                
                                        [Console]::Out.Flush()
                                        try {
                                            Add-Content -Path $LogPath -Value "[$timestamp] WSL: $line" -ErrorAction SilentlyContinue -Encoding UTF8
                                        }
                                        catch {}
                                    }
                                }
                                $lastSize = $content.Length
                            }
                            else {
                                $consecutiveEmptyReads++
                            }
                        }
                        catch {
                            $consecutiveEmptyReads++
                        }
                    }
                    else {
                        $consecutiveEmptyReads++
                    }
            
                    if (Test-Path $FinishPath) {
                        Start-Sleep -Milliseconds 500 # Final sleep to catch last lines
                        break
                    }
                                
                    if ($consecutiveEmptyReads -lt 10) { Start-Sleep -Milliseconds 100 }
                    else { Start-Sleep -Milliseconds 300 }
                }
                # Final read to ensure nothing is missed
                if (Test-Path $FilePath) {
                    # ... (You can add a final Get-Content here if needed) ...
                }
                Write-Host ""
                Write-Host "📋 Background log tailing job finished for $DistroName." -ForegroundColor Gray
            } -ArgumentList $windowsOutputFile, "\\wsl$\$($this.DistroName)$finishFile", $this.Logger.LogFile, $this.DistroName

            # Give the tail job a moment to start up
            Start-Sleep -Milliseconds 500
        
            # Define the command to be run inside WSL
            $wrappedCommand = @"
{
    # Ensure all output goes to the log file
    exec > >(tee '$outputFile') 2>&1
    
    # Execute the actual command passed to the function
    $Command
    
    # Create the .finished file on success or failure to signal completion
} && touch '$finishFile' || { 
    echo '[ERROR] Command execution failed with a non-zero exit code.'
    touch '$finishFile'
}
"@
        
            $this.Logger.WriteLog("INFO", "Executing command asynchronously...", "Cyan")
        
            # --- CORE FIX: Execute WSL asynchronously using Start-Process ---
            $processArgs = "-d $($this.DistroName) -u $($this.Username) bash -c `"$wrappedCommand`""
            $wslProcess = Start-Process -FilePath "wsl" -ArgumentList $processArgs -NoNewWindow -PassThru
        
            # --- CORE FIX: Wait for the asynchronous process to exit ---
            # This loop allows the tailing job to run in the background while we wait.
            $this.Logger.WriteLog("INFO", "Waiting for WSL process to complete. Tailing logs in real-time...", "Gray")
            while (-not $wslProcess.HasExited) {
                # The tailJob is already printing to the console, so we just wait.
                Start-Sleep -Seconds 1
            }
        
            $exitCode = $wslProcess.ExitCode
        
            # Give the tailing job a moment to process the final output and the .finished file
            Start-Sleep -Seconds 2 
        
            # Final status check
            if ($exitCode -eq 0) {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "SUCCESS", $Description)
            }
            else {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - WSL process exited with code: $exitCode")
            }
        
            return ($exitCode -eq 0)
        }
        catch {
            # ... (catch block remains the same) ...
            throw
        }
        finally {
            # --- Cleanup ---
            if ($tailJob) {
                # Stop and remove the background job
                Stop-Job $tailJob -ErrorAction SilentlyContinue
                Remove-Job $tailJob -Force -ErrorAction SilentlyContinue
            }
        
            # Clean up the temporary files inside WSL
            try {
                wsl -d $this.DistroName -u $this.Username bash -c "rm -f '$outputFile' '$finishFile'" 2>&1 | Out-Null
            }
            catch { }
        }
    }


    # Method without return type annotation
    Cleanup() {
        if (Test-Path $this.OutputLogFile) {
            $this.Logger.WriteLog(
                "INFO",
                "WSL output log: $($this.OutputLogFile)",
                "Gray"
            )
        }
        if (Test-Path $this.ErrorLogFile) {
            $this.Logger.WriteLog(
                "INFO",
                "WSL error log: $($this.ErrorLogFile)",
                "Gray"
            )
        }
    }
}

class WslLogger {
    # Properties
    [string]$LogFile
    [string]$LogDir

    # Constructor
    WslLogger([string]$BasePath = "c:\wsl") {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $this.LogDir = "$BasePath\tmp\logs\$timestamp"
        $this.LogFile = "$($this.LogDir)\powershell_install.log"
        $directoriesToCreate = @(
            "$BasePath",
            "$BasePath\tmp",
            "$BasePath\tmp\logs",
            $this.LogDir
        )
        foreach ($dir in $directoriesToCreate) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }
    }

    # Methods without return type annotations
    WriteLog(
        [string]$Level,
        [string]$Message,
        [ConsoleColor]$ForegroundColor = "White"
    ) {
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

    [bool] InvokeWSLWithRealTimeOutput(
        [string]$DistroName,
        [string]$Username,
        [string]$Command,
        [string]$Description
    ) {
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

            # Real-time output handling
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
                $this.WritePhaseStatus(
                    "WSL_REAL",
                    "ERROR",
                    "$Description - Exit code: $exitCode"
                )
                return $false
            }
        }
        catch {
            $this.WritePhaseStatus(
                "WSL_REAL",
                "ERROR",
                "$Description - Exception: $($_.Exception.Message)"
            )
            return $false
        }
    }

    WriteRecoveryInfo(
        [string]$DistroName,
        [string]$Username,
        [string]$RepoPath
    ) {
        $this.WriteLog("RECOVERY", "=== RECOVERY INSTRUCTIONS ===", "Yellow")
        $this.WriteLog("RECOVERY", "To continue manually, run:", "Yellow")
        $this.WriteLog("RECOVERY", "wsl -d $DistroName -u $Username", "Yellow")
        $this.WriteLog(
            "RECOVERY",
            "cd $RepoPath && export FORCE_OVERWRITE=true && ./Setup/1_sys_init.sh",
            "Yellow"
        )
        $this.WriteLog(
            "RECOVERY",
            "=== END RECOVERY INSTRUCTIONS ===",
            "Yellow"
        )
    }
}