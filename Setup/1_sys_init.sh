#!/bin/bash
###     file name: 1_sys_init.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/Setup/.
# shellcheck disable=SC2155

#######--- START OF FILE ---#######
# Main initialization script for WSL Arch Linux setup with step control
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

# Define available steps
declare -A STEPS=(
	["1"]="step_system_prep"
	["2"]="step_system_update"
	["3"]="step_mirror_optimization"
	["4"]="step_filesystem_config"
	["5"]="step_locale_setup"
	["6"]="step_base_packages"
	["7"]="step_dev_tools"
	["8"]="step_tool_configs"
	["9"]="step_ssh_setup" # Add this
	["10"]="step_git_setup"
	["11"]="step_hooks_services" # Increment this
)

declare -A STEP_NAMES=(
	["1"]="System Preparation (Time, Keyring, Dependencies)"
	["2"]="Critical System Update"
	["3"]="Mirror Optimization"
	["4"]="Filesystem Health & Pacman Configuration"
	["5"]="Locale Setup"
	["6"]="Base Package Installation & Environment Paths"
	["7"]="Development Tools & Environments"
	["8"]="User Tools & Dotfile Configuration"
	["9"]="Setup SSH Config"
	["10"]="Git Configuration"
	["11"]="System Hooks and Services"
)

# Step implementations
step_system_prep() {
	print_phase_start "SYSTEM_PREP" "Time Sync, Keyring, Dependencies"
	sync_wsl_time || exit 1
	stabilise_keyring || exit 1
	check_dependencies || exit 1
	print_phase_end "SYSTEM_PREP" "SUCCESS"
}

step_system_update() {
	print_phase_start "SYSTEM_UPDATE" "Critical System Update"
	update_system || exit 1
	print_phase_end "SYSTEM_UPDATE" "SUCCESS"
}

step_mirror_optimization() {
	print_phase_start "MIRRORS" "Optimizing package mirrors"
	optimise_mirrors || exit 1
	print_phase_end "MIRRORS" "SUCCESS"
}

step_filesystem_config() {
	print_phase_start "FILESYSTEM" "Filesystem Health & Pacman Configuration"
	check_filesystem_health || {
		print_error "MAIN" "Filesystem health check failed, cannot continue"
		exit 1
	}
	optimise_pacman || exit 1
	print_phase_end "FILESYSTEM" "SUCCESS"
}

step_locale_setup() {
	print_phase_start "SYSTEM_CONFIG" "Setting system-wide locale"
	setup_locale || exit 1
	print_phase_end "SYSTEM_CONFIG" "SUCCESS"
}

step_base_packages() {
	print_phase_start "BASE_PACKAGES" "Installing base packages and configuring environment paths"
	setup_environment_paths || exit 1 # Creates ~/.config/dotfiles git repo
	install_base_packages || exit 1   # Installs packages from base.installs & add.installs
	print_phase_end "BASE_PACKAGES" "SUCCESS"
}

step_dev_tools() {
	print_phase_start "DEV_TOOLS" "Installing development tools and Python environment"
	install_dev_tools || exit 1
	install_db_tools || exit 1
	install_python_environment || exit 1
	print_phase_end "DEV_TOOLS" "SUCCESS"
}

step_tool_configs() {
	print_phase_start "TOOL_CONFIGS" "Setting up user tools and configurations (Zsh, Tmux, Neovim, P10k, LSD, win32yank)"
	setup_shell || exit 1 # Sets Zsh as default shell, calls setup_zsh internally
	setup_p10k || exit 1
	setup_tmux || exit 1
	setup_neovim || exit 1
	setup_lsd_theme || exit 1
	print_phase_end "TOOL_CONFIGS" "SUCCESS"
}

step_git_setup() {
	print_phase_start "GIT_SETUP" "Setting up Git configuration and cloning personal repository"
	setup_git_config || exit 1
	print_phase_end "GIT_SETUP" "SUCCESS"
}

step_hooks_services() {
	print_phase_start "HOOKS" "Setting up system hooks and services (pacman sync, systemd, config watcher)"
	setup_pacman_git_hook || exit 1
	setup_systemd_enabler || exit 1
	setup_watcher_service || exit 1
	print_phase_end "HOOKS" "SUCCESS"
}

step_ssh_setup() {
	print_phase_start "SSH_SETUP" "Configuring SSH access and agent"

	# Only run if SSH keys exist
	if [[ -f ~/.ssh/id_ed25519 ]] || [[ -f ~/.ssh/id_rsa ]]; then
		setup_ssh_config || print_warning "SSH_SETUP" "SSH config setup had issues"
		setup_ssh_agent || print_warning "SSH_SETUP" "SSH agent setup had issues"
	else
		print_status "SSH_SETUP" "No SSH keys found, skipping SSH setup"
	fi

	print_phase_end "SSH_SETUP" "COMPLETE"
}

