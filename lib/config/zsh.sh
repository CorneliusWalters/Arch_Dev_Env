#!/bin/bash
###     filename: zsh.sh
###     dir: /mnt/c/wsl/scripts/lib/config/zsh.sh


#######--- START OF FILE ---#######
setup_zsh() {
    print_status "ZSH_CONF" "Setting up ZSH configuration..."
    
    # Install oh-my-zsh if not already installed
    if [ ! -d "$HOME/.local/share/zsh/oh-my-zsh" ]; then
        print_status "OMZ_START" "Installing Oh My Zsh..."
        export ZSH="$HOME/.local/share/zsh/oh-my-zsh"
        
        print_status "OMZ_INST" "Installing Oh My Zsh..."
        execute_and_log "install_omz" \
            "Installing Oh My Zsh" \
            "OMW_INST" || return 1

        # Install zsh plugins
        print_status "ZSHAUTO" "Cloning autocomplete ..."
        execute_and_log "zsh_auto" \
            "Installing zsh-autosuggestions" \
            "ZSHAUTO" || return 1

        print_status "HGLGT_SYNT" "Cloning Syntax Highlighting ..."
        execute_and_log "install_omz_syntax" \
            "Installing zsh-syntax-highlighting" \
            "HGLGT_SYNT" || return 1
        
        print_status "P10K" "Cloning PwerLVL 10K ..."
        execute_and_log "install_p10k" \
            "Installing powerlevel10k" \
            "P10K" || return 1
    fi
    echo "export ZDOTDIR=\"\$HOME/.config/zsh\"" > ~/.zshenv

    # Copy ZSH configurations
    source "$SCRIPT_DIR/lib/config/zxc_zsh.sh"
}


#######--- END OF FILE ---#######

