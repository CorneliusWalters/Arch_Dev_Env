#!/bin/bash

##------Structure
##      Git/Setup/
##      ├── 1_sys_init.sh           # Main script
##      ├── Install.ps1             # Power Shell Install Script
##      ├── PowerShell
##      │   ├── Export-Image.ps1    # Exports WSL distro image after install for easy redo
##      │   ├── Import-Distro.ps1   # Import the distro image
##      │   ├── Logging.ps1         # Logging functions
##      │   ├── Test.ps1            # Checks your WSL version
##      │   └── Utils.ps1           # Setup Utilities
##      ├── lib
##      │   ├── 2_logging.sh        # Logging functions
##      │   ├── 3_set_dirs.sh       # create directories and set scripts as executable
##      │   ├── 4_install.sh        # Package/Main installation functions
##      │   ├── 5_sync_packs.sh     # hooks and script patch functionality
##      │   ├── 6_commit_config.sh  # git functionality to make changes to your repo
##      │   ├── 99_wrapper.sh       # Wrapper function to execute from powershell to kick off seemless instalation
##      │   ├── config
##      │   │   ├── nvim.sh         # Neovim configurations
##      │   │   ├── tmux.sh         # Tmux configurations
##      │   │   ├── zsh.sh          # Zsh configurations
##      │   │   ├── p10k.sh         # P10k configurations
##      │   │   ├── zxc_nvim.sh     #cat configuration files for NVIM
##      │   │   ├── zxc_tmux.sh     #cat configuration files for TMUX
##      │   │   ├── zxc_zsh.sh      #cat configuration files for ZSH
##      └   └   └── zxc_p10k.sh     #cat configuration files for ZSH p10K

#######--- START OF FILE ---#######
# Main initialization script for WSL Arch Linux setup
# Exit on any error
set -e

# set directory source
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Source all library functions
source "$SCRIPT_DIR/lib/2_logging.sh" || exit 1
source "$SCRIPT_DIR/lib/4_syst_ready_fn.sh" || exit 1

# Export Repo
export REPO_ROOT="$(dirname "$SCRIPT_DIR")" # Define and export REPO_ROOT

# Initialize logging
init_logging || exit 1

# Source Directory setup
source "$SCRIPT_DIR/lib/3_set_dirs.sh"

# Source instaltion Functions
source "$SCRIPT_DIR/lib/5_install_dev.sh"
source "$SCRIPT_DIR/lib/5_install_serv.sh"

# Source Tools setup & Configuration
source "$SCRIPT_DIR/lib/6_setup_tools.sh"

#test_caller_logging
#exit
sync_wsl_time || exit 1
stabilise_keyring || exit 1
check_dependencies || exit 1

# Main installation flow
{
    print_status "MAIN" "Starting system initialization..."

    # System update and base dependencies
    update_system || exit 1
    # After check_dependencies

    print_phase_start "MIRRORS" "Optimizing package mirrors..."
    optimise_mirrors || exit 1
    print_phase_end "MIRRORS" "Success"

    check_filesystem_health || {
        print_error "MAIN" "Filesystem health check failed, cannot continue"
        exit 1
    }
    optimise_pacman || exit 1

    print_phase_start "SYSTEM_UPDATE" "Updating system packages..."
    setup_locale || exit 1
    print_phase_end "SYSTEM_UPDATE" "SUCCESS"

    print_phase_start "BASE_PACKAGES" "Installing base packages and setting GIT config path..."
    setup_environment_paths || exit 1
    install_base_packages || exit 1
    print_phase_end "BASE_PACKAGES" "SUCCESS"

    # Development tools
    print_phase_start "DEV_TOOLS" "Installing development tools..."
    install_dev_tools || exit 1
    install_db_tools || exit 1
    install_python_environment || exit 1
    print_phase_end "DEV_TOOLS" "SUCCESS"

    # source Configurations

    print_phase_start "CONFIGS" "Setting up configurations..."

    source "$SCRIPT_DIR/lib/config/tmux.sh"
    source "$SCRIPT_DIR/lib/config/zsh.sh"
    source "$SCRIPT_DIR/lib/config/nvim.sh"
    source "$SCRIPT_DIR/lib/config/p10k.sh"

    # Configurations
    setup_shell || exit 1
    setup_p10k || exit 1
    setup_tmux || exit 1
    setup_neovim || exit 1

    print_phase_end "CONFIGS" "SUCCESS"

    print_phase_start "GIT_Setup" "Setting up Git configuration..."
    setup_git_config || exit 1
    print_phase_end "GIT_CONFIG" "SUCCESS"

    print_phase_start "HOOKS" "Setting up system hooks..."
    setup_pacman_git_hook || exit 1
    setup_systemd_enabler || exit 1
    setup_watcher_service || exit 1
    print_phase_end "HOOKS" "SUCCESS"

    print_success "MAIN" "Installation complete!"
    print_status "MAIN" "Please log out and log back in for all changes to take effect."
    print_status "MAIN" "After logging back in, run 'nvim' and wait for plugins to install."
    print_status "MAIN" "Check logs at: $LOGFILE"
} || {
    print_phase_end "INIT" "ERROR"
    print_error "MAIN" "Installation failed. Check logs at: $LOGFILE"
    exit 1
}
