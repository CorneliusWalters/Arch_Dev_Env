#!/bin/bash
###     file name: zxc_zsh.sh
###     dir: /mnt/c/wsl/scripts/lib/config/zxc_zsh.sh


#######--- START OF FILE ---#######
print_status "Setting up zsh configuration..."
cat > ~/.config/zsh/.zshrc << 'EOL'
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

# XDG Base Directory Specification
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"

# Updated paths
export TMUX_CONFIG_DIR="$HOME/.config/tmux"
export ZSH="$XDG_DATA_HOME/zsh/oh-my-zsh"
export TERM="xterm-256color"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
    git
    z
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh
# For WSL specific clipboard


if [[ "$-" == *i* ]] && [[ -n "$WSL_DISTRO_NAME" ]] && [[ -z "$TMUX" ]] && [[ "$TERM_PROGRAM" != "vscode" ]]; then
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

# Quick edit configs
alias zshconf='${EDITOR:-nvim} ~/.config/zsh/.zshrc'
alias tmuxconf='${EDITOR:-nvim} ~/.config/tmux/tmux.conf'
alias nvimconf='${EDITOR:-nvim} ~/.config/nvim/init.lua'


EOL

#######--- END OF FILE ---#######

