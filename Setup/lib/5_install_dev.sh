#!/bin/bash
###     file name: 5_install_dev.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.

install_db_tools() {
  print_status "DB" "Installing database tools..."
  # Add clients for databases you use
  local DB_TOOLS="postgresql-libs sqlite"
  execute_and_log "sudo pacman -S --needed --noconfirm $DB_TOOLS" \
    "Installing database client tools" \
    "DB" || return 1
}

install_dev_tools() {
  print_status "DEV" "Installing development tools..."
  local DEV_TOOLS="nodejs npm go rust zig rust-analyzer zls"
  execute_and_log "sudo pacman -S --needed --noconfirm $DEV_TOOLS" \
    "Installing development tools" \
    "DEV" || return 1
}

install_python_environment() {
  print_status "PYENV" "Installing Python environment..."
  local PYTHON_DEPS="python python-pip python-pipx python-poetry python-pynvim"
  execute_and_log "sudo pacman -S --needed --noconfirm $PYTHON_DEPS" \
    "Installing Python packages" \
    "PYENV" || return 1

  # Setup Python virtual environment for Neovim
  print_status "VIMENV" "Installing Python environment..."
  execute_and_log "python -m venv ~/.local/share/nvim-venv" \
    "Creating Neovim Python virtual environment" \
    "VIMENV" || return 1

  # Install Python packages in virtual environment
  print_status "SETPYENV" "Installing Python packages in virtual environment"
  execute_and_log "source ~/.local/share/nvim-venv/bin/activate && pip install pynvim debugpy && deactivate" \
    "Installing Python packages in virtual environment" \
    "SETPYENV" || return 1
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
