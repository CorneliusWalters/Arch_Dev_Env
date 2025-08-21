#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}
# Check Dependencies

check_dependencies() {
  local deps=("git" "curl" "sudo")
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      print_error "Required dependency not found: $dep"
      return 1
    fi
  done
}

stabilise_keyring() {
  print_status "KEYRING" "Initializing pacman keyring..."

  # Clean existing state
  execute_and_log "sudo rm -rf /etc/pacman.d/gnupg" "Clean keyring" "KEYRING"
  execute_and_log "sudo pkill gpg-agent || true" "Stop key processes" "KEYRING"

  # Initialize keyring
  execute_and_log_with_retry "sudo pacman-key --init" 3 5 "KEYRING"
  execute_and_log "sudo chmod 700 /etc/pacman.d/gnupg" "Set permissions" "KEYRING"

  # Temporarily allow weak signatures for initial setup
  execute_and_log "echo 'allow-weak-key-signatures' | sudo tee -a /etc/pacman.d/gnupg/gpg.conf" \
    "Allow weak keys" "KEYRING"

  # Populate keys with retry logic
  execute_and_log_with_retry "sudo pacman-key --populate archlinux" 3 5 "KEYRING"

  # Remove weak signature allowance
  execute_and_log "sudo sed -i '/allow-weak-key-signatures/d' /etc/pacman.d/gnupg/gpg.conf" \
    "Remove weak key allowance" "KEYRING"

  return 0
}

optimise_pacman() {
  print_status "PACMAN" "Optimizing pacman configuration"

  # Enable parallel downloads, color, and multilib
  execute_and_log "sudo sed -i \
        -e 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' \
        -e 's/^#Color/Color/' \
        -e 's/^#\[multilib\]/\[multilib\]/; /^\[multilib\]/,/Include/ s/^#Include/Include/' \
        /etc/pacman.conf" \
    "Optimise pacman.conf" \
    "PACMAN" || return 1

  # Update databases with new configuration
  execute_and_log "sudo pacman -Syy" \
    "Refresh package databases" \
    "PACMAN" || return 1
}
check_filesystem_health() {
  print_status "HEALTH" "Checking filesystem health..."

  # Test if we can write to various locations
  local test_locations=("/tmp" "$HOME" "/var/tmp")
  local working_location=""

  for location in "${test_locations[@]}"; do
    if echo "test" >"$location/filesystem_test" 2>/dev/null; then
      rm "$location/filesystem_test" 2>/dev/null
      working_location="$location"
      break
    fi
  done

  if [[ -z "$working_location" ]]; then
    print_error "HEALTH" "Critical: No writable filesystem locations found"
    return 1
  fi

  # Update LOGFILE to use working location if needed
  if [[ ! -w "$(dirname "$LOGFILE")" ]]; then
    export LOGFILE="$working_location/wsl_install_$(date +%Y%m%d_%H%M%S).log"
    print_warning "HEALTH" "Switched to fallback log location: $LOGFILE"
  fi

  return 0
}

