#!/bin/bash
#######--- START OF FILE ---#######
# Create logs directory
# logging.sh

# Force unbuffered output for real-time display
export PYTHONUNBUFFERED=1
export DEBIAN_FRONTEND=noninteractive


# Setup logging with detailed timestamps and categories
LOG_DIR="$HOME/.local/logs/$TIMESTAMP"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/sys_init.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

PHASE_MARKER_PREFIX="=== PHASE:"

init_logging() {
    # Create the header directly with command substitution
    cat >> "$LOGFILE" << EOF
=== Installation Log Started at $(date) ===
=== System Information ===
User: $(whoami)
Hostname: $(hostname)
WSL Version: $(wsl.exe --version 2>/dev/null || echo 'WSL version not available')
Kernel: $(uname -r)
Distribution: $(cat /etc/os-release | grep PRETTY_NAME)
Memory: $(free -h)
Disk Space: $(df -h /)
Network Status: $(ip addr show | grep 'inet ')
Current Shell: $SHELL
=== Environment Status ===
Working Directory: $(pwd)
Script Directory: $SCRIPT_DIR
==========================
EOF
    # Also output to stdout for PowerShell capture (with forced flush)
    {
        echo "=== Installation Log Started at $(date) ==="
        echo "=== System Information ==="
        echo "User: $(whoami)"
        echo "Hostname: $(hostname)"
        echo "Working Directory: $(pwd)"
        echo "Script Directory: $SCRIPT_DIR"
        echo "=========================="
    } | tee /dev/stderr
    
    # Force flush all output streams
    sync
}

# Add a phase marker function
print_phase_start() {
    local phase=$1
    local description=$2
    echo -e "${BLUE}${PHASE_MARKER_PREFIX} ${phase} START ===${NC} $description" >&2
    log_message "PHASE_START" "$phase" "$description"
    sync
    sleep 0.1  # Small delay to ensure PowerShell sees the marker
}

print_phase_end() {
    local phase=$1
    local status=$2  # SUCCESS or ERROR
    echo -e "${GREEN}${PHASE_MARKER_PREFIX} ${phase} ${status} ===${NC}" >&2
    log_message "PHASE_END" "$phase" "$status"
    sync
    sleep 0.1
}

log_message() {
    local level=$1
    local category=$2
    local message=$3
    local func="${FUNCNAME[2]:-main}"
    local timestamp
    
    # Use a more robust timestamp method
    if timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null); then
        : # Success
    else
        timestamp="TIMESTAMP_ERROR"
    fi
    
    local log_entry="[$timestamp] [$level] [$category] [$func] $message"
    
    # Try to write to log file with error handling
    if [[ -w "$LOGFILE" ]] && [[ -w "$(dirname "$LOGFILE")" ]]; then
        echo "$log_entry" >> "$LOGFILE" 2>/dev/null || {
            # Fallback to a different location if primary log fails
            echo "$log_entry" >> "/tmp/fallback_install.log" 2>/dev/null
        }
    else
        # Create fallback log location
        mkdir -p "/tmp" 2>/dev/null
        echo "$log_entry" >> "/tmp/fallback_install.log" 2>/dev/null
    fi
        
    # Always output to stdout for PowerShell capture with immediate flush
    echo "$log_entry" >&2
    sync

    # Always output to stdout for PowerShell capture
    if [[ -z "$POWERSHELL_EXECUTION" ]]; then
        echo "$log_entry"
    fi
}

print_status() {
    local category=$1
    local message=$2
    local func="${FUNCNAME[1]:-main}"
    echo -e "${BLUE}[STATUS]${NC} [$category] [$func] $message" >&2
    log_message "STATUS" "$category" "$message"

    sync
}

print_success() {
    local category=$1
    local message=$2
    local func="${FUNCNAME[1]:-main}"
    echo -e "${GREEN}[SUCCESS]${NC} [$category] [$func] $message" >&2
    log_message "SUCCESS" "$category" "$message"
    sync
}

print_warning() {
    local category=$1
    local message=$2
    local func="${FUNCNAME[1]:-main}"
    echo -e "${YELLOW}[WARNING]${NC} [$category] [$func] $message" >&2
    log_message "WARNING" "$category" "$message"
    sync
}

