#!/bin/bash
#
# Watcher.sh - Watches for config file changes and triggers a git commit.
# To be run as a background service.

# The root of the Git repository inside WSL.
# IMPORTANT: This path must be correct.
REPO_ROOT="/mnt/c/wsl/wsl-dev-setup"

# An array of configuration files to watch.
# These paths are relative to the user's HOME directory.
FILES_TO_WATCH=(
	".config/zsh/.zshrc"
	".config/zsh/.p10k.zsh"
	".config/tmux/tmux.conf"
	".config/nvim/init.lua"
	".config/nvim/plugins.lua"
	".config/nvim/keymaps.lua"
	".config/nvim/preferences.lua"
)

# --- Do not edit below this line ---

# Convert to absolute paths
declare -a ABSOLUTE_PATHS
for file in "${FILES_TO_WATCH[@]}"; do
	ABSOLUTE_PATHS+=("$HOME/$file")
done

# The Git action script
PATCH_GENERATOR_SCRIPT="$REPO_ROOT/Setup/lib/6_commit_config.sh"

# The inotifywait loop
inotifywait -m -q -e close_write --format '%w' "${ABSOLUTE_PATHS[@]}" | while read -r CHANGED_FILE; do
	echo "$(date): Detected change in '$CHANGED_FILE'. Triggering patch generation."
	# Execute the patch generator script, passing the changed file path
	bash "$PATCH_GENERATOR_SCRIPT" "$CHANGED_FILE"
done
