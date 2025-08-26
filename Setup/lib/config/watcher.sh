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

# The Git action script
PATCH_GENERATOR_SCRIPT="$SETUP_REPO_ROOT/lib/7_commit_config.sh"

# The inotifywait loop
inotifywait -m -q -e close_write --format '%w' "${ABSOLUTE_PATHS[@]}" | while read -r CHANGED_FILE; do
	echo "$(date): Detected change in '$CHANGED_FILE'. Triggering patch generation."
	# Execute the patch generator script, passing the changed file path
	bash "$PATCH_GENERATOR_SCRIPT" "$CHANGED_FILE"
done