print_error() {
    local category=$1
    local message=$2
    local func="${FUNCNAME[1]:-main}"
    echo -e "${RED}[ERROR]${NC} [$category] [$func] $message" >&2
    log_message "ERROR" "$category" "$message"
    sync
}

execute_and_log() {
    local cmd="$1"
    local desc="$2"
    local category="${3:-COMMAND}"

    # Get caller context using BASH_SOURCE array
    local stack_trace=""
    for ((i=1; i<${#BASH_SOURCE[@]}; i++)); do
        local script=$(basename "${BASH_SOURCE[$i]}")
        local line="${BASH_LINENO[$i-1]}"
        local func="${FUNCNAME[$i]}"
        [[ "$func" != "main" ]] && stack_trace+="$script[${func}]:$line -> "
    done
    stack_trace+=$(basename "${BASH_SOURCE[0]}")

    # Log execution start with stack trace
    print_status "$category" "Stack trace: $stack_trace"
    print_status "$category" "Executing: $desc"
    
    # Fix the command logging - escape quotes properly
    local safe_cmd=$(printf '%q' "$cmd")
    log_message "COMMAND" "$category" "\$ $safe_cmd"

    # Execute with timing and error capture, with real-time output
    local start_time=$(date +%s)
    
    # Use a different approach for real-time output with proper error handling
    local output
    local exit_code
    
    if output=$(eval "$cmd" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ $exit_code -eq 0 ]; then
        log_message "SUCCESS" "$category" "[${FUNCNAME[1]}] Command completed successfully"
        log_message "OUTPUT" "$category" "[${FUNCNAME[1]}] Output: $output"
        log_message "TIMING" "$category" "[${FUNCNAME[1]}] Duration: ${duration}s"
        
        print_success "$category" "[${FUNCNAME[1]}] $desc completed (${duration}s)"
        return 0
    else
        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Command failed with exit code: $exit_code"
        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Stack trace: $stack_trace"
        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Failed command: $safe_cmd"
        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Description: $desc"
        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Duration: ${duration}s"
        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Output: $output"

        print_error "$category" "[${FUNCNAME[1]}] FAILED: $desc (${duration}s)"
        return $exit_code
    fi
}

execute_and_log_with_retry() {
    local cmd="$1"
    local max_attempts="${2:-3}"
    local delay="${3:-5}"
    local category="${4:-RETRY}"
    local attempt=1
    local start_time=$(date +%s)
    local func="${FUNCNAME[1]:-main}"

    while [ $attempt -le $max_attempts ]; do
        print_status "$category" "[$func] Attempt $attempt of $max_attempts"
        log_message "RETRY" "$category" "[$func] Executing attempt $attempt: $cmd"

        # Execute command and capture exit code properly
        local output
        local exit_code
        
        if output=$(eval "$cmd" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
        
        # Show output in real-time (simplified)
        if [ -n "$output" ]; then
            echo "$output" | while IFS= read -r line; do
                echo "$line"
                sync
            done
        fi

        if [ $exit_code -eq 0 ]; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            log_message "SUCCESS" "$category" "[$func] Succeeded on attempt $attempt (${duration}s)"
            log_message "TIMING" "$category" "[$func] Total duration: ${duration}s, Attempts: $attempt"
            print_success "$category" "[$func] Command succeeded on attempt $attempt (${duration}s)"
            
            return 0
        else
            local current_time=$(date +%s)
            local current_duration=$((current_time - start_time))
            
            log_message "WARNING" "$category" "[$func] Attempt $attempt failed with exit code: $exit_code"
            log_message "TIMING" "$category" "[$func] Current duration: ${current_duration}s"

            if [ $attempt -lt $max_attempts ]; then
                print_warning "$category" "[$func] Retrying in $delay seconds (attempt $attempt/$max_attempts, ${current_duration}s elapsed)"
                sleep $delay
            fi
        fi
        
        attempt=$((attempt + 1))
    done

    local final_time=$(date +%s)
    local total_duration=$((final_time - start_time))
    
    log_message "ERROR" "$category" "[$func] Failed after $max_attempts attempts (${total_duration}s)"
    print_error "$category" "[$func] Command failed after $max_attempts attempts (${total_duration}s)"
    
    return $exit_code
}

#######--- END OF FILE ---#######

