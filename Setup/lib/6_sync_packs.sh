#!/bin/bash
###     file name: 6_sync_packs.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.

# This script is intended to be run by a pacman hook.
# It should perform Git operations as the user who invoked sudo pacman.

# --- Define Paths ---
# Derive REPO_ROOT and PACKAGE_LISTS_SRC as these may not be directly inherited by the hook.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")" # E.g., /mnt/c/wsl/wsl_dev_setup
PACKAGE_LISTS_SRC="$REPO_ROOT/Setup/packages"

# Path to the manual additions file, now managed by the hook.
ADD_INSTALLS_FILE="$PACKAGE_LISTS_SRC/add.installs"

# Path to the log directory for the hook (inside the repo for consistency).
LOG_DIR="$REPO_ROOT/tmp/logs"
LOGFILE="$LOG_DIR/pacman_git_sync.log"

# Get the user who invoked sudo (important for Git operations).
CURRENT_USER="$SUDO_USER"

# --- Logging setup for this specific script ---
mkdir -p "$LOG_DIR"
exec >>"$LOGFILE" 2>&1 # Redirect all output to the log file.

echo "--- $(date) - Starting package sync hook for user $CURRENT_USER ---"

if [ -z "$CURRENT_USER" ]; then
	echo "ERROR: SUDO_USER environment variable not set. Cannot determine the user to run Git as. Exiting."
	exit 1
fi

# Function to run commands as the current user.
run_as_user() {
	sudo -u "$CURRENT_USER" bash -c "$1"
}

# Ensure the Git repository exists and is accessible.
if [ ! -d "$REPO_ROOT" ]; then
	echo "ERROR: Git repository root '$REPO_ROOT' not found or not a directory. Exiting."
	exit 1
fi

# Change to the Git repository root directory as the current user.
if ! run_as_user "cd \"$REPO_ROOT\""; then
	echo "ERROR: Failed to change to repository directory '$REPO_ROOT' as user '$CURRENT_USER'. Exiting."
	exit 1
fi

# Create add.installs if it doesn't exist (e.g., very first run or manual deletion).
if [ ! -f "$ADD_INSTALLS_FILE" ]; then
	echo "# Manually added packages, or auto-tracked packages from pacman hook" | run_as_user "tee '$ADD_INSTALLS_FILE'"
fi

# Generate list of ALL explicitly installed packages (excluding base and dependencies).
current_installed_pkgs_temp="/tmp/current_installed_pkgs.tmp"
echo "Generating list of explicitly installed packages currently on system..."
if ! pacman -Qqet >"$current_installed_pkgs_temp" 2>/dev/null; then
	echo "WARNING: Failed to generate current package list using 'pacman -Qqet'. Skipping update."
	rm -f "$current_installed_pkgs_temp"
	exit 0 # Exit successfully as pacman operation completed, but sync failed.
fi

# Get list of packages already in add.installs (cleanly, ignoring comments).
existing_pkgs_raw=$(grep -Ev '^#|^$' "$ADD_INSTALLS_FILE" 2>/dev/null | sort)
# Get list of packages currently installed on the system (explicitly installed, non-deps).
system_pkgs_raw=$(cat "$current_installed_pkgs_temp" | sort)

new_pkgs_found=0
packages_to_append=""

# Compare and identify new packages to append to add.installs.
echo "Checking for new packages to add to '$ADD_INSTALLS_FILE'..."
while IFS= read -r pkg; do
	# If the system package is not found in the existing add.installs list.
	if ! grep -q "^${pkg}$" <<<"$existing_pkgs_raw"; then
		echo "Found new package to append: $pkg"
		packages_to_append+="$pkg"$'\n'
		new_pkgs_found=1
	fi
done <<<"$system_pkgs_raw"

rm -f "$current_installed_pkgs_temp" # Clean up temp file.

if [ "$new_pkgs_found" -eq 1 ]; then
	echo "New packages detected. Appending to '$ADD_INSTALLS_FILE' and committing..."

	# Append new packages with a timestamp and comment.
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	append_header=$'\n'"# Auto-added by pacman hook on $timestamp"$'\n' # Newline before and after comment.

	# Use run_as_user to ensure correct permissions for Git operations.
	(
		echo "$append_header"
		echo "$packages_to_append" | sort # Sort for consistent ordering.
	) | run_as_user "tee -a '$ADD_INSTALLS_FILE'"

	# --- Perform Git operations as the current user ---
	if ! run_as_user "cd \"$REPO_ROOT\" && git add \"$ADD_INSTALLS_FILE\""; then
		echo "ERROR: Failed to add '$ADD_INSTALLS_FILE' to Git staging. Exiting."
		exit 1
	fi

	# Check if there are actual changes staged before committing.
	if run_as_user "cd \"$REPO_ROOT\" && git diff-index --quiet HEAD"; then
		echo "No actual changes to commit after 'git add'. This should not happen if new packages were found."
	else
		# Commit the changes.
		if ! run_as_user "cd \"$REPO_ROOT\" && git commit -m \"Auto: Update $ADD_INSTALLS_FILE with new packages from pacman hook on $timestamp\""; then
			echo "ERROR: Failed to commit changes to Git. Exiting."
			exit 1
		fi

		# Attempt to pull and rebase before pushing to minimize conflicts.
		echo "Attempting to pull and rebase before pushing..."
		if ! run_as_user "cd \"$REPO_ROOT\" && git pull --rebase"; then
			echo "WARNING: 'git pull --rebase' failed. Manual intervention may be required to resolve conflicts before the next push."
			# Continue to push, but user might need to resolve conflicts later.
		fi

		# Push to GitHub.
		echo "Pushing changes to GitHub..."
		if ! run_as_user "cd \"$REPO_ROOT\" && git push"; then
			echo "ERROR: Failed to push changes to GitHub. Please check your Git credentials and network connectivity."
			echo "Manual push from '$REPO_ROOT' as user '$CURRENT_USER' may be required."
			exit 1 # Indicate failure for the hook.
		fi
		echo "Successfully updated and pushed '$ADD_INSTALLS_FILE' to GitHub."
	fi
else
	echo "No new packages to add to '$ADD_INSTALLS_FILE'. Skipping Git commit."
fi

echo "--- $(date) - Package sync hook finished ---"
exit 0 # Ensure the hook always exits successfully from pacman's perspective.
