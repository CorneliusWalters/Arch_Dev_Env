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
    
        # Initialize variables that might be used in cleanup
        $readerJob = $null
        $pipePath = $null
    
        try {
            $this.Logger.WriteLog("INFO", "Starting: $Description", "Cyan")
        
            # Create a safer pipe name (avoid special characters)
            $safePipeName = "wsl_output_$([System.IO.Path]::GetRandomFileName().Replace('.',''))"
            $pipePath = "/tmp/$safePipeName"
            $windowsPipePath = "\\wsl$\$($this.DistroName)\tmp\$safePipeName"
        
            $this.Logger.WriteLog("INFO", "Creating named pipe: $pipePath", "Gray")
        
            # Test if /tmp is writable first
            $testWriteCmd = "test -w /tmp && echo 'TMP_WRITABLE' || echo 'TMP_NOT_WRITABLE'"
            $testResult = wsl -d $this.DistroName -u $this.Username bash -c $testWriteCmd
            $this.Logger.WriteLog("INFO", "Temp directory test: $testResult", "Gray")
        
            if ($testResult -notmatch "TMP_WRITABLE") {
                throw "Temp directory /tmp is not writable: $testResult"
            }
        
            # Check if mkfifo command exists
            $mkfifoTest = "command -v mkfifo && echo 'MKFIFO_EXISTS' || echo 'MKFIFO_MISSING'"
            $mkfifoResult = wsl -d $this.DistroName -u $this.Username bash -c $mkfifoTest
            $this.Logger.WriteLog("INFO", "mkfifo test: $mkfifoResult", "Gray")
        
            if ($mkfifoResult -notmatch "MKFIFO_EXISTS") {
                throw "mkfifo command not available: $mkfifoResult"
            }
        
            # Create the named pipe in WSL with verbose error reporting
            $createPipeCmd = "mkfifo '$pipePath' 2>&1 && echo 'PIPE_CREATED' || echo 'PIPE_FAILED'"
            $pipeResult = wsl -d $this.DistroName -u $this.Username bash -c $createPipeCmd
        
            $this.Logger.WriteLog("INFO", "Pipe creation result: $pipeResult", "Gray")
        
            if ($pipeResult -notmatch "PIPE_CREATED") {
                throw "Failed to create named pipe '$pipePath': $pipeResult"
            }
        
            # Verify pipe exists
            $verifyCmd = "test -p '$pipePath' && echo 'PIPE_EXISTS' || echo 'PIPE_MISSING'"
            $verifyResult = wsl -d $this.DistroName -u $this.Username bash -c $verifyCmd
            $this.Logger.WriteLog("INFO", "Pipe verification: $verifyResult", "Gray")
        
            if ($verifyResult -notmatch "PIPE_EXISTS") {
                throw "Pipe verification failed: $verifyResult"
            }
        
            $this.Logger.WriteLog("SUCCESS", "Named pipe created successfully: $pipePath", "Green")
            # Start background job to read from pipe and display output
            $readerJob = Start-Job -ScriptBlock {
                param($WindowsPipePath, $LogFile, $ErrorFile)
            
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
                
                    # Read from pipe and output in real-time
                    $reader = New-Object System.IO.StreamReader($WindowsPipePath)
                
                    while ($null -ne ($line = $reader.ReadLine())) {
                        # Break on our finish marker
                        if ($line -eq "COMMAND_FINISHED") {
                            break
                        }
                    
                        $timestamp = Get-Date -Format "HH:mm:ss"
                    
                        # Immediate console output with color coding
                        switch -Regex ($line) {
                            '^=== PHASE: (\w+) (START|SUCCESS|ERROR) ===' {
                                $phase = $matches[1]
                                $status = $matches[2]
                                $color = switch ($status) {
                                    "START" { "Cyan" }
                                    "SUCCESS" { "Green" }
                                    "ERROR" { "Red" }
                                }
                                Write-Host "[$timestamp] " -NoNewline -ForegroundColor White
                                Write-Host "PHASE $phase $status" -ForegroundColor $color
                            }
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
                    
                        # Log to files
                        try {
                            Add-Content -Path $LogFile -Value "WSL: $line" -Encoding UTF8 -ErrorAction SilentlyContinue
                        }
                        catch { }
                    
                        # Force console flush
                        [Console]::Out.Flush()
                    }
                
                    $reader.Close()
                
                }
                catch {
                    Write-Error "Pipe reader error: $($_.Exception.Message)"
                }
            } -ArgumentList $windowsPipePath, $this.Logger.LogFile, $this.OutputLogFile
        
            # Give the reader job a moment to start
            Start-Sleep -Milliseconds 500
        
            # Execute the command with output redirected to the pipe
            $wrappedCommand = "{ $Command; } 2>&1 | tee '$pipePath'; echo 'COMMAND_FINISHED' > '$pipePath'"
        
            $this.Logger.WriteLog("INFO", "Executing command with pipe output...", "Cyan")
        
            # Run the actual command
            $result = wsl -d $this.DistroName -u $this.Username bash -c $wrappedCommand
            $exitCode = $LASTEXITCODE
        
            # Output any result that wasn't captured by the pipe (shouldn't be much with tee)
            if (-not [string]::IsNullOrWhiteSpace($result)) {
                $this.Logger.WriteLog("INFO", "Additional command output: $result", "Gray")
                Write-Host $result -ForegroundColor White
            }
        
            # Wait for reader job to finish (with timeout)
            $jobTimeout = 30
            $readerJob | Wait-Job -Timeout $jobTimeout | Out-Null
        
            # Get any remaining output from the job
            if ($readerJob.State -eq "Completed") {
                $jobOutput = Receive-Job $readerJob
                if ($jobOutput) {
                    Write-Host $jobOutput -ForegroundColor White
                }
            }
        
            # Cleanup
            if ($readerJob) {
                Remove-Job $readerJob -Force -ErrorAction SilentlyContinue
            }
        
            # Remove the pipe
            if ($pipePath) {
                try {
                    wsl -d $this.DistroName -u $this.Username bash -c "rm -f '$pipePath'" | Out-Null
                }
                catch { }
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
        
            return $false
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