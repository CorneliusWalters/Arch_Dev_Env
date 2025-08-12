#!/bin/bash
###     file name: nvim.sh
###     dir: /mnt/c/wsl/scripts/lib/config/nvim.sh


#######--- START OF FILE ---#######

setup_neovim() {
# Simplified Logic: Run setup if the nvim config dir is empty OR if force overwrite is enabled.
# The `-z "$(ls -A ~/.config/nvim)"` checks if the directory is empty.
if [[ -z "$(ls -A ~/.config/nvim 2>/dev/null)" ]] || [[ "$FORCE_OVERWRITE" == "true" ]]; then
    print_status "NVIM" "Setting up NVIM configuration..."
    # Install Node packages for Neovim
    execute_and_log "sudo npm install --prefix ~/.local neovim tree-sitter-cli" \
        "Installing Neovim Node packages" "NVIM" || return 1
    
    # Add clipboard support
    setup_winyank || exit 1
    # Source the script that does the heavy lifting
    source "$SCRIPT_DIR/lib/config/zxc_nvim.sh"
    print_success "NVIM" "Neovim configuration complete. Run 'nvim' to install plugins."
else
    print_warning "NVIM_CONF" "NVIM configuration already exists and Force Overwrite is disabled. Skipping."
fi
}

#######--- END OF FILE ---#######

