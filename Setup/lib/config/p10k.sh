#!/bin/bash
###     file name: p10k.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/config/p10k.sh

setup_p10k() {
  if [[ ! -f ~/.config/zsh/.p10k.zsh ]] || [[ "$FORCE_OVERWRITE" == "true" ]]; then
    print_status "P10K" "Setting up Powerlevel10k configuration..."
    source "$SCRIPT_DIR/lib/config/zxc_p10k.sh"
    print_success "P10K" "Powerlevel10k configuration complete."
  else
    print_warning "P10K" "P10k config already exists and Force Overwrite is disabled. Skipping."
  fi
}
