#!/bin/bash
#######--- START OF FILE ---#######

print_status "DIRS" "Creating base directory structure..."

#Export windows accessable Base path
export WSL_BASE_PATH="/mnt/c/wsl"
export CONFIG_BASE_PATH="$WSL_BASE_PATH/config"
export PERSONAL_REPO_ROOT="$HOME/.config/dotfiles"
export SETUP_REPO_ROOT="$REPO_ROOT"
export PRISTINE_DIR="$HOME/.config/dotfiles-pristine/zsh"
export WORKING_FILE="$HOME/.config/zsh/.zshrc"
export PATCH_FILE="$WORKING_FILE.patch"

# Create base XDG and local directories
mkdir -p \
  ~/.config \
  ~/.local/{bin,share,opt,logs} \
  ~/.cache \
  ~/projects \
  ~/work

# --- Centralized Directory Creation for Dotfiles ---
# Create the main pristine directory
mkdir -p "$HOME/.config/dotfiles-pristine"
mkdir -p "$PERSONAL_REPO_ROOT"

# Create directories for TMUX
mkdir -p "$HOME/.config/tmux"
mkdir -p "$HOME/.config/dotfiles-pristine/tmux"

# Create directories for ZSH
mkdir -p "$HOME/.config/zsh"
mkdir -p "$HOME/.config/dotfiles-pristine/zsh"

# Create directories for Neovim
mkdir -p "$HOME/.config/nvim/lua/config"
mkdir -p "$HOME/.config/dotfiles-pristine/nvim"

# Set directory permissions (700 for config dirs, 755 for others)
find ~/.config -type d -exec chmod 700 {} \;
chmod 755 ~/.local/* ~/.cache

# Fix ownership to the current user
chown -R "$USER:$USER" ~/.config ~/.local ~/.cache

print_success "DIRS" "Directory structure and permissions set."

#######--- END OF FILE ---#######
