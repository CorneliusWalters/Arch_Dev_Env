#!/bin/bash
###     file name: zxc_zsh.sh
###     dir: /mnt/c/wsl/scripts/lib/config/zxc_zsh.sh

#######--- START OF FILE ---#######
# --- START: Define all paths locally. This makes the script self-contained. ---
# Directory Creation is done in 2_set_dirs.sh
PRISTINE_FILE="$HOME/.config/dotfiles-pristine/zsh/.zshrc"
WORKING_FILE="$HOME/.config/zsh/.zshrc"
PATCH_FILE="$WORKING_FILE.patch"
# --- END: Path definitions ---

print_status "ZSH_CONF" "Setting up zsh configuration..."

cat >"$PRISTINE_FILE" <<'EOL'
# p10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

path=(
    $HOME/.local/opt/go/bin
    $HOME/.local/opt
    $HOME/.local/bin
    $HOME/go/bin
    $path
)

# Force UTF-8 locale settings for compatibility with nvim and other tools
export LANG=en_ZA.UTF-8
export LC_ALL=en_ZA.UTF-8

# XDG Base Directory Specification
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"

# Updated paths
export TMUX_CONFIG_DIR="$HOME/.config/tmux"
export ZSH="$XDG_DATA_HOME/zsh/oh-my-zsh"
export TERM="xterm-256color"

export PERSONAL_REPO_ROOT="$HOME/.config/dotfiles"
export SETUP_REPO_ROOT="/mnt/c/wsl/wsl_dev_setup"
	
# Ensure personal repo exists
if [[ ! -d "$PERSONAL_REPO_ROOT" ]]; then
    mkdir -p "$PERSONAL_REPO_ROOT"
    cd "$PERSONAL_REPO_ROOT"
    git init >/dev/null 2>&1
    git branch -M main >/dev/null 2>&1
fi

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
    git
    z
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh
# For WSL specific clipboard

if [[ "$-" == *i* && -t 0 ]] && [[ -n "$WSL_DISTRO_NAME" ]] && [[ -z "$TMUX" ]] && [[ "$TERM_PROGRAM" != "vscode" ]]; then
    tmux -f "$XDG_CONFIG_HOME/tmux/tmux.conf" new-session -A -s main
fi

[[ ! -f $XDG_CONFIG_HOME/zsh/.p10k.zsh ]] || source $XDG_CONFIG_HOME/zsh/.p10k.zsh

# SET Alias Shortcuts
alias ls='lsd -lah'
alias ll='lsd -l'
alias la='lsd --tree ./*'
alias cat='bat'
alias top='btop'
alias find='fd'
alias grep='rg'


# Git shortcuts
alias g='git'
alias lg='lazygit'

# Development shortcuts
alias v='nvim'
alias py='python'
alias ipy='ipython'

# System
alias update='sudo pacman -Syu'
alias free='free -h'
alias df='df -h'
alias du='du -h'

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias proj='cd ~/projects'
alias wrk='cd ~/work'

# Quick edit configs
alias zshconf='${EDITOR:-nvim} ~/.config/zsh/.zshrc'
alias tmuxconf='${EDITOR:-nvim} ~/.config/tmux/tmux.conf'
alias nvimconf='${EDITOR:-nvim} ~/.config/nvim/init.lua'

    
EOL

# 2. Copy the pristine file to the working location.
cp "$PRISTINE_FILE" "$WORKING_FILE"

# 3. Check if a user patch exists and apply it.
if [ -f "$PATCH_FILE" ]; then
    print_status "ZSH_PATCH" "Found patch for .zshrc. Applying..."
    if patch "$WORKING_FILE" <"$PATCH_FILE"; then
        print_success "ZSH_PATCH" "Successfully applied user patch to .zshrc."
    else
        print_error "ZSH_PATCH" "Failed to apply patch to .zshrc. Please resolve manually."
    fi
fi

#######--- END OF FILE ---#######
