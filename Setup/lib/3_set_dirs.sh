#!/bin/bash
###     file name: 3_set_dirs.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.

print_status "DIRS" "Defining paths and creating directory structure..."

# --- 1. Define Core Paths ---
export PERSONAL_REPO_ROOT="$HOME/.config/dotfiles"
export SETUP_REPO_ROOT="$REPO_ROOT" # REPO_ROOT is from 1_sys_init.sh
export PRISTINE_ROOT="$HOME/.config/dotfiles-pristine"
export PRISTINE_DOTFILES_SRC="$SETUP_REPO_ROOT/Setup/dotfiles"
export PACKAGE_LISTS_SRC="$SETUP_REPO_ROOT/Setup/packages"

# --- 2. Define Specific Configuration File Paths ---

# ZSH Paths
export ZSH_PRISTINE_FILE="$PRISTINE_ROOT/zsh/.zshrc"
export ZSH_WORKING_FILE="$HOME/.config/zsh/.zshrc"
export ZSH_PATCH_FILE="$ZSH_WORKING_FILE.patch"

# P10K Paths
export P10K_PRISTINE_FILE="$PRISTINE_ROOT/zsh/.p10k.zsh"
export P10K_WORKING_FILE="$HOME/.config/zsh/.p10k.zsh"
export P10K_PATCH_FILE="$P10K_WORKING_FILE.patch"

# TMUX Paths
export TMUX_PRISTINE_FILE="$PRISTINE_ROOT/tmux/tmux.conf"
export TMUX_WORKING_FILE="$HOME/.config/tmux/tmux.conf"
export TMUX_PATCH_FILE="$TMUX_WORKING_FILE.patch"

# LSD Paths
export LSD_PRISTINE_FILE="$PRISTINE_ROOT/lsd/config.yaml"
export LSD_WORKING_FILE="$HOME/.config/lsd/config.yaml"
export LSD_PATCH_FILE="$LSD_WORKING_FILE.patch"

# NVIM Paths
export NVIM_PRISTINE_DIR="$PRISTINE_ROOT/nvim"
export NVIM_WORKING_DIR="$HOME/.config/nvim"

# --- 3. Create All Directories in One Go ---
mkdir -p \
  "$PRISTINE_ROOT/"{tmux,zsh,nvim/lua,lsd} \
  "$HOME/.config/"{tmux,zsh,nvim/lua/config,lsd} \
  "$HOME/.local/"{bin,share,opt,logs} \
  "$HOME/.cache" \
  "$HOME/projects" \
  "$HOME/work" \
  "$PERSONAL_REPO_ROOT"

# --- 4. Set Permissions and Ownership ---
find "$HOME/.config" -type d -exec chmod 700 {} \;
chmod 755 "$HOME/.local" "$HOME/.cache"
chown -R "$USER:$USER" "$HOME/.config" "$HOME/.local" "$HOME/.cache"

print_success "DIRS" "Directory structure and paths defined."
