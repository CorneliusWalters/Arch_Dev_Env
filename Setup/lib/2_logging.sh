#!/bin/bash
###     file name: 2_logging.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.
# shellcheck disable=SC2155

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
		sync
	}

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
		sync
	}
	# Aggressive flushing
	sync
	sleep 0.2
	printf "\n" >&2 # Extra newline to stderr
	sync
}

print_phase_end() {
	local phase=$1
	local status=$2
	# --- FIX: Only echo markers to stdout/stderr for PowerShell ---
	echo ""
	echo "$PHASE_MARKER_PREFIX"
	echo "$PHASE_END_MARKER: $phase"
	echo "STATUS: $status"
	echo "$PHASE_MARKER_PREFIX"
	echo ""
	sync
}

# Add a progress indicator function
print_progress() {
	local current=$1
	local total=$2
	local phase=$3
	local action=$4
	echo ">>> PROGRESS: [$current/$total] $phase - $action"
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

	# Standard output for PowerShell capture. Use specific prefixes.
	echo "[$level] [$category] $message" >&2 # Send to stderr for PowerShell's OutputDataReceived
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

	print_status "$category" "Executing: $desc"
	log_message "COMMAND" "$category" "[$func] \$ $cmd"

	local start_time=$(date +%s)

	# Execute the command directly, allowing output to stream.
	eval "$cmd"
	local exit_code=$?

	local end_time=$(date +%s)
	local duration=$((end_time - start_time))

	if [ $exit_code -eq 0 ]; then
		print_success "$category" "$desc completed successfully (${duration}s)."
		log_message "SUCCESS" "$category" "[$func] Command finished. Exit Code: 0, Duration: ${duration}s"
		return 0
	else
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
	local exit_code=0
	local func="${FUNCNAME[1]:-main}"

	while [ $attempt -le $max_attempts ]; do
		print_status "$category" "[$func] Attempt $attempt of $max_attempts for: $cmd"

		# --- FIX: Execute command directly for streaming output ---
		eval "$cmd"
		exit_code=$?

		if [ $exit_code -eq 0 ]; then
			print_success "$category" "[$func] Succeeded on attempt $attempt."
			return 0
		fi

		if [ $attempt -lt $max_attempts ]; then
			print_warning "$category" "[$func] Attempt $attempt failed. Retrying in $delay seconds..."
			sleep "$delay"
		fi

		attempt=$((attempt + 1))
	done

	print_error "$category" "[$func] Command failed after $max_attempts attempts."
	return $exit_code
}

#######--- END OF FILE ---#######
