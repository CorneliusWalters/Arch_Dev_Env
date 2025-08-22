#!/bin/bash
###     file name: 4_syst_ready_fn.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/4_syst_ready_fn.sh

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check Dependencies
setup_environment_paths() {
  print_status "PATHS" "Setting up environment paths..."
  # Ensure personal repo exists immediately
  if [[ ! -d "$PERSONAL_REPO_ROOT/.git" ]]; then
    cd "$PERSONAL_REPO_ROOT"
    git init >/dev/null 2>&1
    git branch -M main >/dev/null 2>&1
  fi
}

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
  print_status "MIRROR" "Optimizing mirror list for best performance..."

  # Install reflector if it's not already present.
  if ! command_exists reflector; then
    execute_and_log "sudo pacman -S --noconfirm reflector" "Install reflector" "MIRROR" || return 1
  fi

  # Backup the current mirrorlist.
  execute_and_log "sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup" \
    "Backup mirrorlist" "MIRROR" || return 1

  # --- Resilient Strategy ---
  # Find the fastest, most up-to-date mirrors from a global pool.
  print_status "MIRROR" "Searching for the fastest available mirrors globally..."
  local reflector_cmd="sudo reflector --protocol https --latest 50 --age 12 --sort rate --save /etc/pacman.d/mirrorlist --download-timeout 15"

  if execute_and_log "$reflector_cmd" "Generating globally optimized mirror list" "MIRROR"; then
    print_success "MIRROR" "Globally optimized mirror list generated successfully."
    return 0
  fi

  # --- Fallback Strategy ---
  print_warning "MIRROR" "Reflector failed. Using a manual fallback list."

  execute_and_log "sudo bash -c 'cat > /etc/pacman.d/mirrorlist << EOF
# Arch Linux mirrorlist (Manual Fallback)
Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch
EOF'" "Creating basic mirror list" "MIRROR" || {
    print_error "MIRROR" "Failed to create manual fallback mirror list. Aborting."
    return 1
  }

  print_success "MIRROR" "Manual fallback mirror list created."
  return 0
}

update_system() {
  print_status "UPDT" "Performing critical system update..."

  # Step 1: Force a refresh of all package databases. -yy is critical.
  print_status "UPDT" "Step 1/4: Forcing package database refresh..."
  execute_and_log_with_retry "sudo pacman -Syy" 3 5 "UPDT" || return 1

  # Step 2: Update the keyring to ensure we have the latest signing keys.
  print_status "UPDT" "Step 2/4: Updating archlinux-keyring..."
  execute_and_log_with_retry "sudo pacman -S --noconfirm archlinux-keyring" 3 5 "UPDT" || return 1

  # Step 3: Update pacman itself. This is essential to handle repo structure changes.
  print_status "UPDT" "Step 3/4: Updating pacman package manager..."
  execute_and_log_with_retry "sudo pacman -S --noconfirm pacman" 3 5 "UPDT" || return 1

  # Step 4: Now, perform the full system upgrade.
  print_status "UPDT" "Step 4/4: Performing full system upgrade..."
  execute_and_log_with_retry "sudo pacman -Syu --noconfirm" 3 5 "UPDT" || return 1

  print_success "UPDT" "System update sequence completed successfully."
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
