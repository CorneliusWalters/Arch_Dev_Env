#!/bin/bash
###     file name: watcher.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/config/watcher.sh

# An array of configuration files to watch.
# These paths are relative to the HOME directory.
FILES_TO_WATCH=(
	".config/zsh/.zshrc"
	".config/zsh/.p10k.zsh"
	".config/lsd/config.yaml"
	".config/tmux/tmux.conf"
	".config/nvim/init.lua"
	".config/nvim/plugins.lua"
	".config/nvim/keymaps.lua"
	".config/nvim/preferences.lua"
)

# Convert to absolute paths
declare -a ABSOLUTE_PATHS
for file in "${FILES_TO_WATCH[@]}"; do
	ABSOLUTE_PATHS+=("$HOME/$file")
done
# Ensure SETUP_REPO_ROOT is available in this service context
if [[ -z "$SETUP_REPO_ROOT" ]]; then
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	# Assume SETUP_REPO_ROOT is two levels up from this script
	SETUP_REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

PATCH_GENERATOR_SCRIPT="$SETUP_REPO_ROOT/lib/7_commit_config.sh"

# Path to the log directory for the hook (inside the repo for consistency).
LOG_DIR="$SETUP_REPO_ROOT/tmp/logs" # Use SETUP_REPO_ROOT for consistency
LOGFILE="$LOG_DIR/watcher_git_sync.log"

# --- Logging setup for this specific script ---
mkdir -p "$LOG_DIR"
exec >>"$LOGFILE" 2>&1 # Redirect all output to the log file.

echo "--- $(date) - Starting config watcher for $USER ---"

# The inotifywait loop
# Ensure inotifywait is installed (should be in base_packages)
if ! command -v inotifywait >/dev/null; then
	echo "ERROR: inotifywait not found. Config watcher cannot start."
	exit 1
fi

inotifywait -m -q -e close_write --format '%w' "${ABSOLUTE_PATHS[@]}" | while read -r CHANGED_FILE; do
	echo "$(date): Detected change in '$CHANGED_FILE'. Triggering patch generation."
	# Execute the patch generator script, passing the changed file path
	bash "$PATCH_GENERATOR_SCRIPT" "$CHANGED_FILE"
done

echo "--- $(date) - Config watcher stopped ---"
