#!/bin/bash
###     file name: 1_sys_init.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/.
# shellcheck disable=SC2155

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
source "$SCRIPT_DIR/lib/5_install_dev.sh" || exit 1  # Now contains only dev-related package installs
source "$SCRIPT_DIR/lib/5_install_serv.sh" || exit 1 # Remains for service-related functions
source "$SCRIPT_DIR/lib/6_setup_tools.sh" || exit 1  # NEW: Consolidated tool setup & configs

# Export Repo
export REPO_ROOT="$(dirname "$SCRIPT_DIR")" # Define and export REPO_ROOT

# Initialize logging
init_logging || exit 1

# Source Directory setup (defines PRISTINE_DOTFILES_SRC, PACKAGE_LISTS_SRC etc.)
source "$SCRIPT_DIR/lib/3_set_dirs.sh"

# Pre-checks and initial setup
sync_wsl_time || exit 1
stabilise_keyring || exit 1
check_dependencies || exit 1

# Main installation flow
{
    print_status "MAIN" "Starting system initialization..."

    # System update and base dependencies
    update_system || exit 1

    # Filesystem and Pacman Configuration
    print_phase_start "MIRRORS" "Optimizing package mirrors..."
    optimise_mirrors || exit 1
    print_phase_end "MIRRORS" "Success"

    check_filesystem_health || {
        print_error "MAIN" "Filesystem health check failed, cannot continue"
        exit 1
    }
    optimise_pacman || exit 1

    # Locale Setup (essential for correct character display
    print_phase_start "SYSTEM_UPDATE" "Updating system packages..."
    setup_locale || exit 1
    print_phase_end "SYSTEM_UPDATE" "SUCCESS"

    # Base Package Installation
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

    # --- Consolidated Tool Configuration Phase ---
    print_phase_start "TOOL_CONFIGS" "Setting up user tools and configurations (Zsh, Tmux, Neovim, P10k, LSD)..."
    setup_shell || exit 1 # Sets Zsh as default shell, calls setup_zsh internally
    setup_p10k || exit 1
    setup_tmux || exit 1
    setup_neovim || exit 1
    setup_lsd_theme || exit 1
    print_phase_end "TOOL_CONFIGS" "SUCCESS"
    print_phase_end "CONFIGS" "SUCCESS"

    print_phase_start "GIT_Setup" "Setting up Git configuration..."
    setup_git_config || exit 1
    print_phase_end "GIT_CONFIG" "SUCCESS"

    # System Hooks and Services
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
