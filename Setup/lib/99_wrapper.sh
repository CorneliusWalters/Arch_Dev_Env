#!/bin/bash
# Setup/lib/99_wrapper.sh - PowerShell execution wrapper

set -e

# Environment setup
export FORCE_OVERWRITE='true'
export SYSTEM_LOCALE='en_US.UTF-8'
export POWERSHELL_EXECUTION='true'

# Force unbuffered output for real-time streaming
export PYTHONUNBUFFERED=1
export DEBIAN_FRONTEND=noninteractive
stty -icanon 2>/dev/null || true

echo "=== WSL Setup Starting at $(date) ==="
echo "User: $(whoami)"
echo "Home: $HOME"
echo "Working Directory: $(pwd)"

# Force output flush
sync
sleep 0.1

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
sync

# Use stdbuf to disable buffering and run normally (not exec)
stdbuf -oL -eL bash Setup/1_sys_init.sh