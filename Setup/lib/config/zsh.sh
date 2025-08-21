#!/bin/bash
###     filename: zsh.sh
###     dir: /mnt/c/wsl/scripts/lib/config/zsh.sh

#######--- START OF FILE ---#######
#Paths Definition

mkdir -p "$PRISTINE_DIR"
mkdir -p "$(dirname "$WORKING_FILE")"

setup_zsh() {
  if [[ ! -f ~/.config/zsh/.zshrc ]] || [[ "$FORCE_OVERWRITE" == "true" ]]; then
    print_status "ZSH" "Setting up ZSH configuration..."
    # This part handles the unique ZSH setup (ZDOTDIR, OMZ install)
    if ! grep -q "export ZDOTDIR=\"\$HOME/.config/zsh\"" "$HOME/.zshenv" 2>/dev/null; then
      echo 'export ZDOTDIR="$HOME/.config/zsh"' >>"$HOME/.zshenv"
    fi
    rm -f "$HOME/.zshrc"
    if [ ! -d "$HOME/.local/share/zsh/oh-my-zsh" ]; then
      export ZSH="$HOME/.local/share/zsh/oh-my-zsh"
      execute_and_log "install_omz" "Installing Oh My Zsh" "OMZ_INST" || return 1
      execute_and_log "zsh_auto" "Installing zsh-autosuggestions" "ZSHAUTO" || return 1
      execute_and_log "install_omz_syntax" "Installing zsh-syntax-highlighting" "HGLGT_SYNT" || return 1
      execute_and_log "install_p10k" "Installing powerlevel10k" "P10K" || return 1
    fi
    # Now, source the worker script to deploy the config files
    source "$SCRIPT_DIR/lib/config/zxc_zsh.sh"
    print_success "ZSH" "ZSH configuration complete."
  else
    print_warning "ZSH" "ZSH config already exists and Force Overwrite is disabled. Skipping."
  fi
}
#######--- END OF FILE ---#######
