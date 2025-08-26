#!/bin/bash
###     file name: watcher.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.

# --- Derive essential paths (robust for hook execution) ---
# This script's own directory (e.g., /mnt/c/wsl/wsl_dev_setup/lib)
SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The repository root (e.g., /mnt/c/wsl/wsl_dev_setup)
REPO_ROOT="$(dirname "$SCRIPT_LIB_DIR")"

# Path to the Git action script (7_commit_config.sh)
PATCH_GENERATOR_SCRIPT="$REPO_ROOT/lib/7_commit_config.sh"

# Path to the log directory for the watcher (inside the repo for consistency).
LOG_DIR="$REPO_ROOT/tmp/logs"
LOGFILE="$LOG_DIR/watcher_git_sync.log"

# An array of configuration files to watch. These paths are relative to $HOME.
FILES_TO_WATCH=(
	".config/zsh/.zshrc"
	".config/zsh/.p10k.zsh"
	".config/lsd/config.yaml"
	".config/tmux/tmux.conf"
	".config/nvim/init.lua"
	".config/nvim/lua/preferences.lua"
	".config/nvim/lua/plugins.lua"
	".config/nvim/lua/keymaps.lua"
)

# Convert to absolute paths
declare -a ABSOLUTE_PATHS
for file in "${FILES_TO_WATCH[@]}"; do
	ABSOLUTE_PATHS+=("$HOME/$file")
done

# --- Logging setup for this specific script ---
mkdir -p "$LOG_DIR"
exec >>"$LOGFILE" 2>&1 # Redirect all output to the log file.

echo "--- $(date) - Starting config watcher for $USER ---"

# Ensure inotifywait is installed (should be in base_packages)
if ! command -v inotifywait >/dev/null; then
	echo "ERROR: inotifywait not found. Config watcher cannot start."
	exit 1
fi

inotifywait -m -q -e close_write --format '%w' "${ABSOLUTE_PATHS[@]}" | while read -r CHANGED_FILE; do
	echo "$(date): Detected change in '$CHANGED_FILE'. Triggering patch generation."
	bash "$PATCH_GENERATOR_SCRIPT" "$CHANGED_FILE"
done

echo "--- $(date) - Config watcher stopped ---"
