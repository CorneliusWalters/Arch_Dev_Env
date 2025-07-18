#!/bin/bash
###     file name: p10k.sh
###     dir: /mnt/c/wsl/scripts/lib/config/p10k.sh


#######--- START OF FILE ---#######

setup_p10k() {
  if [[ ! -f ~/.config/zsh/.p10k.zsh ]] || [[ "$FORCE_OVERWRITE" == "true" ]]; then
      print_status "P10K" "Setting up Powerlevel10k configuration..."
      source "$SCRIPT_DIR/lib/config/zxc_p10k.sh"
      print_success "P10K" "Powerlevel10k configuration complete."
  else
      print_warning "P10K" "P10k config already exists and Force Overwrite is disabled. Skipping."
  fi
}

#######--- END OF FILE ---#######