# Function to show available steps
show_help() {
	echo "Usage: $0 [OPTION]"
	echo ""
	echo "Options:"
	echo "  --help, -h          Show this help message"
	echo "  --list, -l          List all available steps"
	echo "  --step N            Run specific step number N (1-10)"
	echo "  --steps N-M         Run steps from N to M (e.g., 5-8)"
	echo "  --steps N,M,P       Run specific steps N, M, and P (e.g., 3,7,9)"
	echo ""
	echo "Examples:"
	echo "  $0                  Run all steps (default behavior)"
	echo "  $0 --step 3         Run only step 3 (Mirror Optimization)"
	echo "  $0 --steps 5-7      Run steps 5 through 7"
	echo "  $0 --steps 1,4,8    Run steps 1, 4, and 8 only"
	echo ""
}

# Function to list all steps
list_steps() {
	echo "Available steps:"
	echo ""
	for i in {1..11}; do
		printf "  %2d. %s\n" "$i" "${STEP_NAMES[$i]}"
	done
	echo ""
}

# Function to validate step number
validate_step() {
	local step=$1
	if [[ ! "$step" =~ ^[0-9]+$ ]] || [ "$step" -lt 1 ] || [ "$step" -gt 11 ]; then
		print_error "PARAM" "Invalid step number: $step (must be 1-10)"
		return 1
	fi
	return 0
}

# Function to parse and run specified steps
run_specified_steps() {
	local step_spec=$1
	local steps_to_run=()

	if [[ "$step_spec" =~ ^[0-9]+$ ]]; then
		# Single step
		validate_step "$step_spec" || exit 1
		steps_to_run=("$step_spec")
	elif [[ "$step_spec" =~ ^[0-9]+-[0-9]+$ ]]; then
		# Range of steps (e.g., 5-8)
		local start_step=$(echo "$step_spec" | cut -d'-' -f1)
		local end_step=$(echo "$step_spec" | cut -d'-' -f2)
		validate_step "$start_step" || exit 1
		validate_step "$end_step" || exit 1

		if [ "$start_step" -gt "$end_step" ]; then
			print_error "PARAM" "Invalid range: start step ($start_step) is greater than end step ($end_step)"
			exit 1
		fi

		for ((i = start_step; i <= end_step; i++)); do
			steps_to_run+=("$i")
		done
	elif [[ "$step_spec" =~ ^[0-9,]+$ ]]; then
		# Comma-separated steps (e.g., 1,4,8)
		IFS=',' read -ra step_array <<<"$step_spec"
		for step in "${step_array[@]}"; do
			validate_step "$step" || exit 1
			steps_to_run+=("$step")
		done
	else
		print_error "PARAM" "Invalid step specification: $step_spec"
		echo "Use --help for usage information."
		exit 1
	fi

	# Execute the specified steps
	print_status "MAIN" "Running specified steps: ${steps_to_run[*]}"

	for step_num in "${steps_to_run[@]}"; do
		local step_func="${STEPS[$step_num]}"
		local step_name="${STEP_NAMES[$step_num]}"

		print_status "MAIN" "=== STEP $step_num: $step_name ==="

		if declare -f "$step_func" >/dev/null; then
			$step_func || {
				print_error "MAIN" "Step $step_num failed: $step_name"
				exit 1
			}
		else
			print_error "MAIN" "Step function not found: $step_func"
			exit 1
		fi
	done
}

# Function to run all steps (original behavior)
run_all_steps() {
	print_status "MAIN" "Starting system initialization (all steps)..."

	step_system_prep
	step_system_update
	step_mirror_optimization
	step_filesystem_config
	step_locale_setup
	step_base_packages
	step_dev_tools
	step_tool_configs
	step_git_setup
	step_hooks_services

	print_success "MAIN" "Installation complete!"
	print_status "MAIN" "Please log out and log back in for all changes to take effect."
	print_status "MAIN" "After logging back in, run 'nvim' and wait for plugins to install."
	print_status "MAIN" "Check logs at: $LOGFILE"
}

# --- Parameter Processing ---
case "${1:-}" in
--help | -h)
	show_help
	exit 0
	;;
--list | -l)
	list_steps
	exit 0
	;;
--step)
	if [ -z "${2:-}" ]; then
		print_error "PARAM" "--step requires a step number"
		show_help
		exit 1
	fi
	run_specified_steps "$2"
	;;
--steps)
	if [ -z "${2:-}" ]; then
		print_error "PARAM" "--steps requires a step specification"
		show_help
		exit 1
	fi
	run_specified_steps "$2"
	;;
"")
	# No parameters - run all steps (original behavior)
	run_all_steps
	;;
*)
	print_error "PARAM" "Unknown option: $1"
	show_help
	exit 1
	;;
esac