sync_wsl_time() {
  print_status "TIME" "Synchronizing WSL system time with Windows host..."

  # Force time sync from Windows host
  local wintime
  if wintime=$(powershell.exe -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'" 2>/dev/null); then
    execute_and_log "sudo date -s \"$wintime\"" \
      "Setting system time from Windows host" "TIME"
  else
    print_warning "TIME" "Cannot access Windows PowerShell from WSL, using system time"
  fi

  print_status "TIME" "Current system time: $(date)"
}
optimise_mirrors() {
  print_status "MIRROR" "Updating mirror list"

  # Install reflector if needed
  if ! command_exists reflector; then
    execute_and_log "sudo pacman -S --noconfirm reflector" \
      "Install reflector" \
      "MIRROR" || {
      # Fallback if reflector install fails
      print_warning "MIRROR" "Reflector install failed, using manual mirror setup"

      # Create a basic mirror list with reliable mirrors
      execute_and_log "sudo bash -c 'cat > /etc/pacman.d/mirrorlist << EOF
# Arch Linux mirrorlist
# Generated with manual fallback
Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch
Server = https://arch.mirror.constant.com/\$repo/os/\$arch
Server = https://mirror.f4st.host/archlinux/\$repo/os/\$arch
EOF'" "Creating basic mirror list" "MIRROR"
      return 0
    }
  fi

  # Backup original mirrorlist
  execute_and_log "sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup" \
    "Backup mirrorlist" \
    "MIRROR" || return 1

  # Try multiple mirror generation strategies
  local success=0

  # Strategy 1: Try with South Africa mirrors first
  if execute_and_log "sudo reflector --country ZA --protocol https --latest 50 --sort rate --save /etc/pacman.d/mirrorlist" \
    "Generating South Africa mirror list" "MIRROR"; then
    success=1
  # Strategy 2: Try global mirrors
  elif execute_and_log "sudo reflector --protocol https --latest 100 --sort rate --save /etc/pacman.d/mirrorlist" \
    "Generating global mirror list" "MIRROR"; then
    success=1
  # Strategy 3: Try specific reliable mirrors
  elif execute_and_log "sudo reflector --country US,GB,DE --protocol https --latest 50 --sort rate --save /etc/pacman.d/mirrorlist" \
    "Generating US/GB/DE mirror list" "MIRROR"; then
    success=1
  # Final fallback: Create manual list
  else
    print_warning "MIRROR" "All reflector strategies failed, using manual fallback"

    execute_and_log "sudo bash -c 'cat > /etc/pacman.d/mirrorlist << EOF
# Arch Linux mirrorlist
# Generated with manual fallback
Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch
Server = https://arch.mirror.constant.com/\$repo/os/\$arch
Server = https://mirror.f4st.host/archlinux/\$repo/os/\$arch
EOF'" "Creating basic mirror list" "MIRROR"
    success=1
  fi

  if [ $success -eq 1 ]; then
    print_success "MIRROR" "Mirror list updated successfully"
    return 0
  else
    print_error "MIRROR" "Failed to generate any working mirror list"
    return 1
  fi
}
update_system() {
  print_status "UPDT" "Updating system packages..."
  execute_and_log "sudo pacman -Syu --noconfirm" \
    "Installing Update" \
    "UPDT" || return 1
}

setup_locale() {
  print_status "LOCALE" "Setting up system-wide locale..."

  # Enable locale in locale.gen
  execute_and_log "sudo sed -i 's/#en_ZA.UTF-8/en_ZA.UTF-8/' /etc/locale.gen" \
    "Uncommenting en_ZA.UTF-8 in locale.gen" \
    "LOCALE" || return 1

  # Create system-wide locale.conf
  execute_and_log "sudo tee /etc/locale.conf << 'EOL'
LANG=en_ZA.UTF-8
LC_ALL=en_ZA.UTF-8
LC_CTYPE=en_ZA.UTF-8
LC_NUMERIC=en_ZA.UTF-8
LC_TIME=en_ZA.UTF-8
LC_COLLATE=en_ZA.UTF-8
LC_MONETARY=en_ZA.UTF-8
LC_MESSAGES=en_ZA.UTF-8
LC_PAPER=en_ZA.UTF-8
LC_NAME=en_ZA.UTF-8
LC_ADDRESS=en_ZA.UTF-8
LC_TELEPHONE=en_ZA.UTF-8
LC_MEASUREMENT=en_ZA.UTF-8
LC_IDENTIFICATION=en_ZA.UTF-8
EOL" \
    "Setting system-wide locale configuration" \
    "LOCALE" || return 1

  # Generate locales
  execute_and_log "sudo locale-gen" \
    "Generating locales" \
    "LOCALE" || return 1

  print_success "LOCALE" "System-wide locale configuration complete"
}

install_base_packages() {
  print_status "Packages" "Installing base dependencies..."

  # Define a core set of packages that are always installed
  local CORE_BASE_DEPS="base-devel git github-cli bat cmake ninja zsh tmux neovim htop btop duf ncdu bat lsd ripgrep fd fzf zoxide lazygit git-delta jq yq shellcheck tree tree-sitter unzip zip tar wl-clipboard xclip curl wget httpie procs tldr man-db man-pages inotify-tools"

  # Path to the dynamically generated package list within the Git repository
  local CUSTOM_PACKAGES_FILE="$REPO_ROOT/installed_packages.txt" # Assuming REPO_ROOT is accessible and correct

  local ALL_DEPS="$CORE_BASE_DEPS"

  # Check if the custom package list exists and add its content
  if [ -f "$CUSTOM_PACKAGES_FILE" ]; then
    # Read the file line by line and add to ALL_DEPS, handling newlines
    local additional_pkgs
    additional_pkgs=$(cat "$CUSTOM_PACKAGES_FILE" | tr '\n' ' ')
    ALL_DEPS="$ALL_DEPS $additional_pkgs"
    print_status "Packages" "Including additional packages from $CUSTOM_PACKAGES_FILE."
  else
    print_warning "Packages" "No custom package list found at $CUSTOM_PACKAGES_FILE. Installing only core base dependencies."
  fi

  execute_and_log "sudo pacman -S --needed --noconfirm $ALL_DEPS" \
    "Installing core and custom dependencies" \
    "Packages" || return 1
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
