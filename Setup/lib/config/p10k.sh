#!/bin/bash
###     file name: p10k.sh
###     dir: /mnt/c/wsl/scripts/lib/config/p10k.sh


#######--- START OF FILE ---#######

setup_p10k() {
  if [ ! -f ~/.config/zsh/.p10k.zsh ] || [ "$FORCE_OVERWRITE" == "true" ]; then
      print_status "P10K-ZSH" "Setting up P10K configuration for ZSH ..."
      # Source the script that does the patch/deploy work
      source "$SCRIPT_DIR/lib/config/zxc_p10K.sh"
      print_success "P10K-ZSH" "TMUX configuration complete."
  else
      print_warning "P10K-ZSH" "P10K Config (~/.config/zsh/.p10k.zsh) already exists and Force Overwrite is disabled. Skipping."
  fi

}

#######--- END OF FILE ---#######
