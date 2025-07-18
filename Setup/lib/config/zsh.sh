#!/bin/bash
###     filename: zsh.sh
###     dir: /mnt/c/wsl/scripts/lib/config/zsh.sh


#######--- START OF FILE ---#######
    #Paths Definition
PRISTINE_DIR="$HOME/.config/dotfiles-pristine/zsh"
WORKING_FILE="$HOME/.config/zsh/.zshrc"
PATCH_FILE="$WORKING_FILE.patch"
mkdir -p "$PRISTINE_DIR"
mkdir -p "$(dirname "$WORKING_FILE")"


setup_zsh() {

  if [ ! -f ~/.config/zsh/.zshrc ] || [ "$FORCE_OVERWRITE" == "true" ]; then 
    print_status "ZSH_CONF" "Setting up ZSH configuration..."

    # 1. Create .zshenv to set ZDOTDIR. --Critical Step
    if ! grep -q "export ZDOTDIR=\"\$HOME/.config/zsh\"" "$HOME/.zshenv" 2>/dev/null; then
        print_status "ZSH_CONF" "Adding ZDOTDIR export to ~/.zshenv (if not present)."
        echo 'export ZDOTDIR="$HOME/.config/zsh"' >> "$HOME/.zshenv"
    fi
  # 2. For safety, remove any old .zshrc from the home directory to avoid conflicts.
  rm -f "$HOME/.zshrc"
  # 3. Install oh-my-zsh and plugins if they don't exist.
  if [ ! -d "$HOME/.local/share/zsh/oh-my-zsh" ]; then
      print_status "OMZ_START" "Installing Oh My Zsh and plugins..."
      export ZSH="$HOME/.local/share/zsh/oh-my-zsh"
      execute_and_log "install_omz" "Installing Oh My Zsh" "OMZ_INST" || return 1
      execute_and_log "zsh_auto" "Installing zsh-autosuggestions" "ZSHAUTO" || return 1
      execute_and_log "install_omz_syntax" "Installing zsh-syntax-highlighting" "HGLGT_SYNT" || return 1
      execute_and_log "install_p10k" "Installing powerlevel10k" "P10K" || return 1
  fi
  # 4. write the .zshrc
      source "$SCRIPT_DIR/lib/config/zxc_zsh.sh"
  fi
  print_success "ZSH_CONF" "ZSH configuration complete."
}



#######--- END OF FILE ---#######

