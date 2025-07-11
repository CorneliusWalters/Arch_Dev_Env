#!/bin/bash
###     file name: set_dirs.sh
###     dir: /mnt/c/wsl/scripts/lib/config/set_dirs.sh

#######--- START OF FILE ---#######
# Create project structure

# Create project structure
mkdir -p \
  ~/.config/nvim/lua/config \
  ~/.config/zsh \
  ~/.config/tmux \
  ~/.local/{bin,share,opt,logs} \
  ~/.cache

# Make all scripts executable
chmod +x "$SCRIPT_DIR/lib/"*.sh "$SCRIPT_DIR/lib/config/"*.sh

# Set directory permissions (700 for config dirs, 755 for others)
find ~/.config -type d -exec chmod 700 {} \;  # All config directories
chmod 755 ~/.local/* ~/.cache  # Non-sensitive directories


# Set permissions recursively from .config/nvim downward
find ~/.config/nvim -type d -exec chmod 700 {} \;

# Fix permissions and ownership (NEW ADDITIONS)
chown -R "$USER:$USER" ~/.config

echo "Final permissions for Neovim config:"
ls -ld ~/.config/nvim \
      ~/.config/nvim/lua \
      ~/.config/nvim/lua/config

#######--- END OF FILE ---#######

