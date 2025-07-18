#!/bin/bash
###     file name: tmux.sh
###     dir: /mnt/c/wsl/scripts/lib/config/tmux.sh


#######--- START OF FILE ---#######
# The check for FORCE_OVERWRITE should happen here, in the wrapper.
  # The zxc_*.sh script should just focus on the patching logic.
setup_tmux() {
  if [ ! -f ~/.config/tmux/tmux.conf ] || [ "$FORCE_OVERWRITE" == "true" ]; then
      print_status "TMUX" "Setting up TMUX configuration..."
      # Source the script that does the patch/deploy work
      source "$SCRIPT_DIR/lib/config/zxc_tmux.sh"
      print_success "TMUX" "TMUX configuration complete."
  else
      print_warning "TMUX" "TMux config (~/.config/tmux/tmux.conf) already exists and Force Overwrite is disabled. Skipping."
  fi
}
#######--- END OF FILE ---#######