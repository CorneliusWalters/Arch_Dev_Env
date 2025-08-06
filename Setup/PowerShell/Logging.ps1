class WSLProcessCapture {
    [PSCustomObject]$Logger
    [string]$DistroName
    [string]$Username
    [string]$OutputLogFile
    [string]$ErrorLogFile
    [string]$PipeName
    
    WSLProcessCapture([PSCustomObject]$Logger, [string]$DistroName, [string]$Username) {
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
            $this.Logger.WriteLog("INFO", "Using file-based streaming approach", "Cyan")
            return $this.ExecuteWithFileTailing($Command, $Description)
            
        }
        catch {
            $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exception: $($_.Exception.Message)")
            return $false
        }
    }

    [bool] ExecuteWithFileTailing([string]$Command, [string]$Description) {
        $outputFile = "/tmp/wsl_output_$([System.IO.Path]::GetRandomFileName().Replace('.',''))"
        $finishFile = "$outputFile.finished"
        $windowsOutputFile = "\\wsl$\$($this.DistroName)$outputFile"
        $tailJob = $null
    
        try {
            $this.Logger.WriteLog("INFO", "Using enhanced file-based streaming: $outputFile", "Gray")
        
            # Start enhanced background job with better phase detection
            $tailJob = Start-Job -ScriptBlock {
                param($FilePath, $FinishPath, $LogPath, $DistroName)
            
                $lastSize = 0
                $maxWaitTime = 600
                $startTime = Get-Date
                $currentPhase = ""
                $phaseStartTime = Get-Date
                $consecutiveEmptyReads = 0
                $maxConsecutiveEmpty = 50
            
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
                                    
                                        # Enhanced phase detection with simpler regex
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
                                        elseif ($trimmedLine.StartsWith('>>> PROGRESS: [') -and $trimmedLine.Contains(']')) {
                                            if ($trimmedLine -match '>>> PROGRESS: \[(\d+)/(\d+)\] (.+) - (.+)') {
                                                $current = [int]$matches[1]
                                                $total = [int]$matches[2]
                                                $phase = $matches[3]
                                                $action = $matches[4]
                                                $percentage = [math]::Round(($current / $total) * 100, 1)
                                                
                                                Write-Host ""
                                                Write-Host "📊 PROGRESS: " -NoNewline -ForegroundColor Magenta
                                                $progressText = "[$current/$total] ($percentage%)"
                                                Write-Host $progressText -NoNewline -ForegroundColor Cyan
                                                Write-Host " $phase - $action" -ForegroundColor White
                                                continue
                                            }
                                        }
                                        elseif ($trimmedLine -match '^>>> PHASE_SEPARATOR <<<') {
                                            Write-Host ""
                                            Write-Host (("-" * 40) + " PHASE BREAK " + ("-" * 40)) -ForegroundColor DarkGray
                                            Write-Host ""
                                            Start-Sleep -Milliseconds 300
                                            continue
                                        }
                                        elseif ($trimmedLine -match '^================== (EXECUTING|COMPLETED): (.+) ==================') {
                                            $action = $matches[1]
                                            $phaseName = $matches[2]
                                            if ($action -eq "EXECUTING") {
                                                Write-Host "🔧 $action" + ": " -NoNewline -ForegroundColor Blue
                                                Write-Host "$phaseName" -ForegroundColor White -BackgroundColor DarkBlue
                                            }
                                            else {
                                                Write-Host "✅ $action" + ": " -NoNewline -ForegroundColor Green
                                                Write-Host "$phaseName" -ForegroundColor White -BackgroundColor DarkGreen
                                            }
                                            continue
                                        }
                                        elseif ($trimmedLine -match '^=== PHASE:.*START ===') {
                                            Write-Host ""
                                            Write-Host "🚀 " -NoNewline -ForegroundColor Green
                                            Write-Host "$trimmedLine" -ForegroundColor Magenta
                                            continue
                                        }
                                        elseif ($trimmedLine -match '^=== PHASE:.*SUCCESS ===') {
                                            Write-Host "✅ " -NoNewline -ForegroundColor Green
                                            Write-Host "$trimmedLine" -ForegroundColor Green
                                            Write-Host ""
                                            continue
                                        }
                                        elseif ($trimmedLine -match '^\[ERROR\]|^ERROR:') { 
                                            Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                            Write-Host "❌ $line" -ForegroundColor Red
                                        }
                                        elseif ($trimmedLine -match '^\[SUCCESS\]|^SUCCESS:') { 
                                            Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                            Write-Host "✅ $line" -ForegroundColor Green
                                        }
                                        elseif ($trimmedLine -match '^\[STATUS\]|^STATUS:') { 
                                            Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                            Write-Host "ℹ️  $line" -ForegroundColor Cyan
                                        }
                                        elseif ($trimmedLine -match '^\[WARNING\]|^WARNING:') { 
                                            Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                            Write-Host "⚠️  $line" -ForegroundColor Yellow
                                        }
                                        elseif ($trimmedLine -match '^===.*===') {
                                            Write-Host "$line" -ForegroundColor Cyan
                                        }
                                        else { 
                                            Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
                                            Write-Host "$line" -ForegroundColor White
                                        }
                                    
                                        # Force output flush
                                        [Console]::Out.Flush()
                                        [Console]::Error.Flush()
                                    
                                        # Log to files
                                        try {
                                            $logLine = "$timestamp WSL: $line"
                                            Add-Content -Path $LogPath -Value $logLine -ErrorAction SilentlyContinue -Encoding UTF8
                                        }
                                        catch { 
                                            # Ignore logging errors
                                        }
                                    }
                                }
                                $lastSize = $content.Length
                            }
                            else {
                                $consecutiveEmptyReads++
                                if ($consecutiveEmptyReads -gt $maxConsecutiveEmpty) {
                                    if (Test-Path $FinishPath) {
                                        break
                                    }
                                }
                            }
                        }
                        catch {
                            $consecutiveEmptyReads++
                        }
                    }
                    else {
                        $consecutiveEmptyReads++
                    }
                
                    # Check if we should stop
                    if (Test-Path $FinishPath) {
                        Start-Sleep -Milliseconds 1000
                        break
                    }
                
                    # Adaptive sleep
                    if ($consecutiveEmptyReads -lt 5) {
                        Start-Sleep -Milliseconds 50
                    }
                    else {
                        Start-Sleep -Milliseconds 200
                    }
                }
                
                # Final message
                Write-Host ""
                Write-Host "📋 Background job completed for $DistroName" -ForegroundColor Gray
                
            } -ArgumentList $windowsOutputFile, "\\wsl$\$($this.DistroName)$finishFile", $this.Logger.LogFile, $this.DistroName

            # Give the tail job a moment to start
            Start-Sleep -Milliseconds 750
            
            # Execute command with output redirection
            $wrappedCommand = @"
{
    exec > >(tee '$outputFile') 2>&1
    
    echo '### PHASE_BOUNDARY ###'
    echo '>>> PHASE_START: COMMAND_EXECUTION'
    echo 'DESCRIPTION: $Description'
    echo '### PHASE_BOUNDARY ###'
    
    $Command
    
    echo '### PHASE_BOUNDARY ###'
    echo '<<< PHASE_END: COMMAND_EXECUTION'
    echo '### PHASE_BOUNDARY ###'
    echo '=== COMMAND COMPLETED ==='
} && touch '$finishFile' || { 
    echo '=== COMMAND FAILED ===' 
    echo '[ERROR] Command execution failed'
    touch '$finishFile'
}
"@
            
            $this.Logger.WriteLog("INFO", "Executing command with enhanced streaming...", "Cyan")
            
            # Run the actual command
            $result = wsl -d $this.DistroName -u $this.Username bash -c $wrappedCommand
            $exitCode = $LASTEXITCODE
            
            # Wait for tail job to finish
            $waitStartTime = Get-Date
            $jobCompleted = $false
            
            while (((Get-Date) - $waitStartTime).TotalSeconds -lt 45) {
                if ($tailJob.State -eq "Completed") {
                    $jobCompleted = $true
                    break
                }
                Start-Sleep -Milliseconds 500
                Write-Host "." -NoNewline -ForegroundColor Gray
            }
            
            if ($jobCompleted) {
                Write-Host " ✅" -ForegroundColor Green
            }
            else {
                Write-Host " ⏰" -ForegroundColor Yellow
            }
            
            # Get any remaining output
            try {
                $jobOutput = Receive-Job $tailJob -ErrorAction SilentlyContinue
                if ($jobOutput) {
                    Write-Host $jobOutput -ForegroundColor White
                }
            }
            catch { 
                # Ignore job output errors
            }
            
            # Cleanup
            if ($tailJob) {
                Remove-Job $tailJob -Force -ErrorAction SilentlyContinue
            }
            
            # Clean up files
            try {
                wsl -d $this.DistroName -u $this.Username bash -c "rm -f '$outputFile' '$finishFile'" 2>&1 | Out-Null
            }
            catch { }
            
            # Final status
            if ($exitCode -eq 0) {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "SUCCESS", $Description)
            }
            else {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exit code: $exitCode")
            }
            
            return ($exitCode -eq 0)
            
        }
        catch {
            # Cleanup on error
            if ($tailJob) {
                try {
                    Remove-Job $tailJob -Force -ErrorAction SilentlyContinue
                }
                catch { }
            }
            
            try {
                wsl -d $this.DistroName -u $this.Username bash -c "rm -f '$outputFile' '$finishFile'" 2>&1 | Out-Null
            }
            catch { }
            
            throw
        }
    }
    
    # Method without return type annotation
    Cleanup() {
        if (Test-Path $this.OutputLogFile) {
            $this.Logger.WriteLog("INFO", "WSL output log: $($this.OutputLogFile)", "Gray")
        }
        if (Test-Path $this.ErrorLogFile) {
            $this.Logger.WriteLog("INFO", "WSL error log: $($this.ErrorLogFile)", "Gray")
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
        $directoriesToCreate = @("$BasePath", "$BasePath\tmp", "$BasePath\tmp\logs", $this.LogDir)
        foreach ($dir in $directoriesToCreate) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }
    }

    # Methods without return type annotations
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
                $this.WritePhaseStatus("WSL_REAL", "ERROR", "$Description - Exit code: $exitCode")
                return $false
            }
            
        }
        catch {
            $this.WritePhaseStatus("WSL_REAL", "ERROR", "$Description - Exception: $($_.Exception.Message)")
            return $false
        }
    }
    
    WriteRecoveryInfo([string]$DistroName, [string]$Username, [string]$RepoPath) {
        $this.WriteLog("RECOVERY", "=== RECOVERY INSTRUCTIONS ===", "Yellow")
        $this.WriteLog("RECOVERY", "To continue manually, run:", "Yellow")
        $this.WriteLog("RECOVERY", "wsl -d $DistroName -u $Username", "Yellow")
        $this.WriteLog("RECOVERY", "cd $RepoPath && export FORCE_OVERWRITE=true && ./Setup/1_sys_init.sh", "Yellow")
        $this.WriteLog("RECOVERY", "=== END RECOVERY INSTRUCTIONS ===", "Yellow")
    }    
}