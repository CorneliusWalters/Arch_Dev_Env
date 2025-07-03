#!/bin/bash
###     file name: tmux.sh
###     dir: /mnt/c/wsl/scripts/lib/config/tmux.sh


#######--- START OF FILE ---#######
setup_tmux() {
    print_status "Setting up TMUX configuration..."
    
    # Create TMUX config directory
    mkdir -p ~/.config/tmux
    
    # Copy TMUX configurations
    source "$SCRIPT_DIR/lib/config/zxc_tmux.sh"
    
    print_success "TMUX configuration complete"
}


#######--- END OF FILE ---#######

