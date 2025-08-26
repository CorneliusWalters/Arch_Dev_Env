#!/bin/bash
###     file name: 2_logging.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.
# shellcheck disable=SC2155
# shellcheck disable=SC2034

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
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	# Create the header in the log file
	cat >>"$LOGFILE" <<EOF
=== Installation Log Started at $timestamp ===
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
	# Output to stderr for PowerShell capture (single stream for consistency)
	echo "=== Installation Log Started at $timestamp ===" >&2
	echo "=== System Information ===" >&2
	echo "User: $(whoami)" >&2
	echo "Hostname: $(hostname)" >&2
	echo "Working Directory: $(pwd)" >&2
	echo "Script Directory: $SCRIPT_DIR" >&2
	echo "==========================" >&2
	sync
}

print_phase_start() {
	local phase=$1
	local description=$2
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	echo "" >&2                     # Blank line before phase
	echo "$PHASE_MARKER_PREFIX" >&2 # ### PHASE_BOUNDARY ###
	echo "$PHASE_START_MARKER: $phase" >&2
	echo "TIMESTAMP: $timestamp" >&2
	echo "DESCRIPTION: $description" >&2
	echo "$PHASE_MARKER_PREFIX" >&2 # ### PHASE_BOUNDARY ###
	echo "" >&2                     # Blank line after phase
	sync
}

print_phase_end() {
	local phase=$1
	local status=$2
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	echo "" >&2                     # Blank line before phase
	echo "$PHASE_MARKER_PREFIX" >&2 # ### PHASE_BOUNDARY ###
	echo "$PHASE_END_MARKER: $phase" >&2
	echo "STATUS: $status" >&2
	echo "TIMESTAMP: $timestamp" >&2
	echo "$PHASE_MARKER_PREFIX" >&2 # ### PHASE_BOUNDARY ###
	echo "" >&2                     # Blank line after phase
	sync
}

print_progress() {
	local current=$1
	local total=$2
	local phase=$3
	local action=$4
	echo ">>> PROGRESS: [$current/$total] $phase - $action" >&2 # Send to stderr
	sync
}

log_message() {
	local level=$1
	local category=$2
	local message=$3
	local func="${FUNCNAME[2]:-main}"
	local timestamp

	if timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null); then :; else timestamp="TIMESTAMP_ERROR"; fi

	local log_entry="[$timestamp] [$level] [$category] [$func] $message"

	if [[ -w "$LOGFILE" ]] && [[ -w "$(dirname "$LOGFILE")" ]]; then
		echo "$log_entry" >>"$LOGFILE" 2>/dev/null || {
			echo "$log_entry" >>"/tmp/fallback_install.log" 2>/dev/null
		}
	else
		mkdir -p "/tmp" 2>/dev/null
		echo "$log_entry" >>"/tmp/fallback_install.log" 2>/dev/null
	fi

	# Send all formatted log_message output to PowerShell's stderr (OutputDataReceived)
	echo "[$timestamp] [$level] [$category] $message" >&2
	sync
}

print_status() {
	local category=$1
	local message=$2
	log_message "STATUS" "$category" "$message"
}
print_success() {
	local category=$1
	local message=$2
	log_message "SUCCESS" "$category" "$message"
}
print_warning() {
	local category=$1
	local message=$2
	log_message "WARNING" "$category" "$message"
}
print_error() {
	local category=$1
	local message=$2
	log_message "ERROR" "$category" "$message"
}

execute_and_log() {
	local cmd="$1"
	local desc="$2"
	local category="${3:-COMMAND}"
	local func="${FUNCNAME[1]:-main}"

	log_message "STATUS" "$category" "Executing: $desc"
	log_message "COMMAND" "$category" "[$func] \$ $cmd"

	local start_time=$(date +%s)

	# Execute the command directly, allowing its stdout/stderr to stream.
	eval "$cmd" >&2 # Direct raw command output to stderr so PowerShell captures it.
	local exit_code=$?

	local end_time=$(date +%s)
	local duration=$((end_time - start_time))

	if [ $exit_code -eq 0 ]; then
		log_message "SUCCESS" "$category" "$desc completed successfully (${duration}s)."
		log_message "TIMING" "$category" "[$func] Command finished. Exit Code: 0, Duration: ${duration}s"
		return 0
	else
		log_message "ERROR" "$category" "FAILED: $desc (Exit Code: $exit_code, Duration: ${duration}s)."
		log_message "TIMING" "$category" "[$func] Command failed. Exit Code: $exit_code, Duration: ${duration}s"
		return $exit_code
	fi
}

execute_and_log_with_retry() {
	local cmd="$1"
	local max_attempts="${2:-3}"
	local delay="${3:-5}"
	local category="${4:-RETRY}"
	local attempt=1
	local exit_code=0
	local func="${FUNCNAME[1]:-main}"

	while [ $attempt -le $max_attempts ]; do
		log_message "STATUS" "$category" "[$func] Attempt $attempt of $max_attempts for: $cmd"

		# Execute command directly for streaming output
		eval "$cmd" >&2 # Direct raw command output to stderr so PowerShell captures it.
		exit_code=$?

		if [ $exit_code -eq 0 ]; then
			log_message "SUCCESS" "$category" "[$func] Succeeded on attempt $attempt."
			return 0
		fi

		if [ $attempt -lt $max_attempts ]; then
			log_message "WARNING" "$category" "[$func] Attempt $attempt failed. Retrying in $delay seconds..."
			sleep "$delay"
		fi

		attempt=$((attempt + 1))
	done

	log_message "ERROR" "$category" "[$func] Command failed after $max_attempts attempts."
	return $exit_code
}
