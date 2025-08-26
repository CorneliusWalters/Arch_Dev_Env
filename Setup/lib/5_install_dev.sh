#!/bin/bash
###     file name: 5_install_dev.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.
# shellcheck disable=SC2155

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
