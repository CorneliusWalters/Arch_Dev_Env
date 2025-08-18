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

# Phase Markers
PHASE_MARKER_PREFIX="### PHASE_BOUNDARY ###"
PHASE_START_MARKER=">>> PHASE_START"
PHASE_END_MARKER="<<< PHASE_END"

init_logging() {
    # Create the header directly with command substitution
    cat >>"$LOGFILE" <<EOF
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
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Multiple output methods to ensure visibility
    {
        echo ""
        echo "$PHASE_MARKER_PREFIX"
        echo "$PHASE_START_MARKER: $phase"
        echo "TIMESTAMP: $timestamp"
        echo "DESCRIPTION: $description"
        echo "$PHASE_MARKER_PREFIX"
        echo ""
    } | tee /dev/stderr

    # Aggressive flushing
    sync
    sleep 0.2
    printf "\n" >&2 # Extra newline to stderr
    sync
}

print_phase_end() {
    local phase=$1
    local status=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    {
        echo ""
        echo "$PHASE_MARKER_PREFIX"
        echo "$PHASE_END_MARKER: $phase"
        echo "STATUS: $status"
        echo "TIMESTAMP: $timestamp"
        echo "$PHASE_MARKER_PREFIX"
        echo ""
    } | tee /dev/stderr

    sync
    sleep 0.2
    printf "\n" >&2
    sync
}

# Add a progress indicator function
print_progress() {
    local current=$1
    local total=$2
    local phase=$3
    local action=$4

    {
        echo ">>> PROGRESS: [$current/$total] $phase - $action"
    } | tee /dev/stderr
    sync
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
        echo "$log_entry" >>"$LOGFILE" 2>/dev/null || {
            # Fallback to a different location if primary log fails
            echo "$log_entry" >>"/tmp/fallback_install.log" 2>/dev/null
        }
    else
        # Create fallback log location
        mkdir -p "/tmp" 2>/dev/null
        echo "$log_entry" >>"/tmp/fallback_install.log" 2>/dev/null
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
    local func="${FUNCNAME[1]:-main}"

    # Announce what we are about to do. This goes to the log file and the console.
    print_status "$category" "Executing: $desc"
    log_message "COMMAND" "$category" "[$func] \$ $cmd"

    local start_time
    start_time=$(date +%s)

    # --- CORE CHANGE ---
    # Execute the command directly. Its stdout/stderr will stream to the
    # parent process (the PowerShell job) in real-time.
    # We capture the exit code immediately after.
    eval "$cmd"
    local exit_code=$?

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # --- POST-EXECUTION SUMMARY ---
    # After the command's own output has finished streaming, we print our summary.
    if [ $exit_code -eq 0 ]; then
        # The command's output is already on the screen. We just add our success message.
        print_success "$category" "$desc completed successfully (${duration}s)."
        # Add a more detailed entry to the file log for posterity.
        log_message "SUCCESS" "$category" "[$func] Command finished. Exit Code: 0, Duration: ${duration}s"
        return 0
    else
        # The command's error messages are already on the screen. We add our failure summary.
        print_error "$category" "FAILED: $desc (Exit Code: $exit_code, Duration: ${duration}s)."
        log_message "ERROR" "$category" "[$func] Command failed. Exit Code: $exit_code, Duration: ${duration}s"
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
