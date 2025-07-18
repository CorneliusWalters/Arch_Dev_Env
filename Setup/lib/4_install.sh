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

sync_wsl_time() {
    print_status "TIME" "Synchronizing WSL system time with Windows host..."
    
    # Disable and stop timesyncd if it exists
    if command_exists systemctl; then
        execute_and_log "sudo systemctl stop systemd-timesyncd || true" \
            "Stop timesyncd service if it exists" "TIME"
        execute_and_log "sudo systemctl disable systemd-timesyncd || true" \
            "Disable timesyncd service if it exists" "TIME"
    fi
    
    # Force time sync from Windows host
    local wintime=$(powershell.exe -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'")
    if [ -n "$wintime" ]; then
        execute_and_log "sudo date -s \"$wintime\"" \
            "Setting system time from Windows host" "TIME"
    else
        print_warning "TIME" "Failed to get time from Windows host, trying NTP"
        execute_and_log "sudo timedatectl set-ntp true" \
            "Enable NTP time synchronization" "TIME"
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
setup_config_watcher_service() {
    print_status "WATCHER" "Setting up config file watcher service..."

    local watcher_script="$REPO_ROOT/Setup/lib/config/watcher.sh"
    local commit_script="$REPO_ROOT/Setup/lib/6_commit_config.sh"
    local service_file_path="$HOME/.config/systemd/user/config-watcher.service"

    # Make scripts executable
    chmod +x "$watcher_script" "$commit_script"

    # Create systemd user directory
    mkdir -p "$HOME/.config/systemd/user/"

    # Create the service file
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

    # Enable and start the service as the user
    # We need to run this as the user, not root
    execute_and_log "systemctl --user daemon-reload" "Reloading systemd user daemon" "WATCHER"
    execute_and_log "systemctl --user enable config-watcher.service" "Enabling watcher service" "WATCHER"
    execute_and_log "systemctl --user start config-watcher.service" "Starting watcher service" "WATCHER"

    print_success "WATCHER" "Config watcher service has been set up and started."
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

    # Copy the sync script and make it executable
    execute_and_log "sudo cp \"$sync_script_source\" \"$sync_script_target\"" \
        "Copying package sync script to $sync_script_target" "HOOK_SETUP" || return 1
    execute_and_log "sudo chmod +x \"$sync_script_target\"" \
        "Making package sync script executable" "HOOK_SETUP" || return 1

    # Create the pacman hook file
    # Use tee to write to the hook file with sudo
    execute_and_log "sudo bash -c 'cat > \"$hook_file\" << EOL
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
EOL'" "Creating pacman hook file $hook_file" "HOOK_SETUP" || return 1

    print_success "HOOK_SETUP" "Pacman Git sync hook setup complete."
}
#######--- END OF FILE ---#######

