#!/bin/bash
###     file name: nvim.sh
###     dir: /mnt/c/wsl/scripts/lib/config/nvim.sh


#######--- START OF FILE ---#######

setup_neovim() {
    print_status "NVIM-TREE" "Setting up Neovim configuration..."

    # Install Node packages for Neovim
    execute_and_log "npm install --prefix ~/.local neovim tree-sitter-cli" \
        "Installing Neovim Node packages" \
        "NVIM-TREE" || return 1
    # Add clipboard support
    setup_winyank || exit 1

    # Copy Neovim configurations
    print_status "Neovim configuration complete. Run 'nvim' to install plugins."

    source "$SCRIPT_DIR/lib/config/zxc_nvim.sh"
}


#######--- END OF FILE ---#######

