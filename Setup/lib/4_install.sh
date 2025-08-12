#!/bin/bash

#######--- START OF FILE ---#######
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
##mount_with_retry() {
##    local attempts=0
##    until mount -t drvfs C: /mnt/c; do
##        ((attempts++))
##        if [ $attempts -ge 5 ]; then
##            echo "Failed to mount C: drive after 5 attempts"
##            return 1
##        fi
##        sleep 2
##    done
##}

test_caller_logging() {
    print_status "TEST" "Starting logging system test"
    log_message "INFO" "TEST" "Call stack information:"
    log_message "INFO" "TEST" "BASH_SOURCE: ${BASH_SOURCE[@]}"
    log_message "INFO" "TEST" "FUNCNAME: ${FUNCNAME[@]}"
    log_message "INFO" "TEST" "BASH_LINENO: ${BASH_LINENO[@]}"
    
    execute_and_log "false" "Test caller logging" "DEBUG"
    local test_result=$?
    
    if [ $test_result -ne 0 ]; then
        log_message "TEST" "DEBUG" "Test failed as expected (this is normal for testing)"
    fi
    
    return $test_result
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
        if echo "test" > "$location/filesystem_test" 2>/dev/null; then
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
setup_systemd_enabler() {
    print_status "SYSTEMD" "Checking for systemd enabler (distrod)..."

    # Check if systemd is already the init process (PID 1)
    if [ "$(ps -p 1 -o comm=)" = "systemd" ]; then
        print_success "SYSTEMD" "Systemd is already active (PID 1)."
        return 0
    fi
    
    # If distrod is installed but not active, we might just need to enable it.
    if command -v distrod >/dev/null 2>&1; then
        print_warning "SYSTEMD" "distrod command exists, but systemd is not PID 1. Attempting to enable..."
    else
        print_status "SYSTEMD" "distrod not found, proceeding with full installation."
    fi

    # --- Installation Phase ---
    # FIX 1: Follow the README - download the install.sh script directly.
    local install_script_path="/tmp/distrod_install.sh"
    local install_url="https://raw.githubusercontent.com/nullpo-head/wsl-distrod/main/install.sh"

    print_status "SYSTEMD" "Downloading distrod installer script..."
    if ! execute_and_log "curl -L --fail -o '$install_script_path' '$install_url'" \
        "Downloading distrod installer" "SYSTEMD"; then
        print_error "SYSTEMD" "Failed to download the distrod installer script."
        return 1
    fi

    execute_and_log "chmod +x '$install_script_path'" \
        "Making installer executable" "SYSTEMD" || return 1

    # FIX 2: Run the installer with the required 'install' argument.
    print_status "SYSTEMD" "Running the distrod installer..."
    if ! execute_and_log "sudo '$install_script_path' install" \
        "Installing distrod" "SYSTEMD"; then
        print_error "SYSTEMD" "distrod installation script failed."
        return 1
    fi

    # --- Enablement Phase ---
    # FIX 3: Add the critical, missing 'distrod enable' command.
    local distrod_binary="/opt/distrod/bin/distrod"
    if [ ! -f "$distrod_binary" ]; then
        print_error "SYSTEMD" "distrod binary not found at $distrod_binary after installation."
        return 1
    fi

    print_status "SYSTEMD" "Appending default user to distrod's wsl.conf..."
    # This command safely appends the [user] section to the wsl.conf file
    # that distrod has just created or configured.
    local set_user_cmd="printf '\n[user]\ndefault = %s\n' '$USER' | sudo tee -a /etc/wsl.conf"

    if ! execute_and_log "$set_user_cmd" \
        "Setting default user in /etc/wsl.conf" "SYSTEMD"; then
        print_warning "SYSTEMD" "Could not set default user. You may need to log in as root first."
        # This is not a fatal error, so we don't return 1.
    fi
    
    print_status "SYSTEMD" "Enabling distrod to take over the init process..."
    if ! execute_and_log "sudo '$distrod_binary' enable" \
        "Enabling distrod" "SYSTEMD"; then
        print_error "SYSTEMD" "Failed to enable distrod."
        return 1
    fi

    # --- Final Steps ---
    execute_and_log "rm -f '$install_script_path'" "Cleaning up installer script" "SYSTEMD"

    print_success "SYSTEMD" "distrod has been installed and enabled successfully."
    # FIX 4: Add the final, crucial warning about restarting.
    print_warning "SYSTEMD" "A FULL WSL SHUTDOWN ('wsl --shutdown') is required to activate systemd."
    print_warning "SYSTEMD" "The main PowerShell script should handle this restart."
    
    return 0
}

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

#Create Config Watcher 
setup_watcher_service() {
    print_status "WATCHER" "Setting up config file watcher service..."

    local watcher_script="$REPO_ROOT/Setup/lib/config/watcher.sh"
    # This assumes you've renamed the script as I recommended earlier.
    # If not, change generate_and_commit_patch.sh to 6_commit_config.sh
    local commit_script="$REPO_ROOT/Setup/lib/generate_and_commit_patch.sh"
    local service_file_path="$HOME/.config/systemd/user/config-watcher.service"
    local zshrc_file="$HOME/.config/zsh/.zshrc"

    # Make scripts executable
    chmod +x "$watcher_script" "$commit_script"

    # Create systemd user directory
    mkdir -p "$HOME/.config/systemd/user/"

    # Create the service file
    # This part is unchanged
    cat > "$service_file_path" << EOL
[Unit]
Description=Watches for user config file changes and commits them to Git.
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/bash $watcher_script
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOL

    # --- NEW LOGIC: Add a one-shot enabler to .zshrc ---
    print_status "WATCHER" "Adding one-shot service enabler to .zshrc"

    # This block of code will be added to the end of the user's .zshrc.
    # It runs once, enables the service, and then does nothing on subsequent shell starts.
    cat >> "$zshrc_file" << 'EOL'

# --- One-shot service enabler for config-watcher ---
# This block will run only once after the initial setup.
if ! systemctl --user is-enabled -q config-watcher.service; then
    echo "First-time setup: Enabling and starting config-watcher service..."
    systemctl --user enable --now config-watcher.service
    echo "Config watcher is now active."
fi
# --- End one-shot enabler ---
EOL

    print_success "WATCHER" "Config watcher service file created. It will be enabled automatically on the next shell start."
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
#######--- END OF FILE ---#######

