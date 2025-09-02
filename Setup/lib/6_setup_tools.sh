#!/bin/bash
###     file name: 6_setup_tools.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.

setup_tmux() {
  print_status "TMUX" "Setting up TMUX configuration..."
  # 1. Copy the pristine file directly from the repo to the working directory.
  cp "$PRISTINE_DOTFILES_SRC/tmux.conf" "$TMUX_WORKING_FILE"
  # 2. Check for and apply the user patch.
  if [ -f "$TMUX_PATCH_FILE" ]; then
    print_status "TMUX_PATCH" "Applying patch for tmux.conf..."
    patch "$TMUX_WORKING_FILE" <"$TMUX_PATCH_FILE"
  fi
  print_success "TMUX" "TMUX configuration complete."
}

setup_zsh() {
  print_status "ZSH" "Setting up ZSH configuration..."
  # OMZ and ZDOTDIR setup remains the same
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

  # 1. Copy the pristine file directly from the repo.
  cp "$PRISTINE_DOTFILES_SRC/zsh/.zshrc" "$ZSH_WORKING_FILE"
  # 2. Apply the patch.
  if [ -f "$ZSH_PATCH_FILE" ]; then
    print_status "ZSH_PATCH" "Applying patch for .zshrc..."
    patch "$ZSH_WORKING_FILE" <"$ZSH_PATCH_FILE"
  fi
  print_success "ZSH" "ZSH configuration complete."
}

setup_neovim() {
  print_status "NVIM" "Setting up NVIM configuration..."

  execute_and_log "sudo npm install -g neovim tree-sitter-cli" "Installing Neovim Node packages" "NVIM" || return 1
  setup_winyank || exit 1

  # 1. Copy the pristine files directly from the repo.
  cp "$PRISTINE_DOTFILES_SRC/nvim/init.lua" "$NVIM_WORKING_DIR/init.lua"
  cp -r "$PRISTINE_DOTFILES_SRC/nvim/lua" "$NVIM_WORKING_DIR/"

  # 2. Apply patches for each file.
  local NVIM_CONFIG_FILES=("init.lua" "lua/preferences.lua" "lua/plugins.lua" "lua/keymaps.lua")
  for file in "${NVIM_CONFIG_FILES[@]}"; do
    local working_file="$NVIM_WORKING_DIR/$file"
    local patch_file="$working_file.patch"
    if [ -f "$patch_file" ]; then
      print_status "NVIM_PATCH" "Applying patch for $file..."
      patch "$working_file" <"$patch_file"
    fi
  done
  print_success "NVIM" "Neovim configuration complete."
}

setup_p10k() {
  print_status "P10K" "Setting up Powerlevel10k configuration..."

  # 1. Copy the pristine file directly from the repo.
  cp "$PRISTINE_DOTFILES_SRC/zsh/.p10k.zsh" "$P10K_WORKING_FILE"
  # 2. Apply the patch.
  if [ -f "$P10K_PATCH_FILE" ]; then
    print_status "P10K_PATCH" "Applying patch for .p10k.zsh ..."
    patch "$P10K_WORKING_FILE" <"$P10K_PATCH_FILE"
  fi
  print_success "P10K" "configuration complete."

}

setup_lsd_theme() {
  print_status "LSD" "Setting up Super LS ..."

  # 1. Copy the pristine file directly from the repo.
  cp "$PRISTINE_DOTFILES_SRC/config.yaml" "$LSD_WORKING_FILE"
  # 2. Apply the patch.
  if [ -f "$LSD_PATCH_FILE" ]; then
    print_status "LSD_PATCH" "Applying patch for LSD config.yaml ..."
    patch "$LSD_WORKING_FILE" <"$LSD_PATCH_FILE"
  fi
  print_success "LSD" "configuration complete."

}

setup_winyank() {
  print_status "CLIPBOARD" "Setting up win32yank for Neovim clipboard..."

  # Create directory for win32yank
  execute_and_log "mkdir -p ~/.local/bin" \
    "Creating local bin directory" \
    "CLIPBOARD" || return 1

  # Download win32yank
  execute_and_log "curl -sLo /tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x64.zip" \
    "Downloading win32yank" \
    "CLIPBOARD" || return 1

  # Extract win32yank
  execute_and_log "unzip -o /tmp/win32yank.zip -d /tmp/" \
    "Extracting win32yank" \
    "CLIPBOARD" || return 1

  # Move to local bin and make executable
  execute_and_log "mv /tmp/win32yank.exe ~/.local/bin/" \
    "Installing win32yank" \
    "CLIPBOARD" || return 1

  execute_and_log "chmod +x ~/.local/bin/win32yank.exe" \
    "Making win32yank executable" \
    "CLIPBOARD" || return 1

  # Clean up
  execute_and_log "rm /tmp/win32yank.zip" \
    "Cleaning up" \
    "CLIPBOARD" || return 1
}

install_omz() {
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}
zsh_auto() {
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-autosuggestions
}
install_omz_syntax() {
  git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting
}
install_p10k() {
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$ZSH/custom}/themes/powerlevel10k
}

setup_shell() {
  local zsh_path=$(which zsh)

  # First set up ZSH and its configurations
  setup_zsh || return 1

  # Set it as default shell if needed
  if [ "$SHELL" != "$zsh_path" ]; then
    print_status "DEF_SHELL" "Setting zsh as default shell..."
    execute_and_log "sudo chsh -s $zsh_path $USER" \
      "Setting ZSH as default shell" \
      "DEF_SHELL" || return 1

    # Add verification here
    print_status "DEF_SHELL" "Verifying shell change..."
    if grep -q "$zsh_path" /etc/passwd; then
      print_success "DEF_SHELL" "Shell change verified in /etc/passwd"
    else
      print_error "DEF_SHELL" "Shell change verification failed"
      return 1
    fi
  fi
}
