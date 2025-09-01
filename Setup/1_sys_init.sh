#!/bin/bash
###     file name: 1_sys_init.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/Setup/.
# shellcheck disable=SC2155

#######--- START OF FILE ---#######
# Main initialization script for WSL Arch Linux setup
# Exit on any error
set -e

# set directory source (directory of this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Source core library functions (order matters!)
source "$SCRIPT_DIR/lib/2_logging.sh" || exit 1
source "$SCRIPT_DIR/lib/4_syst_ready_fn.sh" || exit 1 # Contains get_packages_from_file now
source "$SCRIPT_DIR/lib/5_install_dev.sh" || exit 1   # Contains dev/db/python installs
source "$SCRIPT_DIR/lib/5_install_serv.sh" || exit 1  # Contains service/hook installs
source "$SCRIPT_DIR/lib/6_setup_tools.sh" || exit 1   # NEW: Consolidated tool setup & configs

# Export Repository Root (one level up from Setup/)
export REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Initialize logging (this sets up LOG_DIR and LOGFILE)
init_logging || exit 1

# Source Directory setup (defines PRISTINE_ROOT, PRISTINE_DOTFILES_SRC, PACKAGE_LISTS_SRC etc.)
source "$SCRIPT_DIR/lib/3_set_dirs.sh" || exit 1

# --- Main Installation Flow ---
{
    print_status "MAIN" "Starting system initialization..."

    # Step 1: Time Sync, Keyring, Dependencies (Always first)
    sync_wsl_time || exit 1
    stabilise_keyring || exit 1
    check_dependencies || exit 1

    # Step 2: Critical System Update (Handles Arch repo changes)
    update_system || exit 1

    # Step 3: Mirror Optimization (Happens AFTER update_system makes pacman functional)
    print_phase_start "MIRRORS" "Optimizing package mirrors..."
    optimise_mirrors || exit 1
    print_phase_end "MIRRORS" "SUCCESS"

    # Step 4: Filesystem Health & Pacman Configuration
    check_filesystem_health || {
        print_error "MAIN" "Filesystem health check failed, cannot continue"
        exit 1
    }
    optimise_pacman || exit 1

    # Step 5: Locale Setup (Essential for correct character display)
    print_phase_start "SYSTEM_CONFIG" "Setting system-wide locale..."
    setup_locale || exit 1
    print_phase_end "SYSTEM_CONFIG" "SUCCESS"

    # Step 6: Base Package Installation & Environment Paths
    print_phase_start "BASE_PACKAGES" "Installing base packages and configuring environment paths..."
    setup_environment_paths || exit 1 # Creates ~/.config/dotfiles git repo
    install_base_packages || exit 1   # Installs packages from base.installs & add.installs
    print_phase_end "BASE_PACKAGES" "SUCCESS"

    # Step 7: Development Tools & Environments Installation
    print_phase_start "DEV_TOOLS" "Installing development tools and Python environment..."
    install_dev_tools || exit 1
    install_db_tools || exit 1
    install_python_environment || exit 1
    print_phase_end "DEV_TOOLS" "SUCCESS"

    # Step 8: Consolidated User Tools & Dotfile Configuration
    print_phase_start "TOOL_CONFIGS" "Setting up user tools and configurations (Zsh, Tmux, Neovim, P10k, LSD, win32yank)..."
    setup_shell || exit 1 # Sets Zsh as default shell, calls setup_zsh internally
    setup_p10k || exit 1
    setup_tmux || exit 1
    setup_neovim || exit 1
    setup_lsd_theme || exit 1
    print_phase_end "TOOL_CONFIGS" "SUCCESS"

    # Step 9: Git Configuration (user info and personal repo clone)
    print_phase_start "GIT_SETUP" "Setting up Git configuration and cloning personal repository..."
    setup_git_config || exit 1
    print_phase_end "GIT_SETUP" "SUCCESS"

    # Step 10: System Hooks and Services
    print_phase_start "HOOKS" "Setting up system hooks and services (pacman sync, systemd, config watcher)..."
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
