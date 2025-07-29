#!/bin/bash
# Setup/lib/99_wrapper.sh - PowerShell execution wrapper

set -e

# Environment setup
export FORCE_OVERWRITE='true'
export SYSTEM_LOCALE='en_US.UTF-8'
export POWERSHELL_EXECUTION='true'

echo "=== WSL Setup Starting at $(date) ==="
echo "User: $(whoami)"
echo "Home: $HOME"
echo "Working Directory: $(pwd)"

# Get the repository root (assuming this script is in Setup/lib/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "Script directory: $SCRIPT_DIR"
echo "Repository root: $REPO_ROOT"

# Change to repository directory
cd "$REPO_ROOT" || {
    echo "ERROR: Cannot cd to $REPO_ROOT"
    exit 1
}

echo "Changed to: $(pwd)"

# Verify main script exists
if [ ! -f Setup/1_sys_init.sh ]; then
    echo "ERROR: Setup/1_sys_init.sh not found"
    ls -la Setup/
    exit 1
fi

echo "Starting 1_sys_init.sh..."
exec bash Setup/1_sys_init.sh