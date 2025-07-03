#!/bin/bash
###     filename: zsh.sh
###     dir: /mnt/c/wsl/scripts/lib/config/zsh.sh


#######--- START OF FILE ---#######
setup_zsh() {
    print_status "ZSH_CONF" "Setting up ZSH configuration..."

    # 1. Ensure the ZDOTDIR exists before we do anything else.
    mkdir -p "$HOME/.config/zsh"

    # 2. Create .zshenv to set ZDOTDIR. This is critical and must happen first.
    echo 'export ZDOTDIR="$HOME/.config/zsh"' > "$HOME/.zshenv"

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
    source "$SCRIPT_DIR/lib/config/zxc_zsh.sh"

    print_success "ZSH_CONF" "ZSH configuration complete."
}



#######--- END OF FILE ---#######

