#!/bin/bash
###     file name: 99_wrapper.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.

set -e

# Environment setup
export FORCE_OVERWRITE='true'
export SYSTEM_LOCALE='en_US.UTF-8'
export POWERSHELL_EXECUTION='true'

# Force unbuffered output for real-time streaming
export PYTHONUNBUFFERED=1
export DEBIAN_FRONTEND=noninteractive
export TERM=xterm-256color

stty -icanon min 1 time 0 2>/dev/null || true

echo "### PHASE_BOUNDARY ###"
echo ">>> PHASE_START: WRAPPER_INIT"
echo "DESCRIPTION: WSL Setup Starting"
echo "### PHASE_BOUNDARY ###"

# Force output flush and add visual separator
# Force output flush
sync
printf "\n" >&2
sleep 0.2

# Get the repository root (assuming this script is in Setup/lib/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "Script directory: $SCRIPT_DIR"
echo "Repository root: $REPO_ROOT"
sync

# Change to repository directory
cd "$REPO_ROOT" || {
    echo "ERROR: Cannot cd to $REPO_ROOT"
    exit 1
}

echo "Changed to: $(pwd)"
sync

# Verify main script exists
if [ ! -f Setup/1_sys_init.sh ]; then
    echo "ERROR: Setup/1_sys_init.sh not found"
    ls -la Setup/
    exit 1
fi

echo "Starting 1_sys_init.sh..."

echo "### PHASE_BOUNDARY ###"
echo ">>> PHASE_START: SCRIPT_EXECUTION"
echo "DESCRIPTION: Starting main installation script"
echo "### PHASE_BOUNDARY ###"

sync

# Use unbuffered execution
stdbuf -oL -eL bash Setup/1_sys_init.sh
exit 0
