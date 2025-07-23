#!/bin/bash
#
# generate_and_commit_patch.sh - Creates a .patch file from a modified config
# and commits it to Git.

REPO_ROOT="/mnt/c/wsl/wsl_dev_setup"
LOG_FILE="/mnt/c/wsl/tmp/logs/config_git_sync.log"
# --- Do not edit below this line ---

mkdir -p "$(dirname "$LOG_FILE")"
exec >> "$LOG_FILE" 2>&1

WORKING_FILE="$1"
if [ -z "$WORKING_FILE" ]; then
    echo "$(date): ERROR - No file path provided. Exiting."
    exit 1
fi

# Derive the pristine and patch file paths
RELATIVE_PATH=${WORKING_FILE#$HOME/} # e.g., .config/tmux/tmux.conf
PRISTINE_FILE="$HOME/.config/dotfiles-pristine/${RELATIVE_PATH#*/}" # e.g., .../tmux/tmux.conf
PATCH_FILE="$WORKING_FILE.patch"
FILENAME=$(basename "$WORKING_FILE")

echo "---"
echo "$(date): Processing change for $FILENAME"

if [ ! -f "$PRISTINE_FILE" ]; then
    echo "ERROR: Pristine file not found at '$PRISTINE_FILE'. Cannot generate patch."
    exit 1
fi

# Generate the patch using diff
# -u: unified format (standard for patches)
# The labels 'a/' and 'b/' are conventional for diff.
echo "Generating patch for $FILENAME..."
diff -u "$PRISTINE_FILE" "$WORKING_FILE" > "$PATCH_FILE"

# Check if the patch file is empty (meaning no changes)
if [ ! -s "$PATCH_FILE" ]; then
    echo "No differences found. Removing empty patch file and skipping commit."
    rm "$PATCH_FILE"
    exit 0
fi

cd "$REPO_ROOT" || { echo "ERROR: Could not cd to $REPO_ROOT"; exit 1; }

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