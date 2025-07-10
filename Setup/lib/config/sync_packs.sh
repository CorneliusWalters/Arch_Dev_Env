#!/bin/bash

# This script is intended to be run by a pacman hook.
# It should perform Git operations as the user who invoked sudo pacman.

# Define paths
REPO_ROOT="/mnt/c/wsl/wsl-dev-setup" # IMPORTANT: Adjust if your localClonePath changes
PACKAGE_LIST_FILE="$REPO_ROOT/installed_packages.txt" # This will be in the main repo root
LOG_DIR="/mnt/c/wsl/tmp/logs"
LOGFILE="$LOG_DIR/pacman_git_sync.log"

# Get the user who invoked sudo (important for Git operations)
CURRENT_USER="$SUDO_USER"

# --- Logging setup for this specific script ---
mkdir -p "$LOG_DIR"
exec >> "$LOGFILE" 2>&1 # Redirect all output to the log file

echo "--- $(date) - Starting package sync hook for user $CURRENT_USER ---"

if [ -z "$CURRENT_USER" ]; then
    echo "ERROR: SUDO_USER environment variable not set. Cannot determine the user to run Git as. Exiting."
    exit 1
fi

# Function to run commands as the current user
run_as_user() {
    sudo -u "$CURRENT_USER" bash -c "$1"
}

# Ensure the Git repository exists and is accessible
if [ ! -d "$REPO_ROOT" ]; then
    echo "ERROR: Git repository root '$REPO_ROOT' not found or not a directory. Exiting."
    exit 1
fi

# Change to the Git repository root directory as the current user
if ! run_as_user "cd \"$REPO_ROOT\""; then
    echo "ERROR: Failed to change to repository directory '$REPO_ROOT' as user '$CURRENT_USER'. Exiting."
    exit 1
fi

# Generate list of explicitly installed packages (excluding base and dependencies)
# -Q: query, -q: quiet, -e: explicitly installed, -t: not a dependency (leaves)
echo "Generating new list of explicitly installed packages..."
if ! pacman -Qqet > "$PACKAGE_LIST_FILE.new" 2>/dev/null; then
    echo "WARNING: Failed to generate new package list using 'pacman -Qqet'. Skipping update."
    exit 0 # Exit successfully as pacman operation completed, but sync failed
fi

# Compare the new list with the existing one
if run_as_user "cmp -s \"$PACKAGE_LIST_FILE.new\" \"$PACKAGE_LIST_FILE\""; then
    echo "No changes detected in the package list. Skipping Git commit."
    rm "$PACKAGE_LIST_FILE.new"
else
    echo "Package list has changed. Updating Git repository..."
    
    # Move the new list to replace the old one
    mv "$PACKAGE_LIST_FILE.new" "$PACKAGE_LIST_FILE"

    # Perform Git operations as the current user
    if ! run_as_user "cd \"$REPO_ROOT\" && git add \"$PACKAGE_LIST_FILE\""; then
        echo "ERROR: Failed to add '$PACKAGE_LIST_FILE' to Git staging. Exiting."
        exit 1
    fi

    # Check if there are actual changes staged before committing
    if run_as_user "cd \"$REPO_ROOT\" && git diff-index --quiet HEAD"; then
        echo "No actual changes to commit after 'git add'. This should not happen if 'cmp -s' failed."
    else
        # Commit the changes
        if ! run_as_user "cd \"$REPO_ROOT\" && git commit -m \"Auto: Update installed Arch packages via pacman hook\""; then
            echo "ERROR: Failed to commit changes to Git. Exiting."
            exit 1
        fi

        # Attempt to pull and rebase before pushing to minimize conflicts
        echo "Attempting to pull and rebase before pushing..."
        if ! run_as_user "cd \"$REPO_ROOT\" && git pull --rebase"; then
            echo "WARNING: 'git pull --rebase' failed. Manual intervention may be required to resolve conflicts before the next push."
            # Continue to push, but user might need to resolve conflicts later
        fi

        # Push to GitHub
        echo "Pushing changes to GitHub..."
        if ! run_as_user "cd \"$REPO_ROOT\" && git push"; then
            echo "ERROR: Failed to push changes to GitHub. Please check your Git credentials and network connectivity."
            echo "Manual push from '$REPO_ROOT' as user '$CURRENT_USER' may be required."
            exit 1 # Indicate failure for the hook
        fi
        echo "Successfully updated and pushed '$PACKAGE_LIST_FILE' to GitHub."
    fi
fi

echo "--- $(date) - Package sync hook finished ---"
exit 0 # Ensure the hook always exits successfully from pacman's perspective