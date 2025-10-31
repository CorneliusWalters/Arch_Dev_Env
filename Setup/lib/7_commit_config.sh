#!/bin/bash
###     file name: 7_commit_config.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.
# shellcheck disable=SC1090
# generate_and_commit_patch.sh - Creates a .patch file from a modified config
# and commits it to Git.

# --- Self-contained Path Derivation ---
# This script's own directory (e.g., /mnt/c/wsl/wsl_dev_setup/lib)
SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The repository root (e.g., /mnt/c/wsl/wsl_dev_setup)
REPO_ROOT="$(dirname "$SCRIPT_LIB_DIR")"
# The Setup directory (e.g., /mnt/c/wsl/wsl_dev_setup/Setup)
SETUP_DIR="$REPO_ROOT/Setup"
# Source directory definitions relative to the derived path
source "$SETUP_DIR/lib/3_set_dirs.sh" || {
    echo "$(date): ERROR - Central directory definitions not found. Exiting."
    exit 1
}

LOG_DIR="$REPO_ROOT/tmp/logs"
LOG_FILE="$LOG_DIR/commit_patch.log"
mkdir -p "$LOG_DIR"
exec >>"$LOG_FILE" 2>&1

WORKING_FILE="$1"
if [ -z "$WORKING_FILE" ]; then
    echo "$(date): ERROR - No file path provided. Exiting."
    exit 1
fi

# Derive the pristine and patch file paths from variables defined in 3_set_dirs.sh
# This logic requires PRISTINE_ROOT to be defined, which it is.
RELATIVE_PATH=${WORKING_FILE#$HOME/}
PRISTINE_FILE="$PRISTINE_ROOT/${RELATIVE_PATH#*/}"
PATCH_FILE="$WORKING_FILE.patch"
FILENAME=$(basename "$WORKING_FILE")

echo "---"
echo "$(date): Processing change for $FILENAME"

if [ ! -f "$PRISTINE_FILE" ]; then
    echo "ERROR: Pristine file not found at '$PRISTINE_FILE'. Cannot generate patch."
    exit 1
fi

# Generate the patch using diff
echo "Generating patch for $FILENAME..."
diff -u "$PRISTINE_FILE" "$WORKING_FILE" >"$PATCH_FILE"

# Check if the patch file is empty (meaning no changes)
if [ ! -s "$PATCH_FILE" ]; then
    echo "No differences found. Removing empty patch file and skipping commit."
    rm "$PATCH_FILE"
    exit 0
fi

cd "$PERSONAL_REPO_ROOT" || {
    echo "ERROR: Could not cd to $PERSONAL_REPO_ROOT"
    exit 1
}

echo "Staging patch file: $PATCH_FILE"
git add "$PATCH_FILE"

echo "Committing patch for $FILENAME..."
git commit -m "Auto-sync: Update patch for $FILENAME"

echo "Pushing changes to remote..."
if git push; then
    echo "Successfully pushed patch for $FILENAME."
else
    echo "ERROR: Failed to push changes. Manual intervention may be required."
fi

echo "---"
