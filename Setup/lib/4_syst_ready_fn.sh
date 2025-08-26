#!/bin/bash
###     file name: 4_syst_ready_fn.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.
# shellcheck disable=SC2206
# shellcheck disable=SC1090
# shellcheck disable=SC2296
# shellcheck disable=SC2155
# shellcheck disable=SC2164

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

get_packages_from_file() {
  local file_path=$1
  if [ -f "$file_path" ]; then
    # Filter out comments and empty lines, then join with spaces.
    grep -Ev '^#|^$' "$file_path" | tr '\n' ' '
  fi
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

  # Check Python Deps
  # before installing reflector, which depends on it.
  execute_and_log "sudo pacman -S --noconfirm --needed python" "Ensuring Python is installed" "MIRROR" || return 1

  # Step 2: Install reflector.
  if ! command_exists reflector; then
    execute_and_log "sudo pacman -S --noconfirm reflector" "Install reflector" "MIRROR" || return 1
  fi

  # Step 3: Backup the current, known-working mirrorlist.
  execute_and_log "sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup" \
    "Backup current mirrorlist" "MIRROR" || return 1

  # Step 4: Attempt to generate a faster mirrorlist.
  print_status "MIRROR" "Attempting to generate a faster mirror list with reflector..."
  local reflector_cmd="sudo reflector --protocol https --latest 50 --age 12 --sort rate --save /etc/pacman.d/mirrorlist --download-timeout 15"

  # We run this command but don't exit if it fails.
  eval "$reflector_cmd"
  local exit_code=$?

  # Step 5: Check the result and recover safely if needed.
  if [ $exit_code -eq 0 ]; then
    print_success "MIRROR" "Reflector successfully generated an optimized mirror list."
  else
    print_warning "MIRROR" "Reflector failed to generate a new list (Exit Code: $exit_code)."
    print_warning "MIRROR" "This is non-fatal. Restoring the previous working mirrorlist."
    # --- THE CRITICAL FIX ---
    # Restore the known-good mirrorlist instead of writing a bad one.
    execute_and_log "sudo cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist" \
      "Restoring backup mirrorlist" "MIRROR"
  fi

  # This function should always succeed, as having a working-but-unoptimized
  # mirrorlist is an acceptable outcome.
  return 0
}

update_system() {
  print_status "UPDT" "Performing critical system update..."

  # Step 1: Force a refresh of all package databases. -yy is critical.
  print_status "UPDT" "Step 1/5: Forcing package database refresh..."
  execute_and_log_with_retry "sudo pacman -Syy" 3 5 "UPDT" || return 1

  # Step 2: Update the keyring to ensure we have the latest signing keys.
  print_status "UPDT" "Step 2/5: Updating archlinux-keyring..."
  execute_and_log_with_retry "sudo pacman -S --noconfirm archlinux-keyring" 3 5 "UPDT" || return 1

  # Step 3: Update pacman itself. This is essential to handle repo structure changes.
  print_status "UPDT" "Step 3/5: Updating pacman package manager..."
  execute_and_log_with_retry "sudo pacman -S --noconfirm pacman" 3 5 "UPDT" || return 1

  # Step 4: Now, perform the full system upgrade.
  print_status "UPDT" "Step 4/5: Performing full system upgrade..."
  execute_and_log_with_retry "sudo pacman -Syu --noconfirm" 3 5 "UPDT" || return 1

  # Step 5: Explicitly rebuild the system's certificate trust store.
  print_status "UPDT" "Step 5/5: Rebuilding certificate trust store..."
  execute_and_log "sudo update-ca-trust" "Rebuilding CA trust" "UPDT" || return 1

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
  print_status "PACKAGES" "Installing base dependencies..."

  # Read the core package list from its file.
  local base_pkgs=$(get_packages_from_file "$PACKAGE_LISTS_SRC/base.installs")

  # --- MODIFIED: Read additional packages from 'add.installs' ---
  local additional_pkgs_file="$PACKAGE_LISTS_SRC/add.installs"
  local additional_pkgs=$(get_packages_from_file "$additional_pkgs_file")

  if [ -n "$additional_pkgs" ]; then
    print_status "PACKAGES" "Including additional packages from '$additional_pkgs_file'."
  fi

  # Combine the lists.
  local all_pkgs="$base_pkgs $additional_pkgs"

  if [ -z "$all_pkgs" ]; then
    print_warning "PACKAGES" "No packages to install."
    return 0
  fi

  execute_and_log "sudo pacman -S --needed --noconfirm $all_pkgs" \
    "Installing base and additional dependencies" "PACKAGES" || return 1
}
