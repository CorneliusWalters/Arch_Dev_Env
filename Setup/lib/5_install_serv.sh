#!/bin/bash
###     file name: 5_install_serv.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.
# shellcheck disable=SC2155

setup_systemd_enabler() {
  print_status "SYSTEMD" "Setting up native WSL2 systemd support..."

  # Check if systemd is already the init process (PID 1)
  if [ "$(ps -p 1 -o comm=)" = "systemd" ]; then
    print_success "SYSTEMD" "Systemd is already active (PID 1)."
    return 0
  fi

  print_status "SYSTEMD" "Configuring WSL for native systemd support..."

  # Create a clean wsl.conf with systemd enabled
  sudo tee /etc/wsl.conf >/dev/null <<EOF
[user]
default=$USER

[boot]
systemd=true

[interop]
enabled=true
appendWindowsPath=true
EOF

  print_success "SYSTEMD" "WSL systemd configuration complete."
  print_warning "SYSTEMD" "A full WSL shutdown and restart is required to activate systemd."
  print_warning "SYSTEMD" "The PowerShell script will handle this restart automatically."

  return 0
}

setup_watcher_service() {
  print_status "WATCHER" "Setting up config file watcher service..."

  local watcher_script="$REPO_ROOT/Setup/lib/config/watcher.sh"
  local commit_script="$REPO_ROOT/Setup/lib/7_commit_config.sh"
  local service_file_path="$HOME/.config/systemd/user/config-watcher.service"
  local zshrc_file="$HOME/.config/zsh/.zshrc"

  # Make scripts executable
  chmod +x "$watcher_script" "$commit_script"

  # Create systemd user directory
  mkdir -p "$HOME/.config/systemd/user/"

  # Create the service file
  cat >"$service_file_path" <<EOL
[Unit]
Description=Watches for user config file changes and commits them to Git
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/bash $watcher_script
Restart=always
RestartSec=10
Environment=HOME=$HOME

[Install]
WantedBy=default.target
EOL

  # Add enabler to .zshrc that waits for systemd to be ready
  cat >>"$zshrc_file" <<'EOL'

# --- One-shot service enabler for config-watcher ---
# Wait for systemd and enable service on first shell start
if command -v systemctl >/dev/null 2>&1 && ! systemctl --user is-enabled -q config-watcher.service 2>/dev/null; then
    echo "Setting up config watcher service..."
    systemctl --user daemon-reload
    systemctl --user enable --now config-watcher.service 2>/dev/null && \
        echo "Config watcher service enabled." || \
        echo "Config watcher will be enabled after systemd is fully initialized."
fi
# --- End one-shot enabler ---
EOL

  print_success "WATCHER" "Config watcher service configured."
}

setup_pacman_git_hook() {
  print_status "HOOK_SETUP" "Setting up pacman hook for Git repository synchronization..."

  local sync_script_source="$SCRIPT_DIR/lib/5_sync_packs.sh"
  local sync_script_target="/usr/local/bin/5_sync_packs.sh"
  local hook_file="/etc/pacman.d/hooks/auto-git-sync.hook"
  local hook_dir="/etc/pacman.d/hooks"

  # Create the hooks directory if it doesn't exist
  execute_and_log "sudo mkdir -p \"$hook_dir\"" \
    "Creating pacman hooks directory" "HOOK_SETUP" || return 1

  # Copy the sync script and make it executable
  execute_and_log "sudo cp \"$sync_script_source\" \"$sync_script_target\"" \
    "Copying package sync script to $sync_script_target" "HOOK_SETUP" || return 1
  execute_and_log "sudo chmod +x \"$sync_script_target\"" \
    "Making package sync script executable" "HOOK_SETUP" || return 1

  # Create the pacman hook file
  execute_and_log "sudo tee \"$hook_file\" > /dev/null << 'EOL'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Syncing installed packages to Git repository...
When = PostTransaction
Exec = $sync_script_target
EOL" \
    "Creating pacman hook file $hook_file" "HOOK_SETUP" || return 1

  print_success "HOOK_SETUP" "Pacman Git sync hook setup complete."
}

setup_git_config() {
  print_status "GIT_CONFIG" "Setting up Git configuration..."

  # --- Configure Global Git Settings ---
  local git_name=$(git config --global user.name 2>/dev/null)
  local git_email=$(git config --global user.email 2>/dev/null)

  if [[ -z "$git_name" ]] || [[ -z "$git_email" ]] || [[ "$FORCE_OVERWRITE" == "true" ]]; then
    print_status "GIT_CONFIG" "Git user info needed..."
    if [[ -n "$GIT_USER_NAME" ]] && [[ -n "$GIT_USER_EMAIL" ]]; then
      execute_and_log "git config --global user.name '$GIT_USER_NAME'" "Setting git user name" "GIT_CONFIG" || return 1
      execute_and_log "git config --global user.email '$GIT_USER_EMAIL'" "Setting git user email" "GIT_CONFIG" || return 1
    else
      print_warning "GIT_CONFIG" "No git credentials provided, using defaults"
      execute_and_log "git config --global user.name 'WSL User'" "Setting default git user name" "GIT_CONFIG" || return 1
      execute_and_log "git config --global user.email 'user@example.com'" "Setting default git user email" "GIT_CONFIG" || return 1
    fi
    execute_and_log "git config --global init.defaultBranch main" "Setting default branch" "GIT_CONFIG" || return 1
    execute_and_log "git config --global pull.rebase false" "Setting pull strategy" "GIT_CONFIG" || return 1
    execute_and_log "git config --global core.autocrlf input" "Setting line endings" "GIT_CONFIG" || return 1
  else
    print_success "GIT_CONFIG" "Git already configured for $git_name <$git_email>"
  fi

  # --- Clone Personal Dotfiles Repository ---
  print_status "PERSONAL_REPO" "Setting up personal dotfiles repository..."
  if [[ -n "$PERSONAL_REPO_URL" ]]; then
    if [ -z "$(ls -A "$PERSONAL_REPO_ROOT")" ] || [ ! -d "$PERSONAL_REPO_ROOT/.git" ]; then
      print_status "PERSONAL_REPO" "Cloning from $PERSONAL_REPO_URL..."
      execute_and_log "git clone '$PERSONAL_REPO_URL' '$PERSONAL_REPO_ROOT'" \
        "Cloning personal dotfiles repo" "PERSONAL_REPO" || return 1
    else
      print_warning "PERSONAL_REPO" "Directory $PERSONAL_REPO_ROOT is not empty. Skipping clone."
    fi
  else
    print_warning "PERSONAL_REPO" "No personal repository URL provided. Skipping clone."
  fi
}
