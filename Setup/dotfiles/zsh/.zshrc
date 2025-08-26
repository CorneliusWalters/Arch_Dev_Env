# shellcheck disable=SC2206
# shellcheck disable=SC1090
# shellcheck disable=SC2296
# shellcheck disable=SC2164
# shellcheck disable=SC2086
# shellcheck disable=SC1091
# shellcheck disable=SC2034



# p10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
# shellcheck disable=SC1090
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
