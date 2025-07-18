#!/bin/bash
###     file name: tmux.sh
###     dir: /mnt/c/wsl/scripts/lib/config/tmux.sh


#######--- START OF FILE ---#######
if [ ! -f ~/.config/tmux/tmux.conf ] || [ "$FORCE_OVERWRITE" == "true" ]; then
    setup_tmux() {
        print_status "Setting up TMUX configuration..."

        # Create TMUX config directory
        mkdir -p ~/.config/tmux

        # Copy TMUX configurations

        source "$SCRIPT_DIR/lib/config/zxc_tmux.sh"

        print_success "TMUX configuration complete"
    }
else
    print_warning "TMUX_CONF" "TMux config (~/.config/tmux/tmux.conf) already exists and Force Overwrite is disabled. Skipping."
fi
#######--- END OF FILE ---#######

