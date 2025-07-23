#!/bin/bash
#######--- START OF FILE ---#######

print_status "DIRS" "Creating base directory structure..."

# Create base XDG and local directories
mkdir -p \
  ~/.config \
  ~/.local/{bin,share,opt,logs} \
  ~/.cache

# --- Centralized Directory Creation for Dotfiles ---
# Create the main pristine directory
mkdir -p "$HOME/.config/dotfiles-pristine"

# Create directories for TMUX
mkdir -p "$HOME/.config/tmux"
mkdir -p "$HOME/.config/dotfiles-pristine/tmux"

# Create directories for ZSH
mkdir -p "$HOME/.config/zsh"
mkdir -p "$HOME/.config/dotfiles-pristine/zsh"

# Create directories for Neovim
mkdir -p "$HOME/.config/nvim/lua/config"
mkdir -p "$HOME/.config/dotfiles-pristine/nvim"

# Create Windows-accessible log/config directories
mkdir -p "$LOGS_BASE_PATH"
mkdir -p "$CONFIG_BASE_PATH"

print_status "PERMS" "Setting directory permissions..."

# Make all library scripts executable
chmod +x "$SCRIPT_DIR/lib/"*.sh
chmod +x "$SCRIPT_DIR/lib/config/"*.sh
chmod +x "$SCRIPT_DIR/lib/config/watcher.sh"
chmod +x "$SCRIPT_DIR/lib/6_commit_config.sh"

# Set directory permissions (700 for config dirs, 755 for others)
find ~/.config -type d -exec chmod 700 {} \;
chmod 755 ~/.local/* ~/.cache

# Fix ownership to the current user
chown -R "$USER:$USER" ~/.config ~/.local ~/.cache

print_success "DIRS" "Directory structure and permissions set."

#######--- END OF FILE ---#######

