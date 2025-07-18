#!/bin/bash
###     filename: zsh.sh
###     dir: /mnt/c/wsl/scripts/lib/config/zsh.sh


#######--- START OF FILE ---#######
    #Paths Definition
    PRISTINE_DIR="$HOME/.config/dotfiles-pristine/tmux"
    WORKING_FILE="$HOME/.config/tmux/tmux.conf"
    PATCH_FILE="$WORKING_FILE.patch"

    mkdir -p "$PRISTINE_DIR"
    mkdir -p "$(dirname "$WORKING_FILE")"


setup_zsh() {

    print_status "ZSH_CONF" "Setting up ZSH configuration..."

    # 1. Ensure the ZDOTDIR exists before we do anything else.
    mkdir -p "$HOME/.config/zsh"


    # 2. Create .zshenv to set ZDOTDIR. This is critical and must happen first.
    if ! grep -q "export ZDOTDIR=\"\$HOME/.config/zsh\"" "$HOME/.zshenv" 2>/dev/null; then
        print_status "ZSH_CONF" "Adding ZDOTDIR export to ~/.zshenv (if not present)."
        echo 'export ZDOTDIR="$HOME/.config/zsh"' >> "$HOME/.zshenv"
    else
        print_status "ZSH_CONF" "ZDOTDIR export already present in ~/.zshenv. Skipping."
    fi
    # 3. For safety, remove any old .zshrc from the home directory to avoid conflicts.
    rm -f "$HOME/.zshrc"

    # 4. Install oh-my-zsh and plugins if they don't exist.
    if [ ! -d "$HOME/.local/share/zsh/oh-my-zsh" ]; then
        print_status "OMZ_START" "Installing Oh My Zsh and plugins..."
        export ZSH="$HOME/.local/share/zsh/oh-my-zsh"

        execute_and_log "install_omz" "Installing Oh My Zsh" "OMZ_INST" || return 1
        execute_and_log "zsh_auto" "Installing zsh-autosuggestions" "ZSHAUTO" || return 1
        execute_and_log "install_omz_syntax" "Installing zsh-syntax-highlighting" "HGLGT_SYNT" || return 1
        execute_and_log "install_p10k" "Installing powerlevel10k" "P10K" || return 1
    fi

    # 5. Now that ZDOTDIR is set and plugins are installed, write the .zshrc.
    if [ ! -f ~/.config/zsh/.zshrc ] || [ "$FORCE_OVERWRITE" == "true" ]; then 
        source "$SCRIPT_DIR/lib/config/zxc_zsh.sh"
    else
        print_warning "ZSH_CONF" "ZSH config (~/.config/zsh/.zshrc) already exists. and Force Overwrite is disabled. Skipping.".""
    fi
    print_success "ZSH_CONF" "ZSH configuration complete."
}



#######--- END OF FILE ---#######

