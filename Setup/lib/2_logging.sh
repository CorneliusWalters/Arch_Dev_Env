#!/bin/bash
#######--- START OF FILE ---#######
# Create logs directory
# logging.sh


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

init_logging() {
    local header_info=$(cat << 'EOF'
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
)

    # Evaluate the variables in the header
    local evaluated_header=$(eval "echo \"$header_info\"")
    
    # Write to WSL log file
    echo "$evaluated_header" >> "$LOGFILE"
    
    # Also send to stdout for PowerShell to capture
    echo "$evaluated_header"
}

log_message() {
    local level=$1
    local category=$2
    local message=$3
    local func="${FUNCNAME[2]:-main}"  # Get the calling function, default to 'main'
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] [$category] [$func] $message"
    
    # Write to WSL log file
    echo "$log_entry" >> "$LOGFILE"
    echo "$log_entry"

}

print_status() {
    local category=$1
    local message=$2
    local func="${FUNCNAME[1]:-main}"
    echo -e "${BLUE}[STATUS]${NC} [$category] [$func] $message" >&2
    log_message "STATUS" "$category" "$message"
}

print_success() {
    local category=$1
    local message=$2
    local func="${FUNCNAME[1]:-main}"
    echo -e "${GREEN}[SUCCESS]${NC} [$category] [$func] $message" >&2
    log_message "SUCCESS" "$category" "$message"
}

print_warning() {
    local category=$1
    local message=$2
    local func="${FUNCNAME[1]:-main}"
    echo -e "${YELLOW}[WARNING]${NC} [$category] [$func] $message" >&2
    log_message "WARNING" "$category" "$message"
}

print_error() {
    local category=$1
    local message=$2
    local func="${FUNCNAME[1]:-main}"
    echo -e "${RED}[ERROR]${NC} [$category] [$func] $message" >&2
    log_message "ERROR" "$category" "$message"
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
    log_message "COMMAND" "$category" "$ $cmd"

    # Execute with timing and error capture
    local start_time=$(date +%s)
    if output=$( { eval "$cmd"; } 2>&1 ); then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_message "SUCCESS" "$category" "[${FUNCNAME[1]}] Command completed successfully"
        log_message "OUTPUT" "$category" "[${FUNCNAME[1]}] Output:\n$output"
        log_message "TIMING" "$category" "[${FUNCNAME[1]}] Duration: ${duration}s"
        
        print_success "$category" "[${FUNCNAME[1]}] $desc completed (${duration}s)"
        return 0
    else
        local exit_code=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Command failed with exit code: $exit_code"
        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Stack trace: $stack_trace"
        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Failed command: $cmd"
        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Description: $desc"
        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Duration: ${duration}s"
        log_message "ERROR" "$category" "[${FUNCNAME[1]}] Output:\n$output"

        print_error "$category" "[${FUNCNAME[1]}] FAILED: $desc (${duration}s)"
        return $exit_code
    fi
}

execute_and_log_with_retry() {
    local cmd="$1"
    local max_attempts="${2:-3}"  # Default to 3 attempts
    local delay="${3:-5}"        # Default to 5 second delay
    local category="${4:-RETRY}"
    local attempt=1
    local start_time=$(date +%s)
    local func="${FUNCNAME[1]:-main}"

    while [ $attempt -le $max_attempts ]; do
        print_status "$category" "[$func] Attempt $attempt of $max_attempts"
        log_message "RETRY" "$category" "[$func] Executing attempt $attempt: $cmd"

        if output=$( { eval "$cmd"; } 2>&1 ); then
            local exit_code=$?
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            log_message "SUCCESS" "$category" "[$func] Succeeded on attempt $attempt (${duration}s)"
            log_message "OUTPUT" "$category" "[$func] Output:\n$output"
            log_message "TIMING" "$category" "[$func] Total duration: ${duration}s, Attempts: $attempt"
            print_success "$category" "[$func] Command succeeded on attempt $attempt (${duration}s)"
            
            # Add performance logging if duration is significant
            if [ $duration -gt 5 ]; then
                log_message "PERF" "$category" "[$func] Command took ${duration}s to complete after $attempt attempts"
            fi
            
            return $exit_code  # Return actual exit code instead of 0
        else
            local exit_code=$?
            local current_time=$(date +%s)
            local current_duration=$((current_time - start_time))
            
            log_message "WARNING" "$category" "[$func] Attempt $attempt failed with exit code: $exit_code"
            log_message "WARNING" "$category" "[$func] Output:\n$output"
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
    log_message "ERROR" "$category" "[$func] Final exit code: $exit_code"
    print_error "$category" "[$func] Command failed after $max_attempts attempts (${total_duration}s)"
    
    return $exit_code  # Return the last exit code
}

#######--- END OF FILE ---#######

