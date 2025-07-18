#!/bin/bash
###     file name: p10k.sh
###     dir: /mnt/c/wsl/scripts/lib/config/p10k.sh


#######--- START OF FILE ---#######
setup_p10k() {
    print_status "P10K" "Setting up Powerlevel10k configuration..."
    
    # Create ZSH config directory if it doesn't exist
    mkdir -p ~/.config/zsh
    
    # Copy P10K configurations
    source "$SCRIPT_DIR/lib/config/zxc_p10k.sh"
    
    print_success "Powerlevel10k configuration complete"
}

#######--- END OF FILE ---#######
