# Setup/PowerShell/Logging.ps1


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
            
            # Check if mkfifo command exists (fixed logic)
            $mkfifoTest = "command -v mkfifo >/dev/null 2>&1 && echo 'MKFIFO_OK' || echo 'MKFIFO_MISSING'"
            $mkfifoResult = wsl -d $this.DistroName -u $this.Username bash -c $mkfifoTest
            $this.Logger.WriteLog("INFO", "mkfifo test result: '$mkfifoResult'", "Gray")
            
            # Try named pipes first if mkfifo is available
            if ($mkfifoResult.Trim() -eq "MKFIFO_OK") {
                $this.Logger.WriteLog("INFO", "Attempting named pipe approach", "Cyan")
                return $this.ExecuteWithNamedPipe($Command, $Description)
            }
            else {
                $this.Logger.WriteLog("WARNING", "mkfifo not available, using file-based approach", "Yellow")
                return $this.ExecuteWithFileTailing($Command, $Description)
            }
            
        }
        catch {
            $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Exception: $($_.Exception.Message)")
            
            # Fallback to file approach on any error
            $this.Logger.WriteLog("WARNING", "Named pipe failed, falling back to file tailing", "Yellow")
            try {
                return $this.ExecuteWithFileTailing($Command, $Description)
            }
            catch {
                $this.Logger.WritePhaseStatus("WSL_EXEC", "ERROR", "$Description - Both methods failed: $($_.Exception.Message)")
                return $false
            }
        }
    }

    [bool] ExecuteWithNamedPipe([string]$Command, [string]$Description) {
        # Initialize variables that might be used in cleanup
        $readerJob = $null
        $pipePath = $null
        
        try {
            # Create a safer pipe name (avoid special characters)
            $safePipeName = "wsl_output_$([System.IO.Path]::GetRandomFileName().Replace('.',''))"
            $pipePath = "/tmp/$safePipeName"
            $windowsPipePath = "\\wsl$\$($this.DistroName)\tmp\$safePipeName"
            
            $this.Logger.WriteLog("INFO", "Creating named pipe: $pipePath", "Gray")
            
            # Create the named pipe in WSL with verbose error reporting
            $createPipeCmd = "mkfifo '$pipePath' 2>&1 && echo 'PIPE_CREATED' || echo 'PIPE_FAILED'"
            $pipeResult = wsl -d $this.DistroName -u $this.Username bash -c $createPipeCmd
            
            $this.Logger.WriteLog("INFO", "Pipe creation result: $pipeResult", "Gray")
            
            if ($pipeResult -notmatch "PIPE_CREATED") {
                throw "Failed to create named pipe '$pipePath': $pipeResult"
            }
            
            # Start background job to read from pipe
            $readerJob = Start-Job -ScriptBlock {
                param($WindowsPipePath, $LogFile)
                
                try {
                    # Wait for pipe to be available
                    $timeout = 30
                    $elapsed = 0
                    while (-not (Test-Path $WindowsPipePath) -and $elapsed -lt $timeout) {
                        Start-Sleep -Milliseconds 500
                        $elapsed += 0.5
                    }
                    
                    if (-not (Test-Path $WindowsPipePath)) {
                        Write-Error "Pipe not available after timeout"
                        return
                    }
                    
                    # Read from pipe
                    $reader = New-Object System.IO.StreamReader($WindowsPipePath)
                    
                    while ($null -ne ($line = $reader.ReadLine())) {
                        if ($line -eq "COMMAND_FINISHED") {
                            break
                        }
                        
                        $timestamp = Get-Date -Format "HH:mm:ss"
                        
                        # Color coding
                        switch -Regex ($line) {
                            '^\[ERROR\]|ERROR:' { 
                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                Write-Host "$line" -ForegroundColor Red
                            }
                            '^\[SUCCESS\]|SUCCESS:' { 
                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                Write-Host "$line" -ForegroundColor Green
                            }
                            '^\[STATUS\]|STATUS:' { 
                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                Write-Host "$line" -ForegroundColor Cyan
                            }
                            '^\[WARNING\]|WARNING:' { 
                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                Write-Host "$line" -ForegroundColor Yellow
                            }
                            default { 
                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
                                Write-Host "$line" -ForegroundColor White
                            }
                        }
                        
                        [Console]::Out.Flush()
                        
                        # Log to files
                        try {
                            Add-Content -Path $LogFile -Value "WSL: $line" -ErrorAction SilentlyContinue
                        }
                        catch { }
                    }
                    
                    $reader.Close()
                    
                }
                catch {
                    Write-Error "Pipe reader error: $($_.Exception.Message)"
                }
            } -ArgumentList $windowsPipePath, $this.Logger.LogFile
            
            # Give the reader job a moment to start
            Start-Sleep -Milliseconds 500
            
            # Execute the command
            $wrappedCommand = "{ $Command; } 2>&1 | tee '$pipePath'; echo 'COMMAND_FINISHED' > '$pipePath'"
            $result = wsl -d $this.DistroName -u $this.Username bash -c $wrappedCommand
            $exitCode = $LASTEXITCODE
            
            # Wait for reader job to finish
            $readerJob | Wait-Job -Timeout 30 | Out-Null
            
            # Get any remaining output
            if ($readerJob.State -eq "Completed") {
                $jobOutput = Receive-Job $readerJob -ErrorAction SilentlyContinue
                if ($jobOutput) {
                    Write-Host $jobOutput -ForegroundColor White
                }
            }
            
            # Cleanup
            if ($readerJob) {
                Remove-Job $readerJob -Force -ErrorAction SilentlyContinue
            }
            
            if ($pipePath) {
                try {
                    wsl -d $this.DistroName -u $this.Username bash -c "rm -f '$pipePath'" 2>&1 | Out-Null
                }
                catch { }
            }
            
            return ($exitCode -eq 0)
            
        }
        catch {
            # Cleanup on error
            if ($readerJob) {
                try {
                    Remove-Job $readerJob -Force -ErrorAction SilentlyContinue
                }
                catch { }
            }
            
            if ($pipePath) {
                try {
                    wsl -d $this.DistroName -u $this.Username bash -c "rm -f '$pipePath'" 2>&1 | Out-Null
                }
                catch { }
            }
            
            throw
        }
    }

    [bool] ExecuteWithFileTailing([string]$Command, [string]$Description) {
        $outputFile = "/tmp/wsl_output_$([System.IO.Path]::GetRandomFileName().Replace('.',''))"
        $finishFile = "$outputFile.finished"
        $windowsOutputFile = "\\wsl$\$($this.DistroName)$outputFile"
        $tailJob = $null
        
        try {
            $this.Logger.WriteLog("INFO", "Using file-based streaming: $outputFile", "Gray")
            
            # Start background job to tail the file
            $tailJob = Start-Job -ScriptBlock {
                param($FilePath, $FinishPath, $LogPath)
                
                $lastSize = 0
                $maxWaitTime = 600  # 10 minutes timeout
                $startTime = Get-Date
                
                while (((Get-Date) - $startTime).TotalSeconds -lt $maxWaitTime) {
                    if (Test-Path $FilePath) {
                        try {
                            $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
                            if ($content -and $content.Length -gt $lastSize) {
                                $newContent = $content.Substring($lastSize)
                                $lines = $newContent -split "`r?`n"
                                
                                foreach ($line in $lines) {
                                    if (-not [string]::IsNullOrWhiteSpace($line)) {
                                        $timestamp = Get-Date -Format "HH:mm:ss"
                                        
                                        # Color coding
                                        switch -Regex ($line.Trim()) {
                                            '^\[ERROR\]|ERROR:' { 
                                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                                Write-Host "$line" -ForegroundColor Red
                                            }
                                            '^\[SUCCESS\]|SUCCESS:' { 
                                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                                Write-Host "$line" -ForegroundColor Green
                                            }
                                            '^\[STATUS\]|STATUS:' { 
                                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                                Write-Host "$line" -ForegroundColor Cyan
                                            }
                                            '^\[WARNING\]|WARNING:' { 
                                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                                Write-Host "$line" -ForegroundColor Yellow
                                            }
                                            '^=== PHASE:' {
                                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                                Write-Host "$line" -ForegroundColor Magenta
                                            }
                                            default { 
                                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
                                                Write-Host "$line" -ForegroundColor White
                                            }
                                        }
                                        
                                        [Console]::Out.Flush()
                                        
                                        # Log it
                                        try {
                                            Add-Content -Path $LogPath -Value "WSL: $line" -ErrorAction SilentlyContinue
                                        }
                                        catch { }
                                    }
                                }
                                $lastSize = $content.Length
                            }
                        }
                        catch {
                            # Ignore file read errors during active writing
                        }
                    }
                    
                    # Check if we should stop
                    if (Test-Path $FinishPath) {
                        Start-Sleep -Milliseconds 1000  # Give final output time
                        break
                    }
                    
                    Start-Sleep -Milliseconds 200
                }
            } -ArgumentList $windowsOutputFile, "\\wsl$\$($this.DistroName)$finishFile", $this.Logger.LogFile
            
            # Give the tail job a moment to start
            Start-Sleep -Milliseconds 500
            
            # Execute command with output redirection
            $wrappedCommand = @"
{
    exec > >(tee '$outputFile') 2>&1
    $Command
    echo "=== COMMAND COMPLETED ==="
} && touch '$finishFile' || { echo "=== COMMAND FAILED ==="; touch '$finishFile'; }
"@
            
            $this.Logger.WriteLog("INFO", "Executing command with file streaming...", "Cyan")
            
            # Run the actual command
            $result = wsl -d $this.DistroName -u $this.Username bash -c $wrappedCommand
            $exitCode = $LASTEXITCODE
            
            # Wait for tail job to finish
            $tailJob | Wait-Job -Timeout 30 | Out-Null
            
            # Get any remaining output
            try {
                $jobOutput = Receive-Job $tailJob -ErrorAction SilentlyContinue
                if ($jobOutput) {
                    Write-Host $jobOutput -ForegroundColor White
                }
            }
            catch { }
            
            # Cleanup
            if ($tailJob) {
                Remove-Job $tailJob -Force -ErrorAction SilentlyContinue
            }
            
            # Clean up files
            try {
                wsl -d $this.DistroName -u $this.Username bash -c "rm -f '$outputFile' '$finishFile'" 2>&1 | Out-Null
            }
            catch { }
            
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