# Arch Dev Enviroment: WSL Arch Linux Development Environment Setup

This repository provides a fully automated and opinionated setup for a powerful Arch Linux development environment running inside Windows Subsystem for Linux (WSL). The goal is a "ready-as-is" configuration, allowing for quick and consistent deployment across multiple machines.

## Table of Contents

- [1. File Structure](#1-File-Structure)
- [2. Features](#2-features)
- [3. Prerequisites](#3-prerequisites)
- [4. Quick Start](#4-quick-start)
- [5. Locale Configuration**](#5-locale-configuration)
- [6. Post-Installation Steps](#6-post-installation-steps)
- [7. Configuration Management](#7-Configuration-Management)
- [8. Customizing Your Environment (Forking & Modifying)](#8-customizing-your-environment-forking--modifying)
- [9. Troubleshooting](#9-troubleshooting)
- [10. Usage](#10-usage)
- [License](#license)
---
## 1. File Structure
```
Arch_Dev_Env/
├── Setup/                       # Main setup directory
│   ├── 1_sys_init.sh            # Main Bash setup script 
│   ├── Install.ps1              # Main PowerShell installation script ⚠️ **MODIFY THIS FIRST**
│   ├── PowerShell/              # Modular PowerShell components
│   │   ├── Export-Image.ps1     # Exports WSL distro image after install
│   │   ├── Import-Distro.ps1    # Imports and configures WSL distro
│   │   ├── Logging.ps1          # PowerShell logging functionality
│   │   ├── Test.ps1             # WSL version and prerequisite tests
│   │   └── Utils.ps1            # WSL run utilities used by primary Install.ps1 script
│   └── lib/                     # Bash library functions
│       ├── 0_prepare_root.sh    # prepare required packages and set user enviroment
│       ├── 2_set_dirs.sh        # Directory creation and permissions
│       ├── 3_logging.sh         # Bash logging functions
│       ├── 4_install.sh         # Package installation functions
│       ├── 5_sync_packs.sh      # Package list synchronization
│       ├── snapshots.sh         # WSL snapshot functions (currently disabled)
│       └── config/              # Configuration templates
│           ├── nvim.sh          # Neovim setup functions
│           ├── p10k.sh          # Powerlevel10k setup functions
│           ├── tmux.sh          # Tmux setup functions
│           ├── watcher.sh       # Set config dotfiles to monitor and update changes **Confirm these**
│           ├── zsh.sh           # Zsh setup functions
│           ├── zxc_nvim.sh      # Neovim configuration content
│           ├── zxc_tmux.sh      # Tmux configuration content
│           ├── zxc_zsh.sh       # Zsh configuration content
│           └── zxc_p10k.sh      # Powerlevel10k configuration content
├── export_repo.py               # Python utility to export repository contents
├── export_repo.sh               # Bash utility to export repository contents
├── LICENSE                      # Public domain license (Unlicense)
└── README.md                    # This documentation file
```
---
## 2. Features

### 🔧 **Core System**
- **Automated WSL Distro Management**: Import/export functionality for environment versioning
- **Systemd Support**: Full systemd integration via distrod for proper service management
- **Real-time Logging**: Comprehensive installation progress with PowerShell integration
- **Mirror Optimization**: Automatic package mirror selection for optimal performance
- **XDG Base Directory Compliant:** Organizes configuration files under `~/.config` for a cleaner home directory.
- **Optimized Pacman:** Configures parallel downloads, colors, and multilib repository.
- **South African Locale**: Pre-configured for `en_ZA.UTF-8` locale settings

### 🛠️ **Development Tools**
- **Multi-Language Support**: Python, Node.js, Go, Rust, Zig with proper toolchain setup
- **Modern Shell**: ZSH with Oh My Zsh, Powerlevel10k theme, and productivity plugins
- **Advanced Editor**: Neovim with LSP, completion, Treesitter, and modern plugin ecosystem
- **Terminal Multiplexer**: Tmux with optimized configuration and key bindings
- **Version Control**: Git with enhanced tools (lazygit, git-delta) and commit hooks

### 📦 **Package Management**
- **Automatic Sync**: Git hooks automatically commit package list changes
- **Custom Package Support**: Additional packages via `installed_packages.txt`
- **Base Dependencies**: Essential development packages pre-configured
- **Database Tools**: PostgreSQL, SQLite clients included

### ⚙️ **Configuration System**
- **Patch-Based Configs**: Non-destructive customization via diff patches
- **Config Watcher**: Systemd service automatically commits configuration changes
- **Pristine Management**: Original configurations preserved alongside user modifications
- **Hot-Reload**: Changes applied without disrupting workflow

### 🔗 **Windows Integration**
- **Clipboard Support**: Seamless copy/paste between WSL and Windows
- **File System Access**: Direct access to Windows drives and files
- **Network Integration**: Services accessible from Windows host
- **GUI Support**: WSLg compatibility for graphical applications

---

## 3. Prerequisites

Before you begin, ensure you have the following set up on your **Windows host**:

*   **Windows 10/11 (version 2004 or higher)** with WSL enabled.
*   **WSL 2 installed and configured.** You can install it by running `wsl --install` in an elevated PowerShell/CMD.
*   **Git for Windows:** Download and install from [https://git-scm.com/download/win](https://git-scm.com/download/win).
*   **PowerShell:** The `Install.ps1` script requires PowerShell.

## 4. Quick Start

### Prerequisites
- Windows 10/11 with WSL 2 support
- PowerShell with Administrator privileges  
- Git installed on Windows
- Internet connection for package downloads

### One-Command Installation
```
powershell
# Open PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
git clone https://github.com/CorneliusWalters/Arch_Dev_Env.git c:\wsl\wsl_dev_setup
cd c:\wsl\wsl_dev_setup\Setup
.\Install.ps1
```
### Installation Phases

The installer progresses through several phases:

1. **Prerequisites Check**: Validates WSL version and dependencies
2. **Distro Import**: Downloads and imports clean Arch Linux image
3. **User Setup**: Creates user account and configures permissions
4. **System Configuration**: Updates packages and sets up system services
5. **Development Tools**: Installs programming languages and development tools
6. **Shell Configuration**: Sets up ZSH, Oh My Zsh, and Powerlevel10k
7. **Editor Setup**: Configures Neovim with plugins and LSP support
8. **Service Configuration**: Enables systemd services and watchers
9. **Export**: Creates backup image of configured environment

The installation will:
1. Prompt for your desired WSL username
2. Download and import a clean Arch Linux WSL image
3. Configure the system with your username
4. Install all development tools and configurations
5. Export the configured environment for future use

**Total Installation Time**: ~15-30 minutes depending on internet speed

---

### 5. Locale Configuration

During the setup, the system-wide locale is automatically configured to `en_ZA.UTF-8` (South African English UTF-8). This ensures consistent date, time, currency, and sorting formats.

If you prefer a different locale, you can change it after the installation is complete by editing `/etc/locale.conf` and `/etc/locale.gen` manually, then regenerating the locales:

1.  Edit `/etc/locale.conf` (as root):
    ```
    sudo nvim /etc/locale.conf
    # Change LANG and other LC_ variables to your preferred locale, e.g., en_US.UTF-8
    ```
2.  Edit `/etc/locale.gen` (as root):
    ```
    sudo nvim /etc/locale.gen
    # Uncomment the line corresponding to your desired locale (e.g., en_US.UTF-8 UTF-8)
    # Comment out en_ZA.UTF-8
    ```
3.  Generate the new locales:
    ```
    sudo locale-gen
    ```
4.  modify below lines in "~/.config/zsh/.zshrc":
    ```
    # Force UTF-8 locale settings for compatibility with nvim and other tools
    export LANG=en_ZA.UTF-8
    export LC_ALL=en_ZA.UTF-8

    ```
5.  Log out and back in, or restart your WSL instance for changes to take effect, and source "~/.config/zsh/.zshrc".



### 6. Post-Installation Steps

1.  **Logout and Log back in:** For all shell and configuration changes (like default Zsh shell, paths, etc.) to take full effect, you should close your current WSL terminal and open a new one.
2.  **Neovim Plugin Installation:**
    Once in the new Arch WSL terminal, open Neovim:
    ```bash
    nvim
    ```
    Neovim will automatically detect and install its plugins (managed by Lazy.nvim). This may take some time depending on your internet connection. After installation, exit Neovim (`:q`) and restart it if prompted for plugin compilation.

## 7. Configuration Management

### Patch-Based System

This setup uses an innovative **patch-based configuration management system** that preserves your customizations while allowing for easy updates and sharing.

#### How It Works

```

~/.config/dotfiles-pristine/    # Original configurations
~/.config/zsh/.zshrc           # Your working configuration
~/.config/zsh/.zshrc.patch     # Your customizations as a patch file
```

#### Making Changes

1. **Edit Configuration Files Normally**:
```
bash
# Edit your shell configuration
zshconf

# Edit Neovim configuration  
nvimconf

# Edit Tmux configuration
tmuxconf
```

2. **Automatic Patch Generation**: The config watcher service detects changes and automatically creates patch files and commits them to Git.

3. **Version Control**: All your customizations are tracked in Git as patch files, making them easy to share and version.

#### Restoring Configurations

If you need to start fresh or reapply patches:

```
bash
# Force overwrite all configurations (during next login)
export FORCE_OVERWRITE=true

# Or manually apply patches
cd $REPO_ROOT
patch ~/.config/zsh/.zshrc < ~/.config/zsh/.zshrc.patch
```

### Configuration Files Managed

- **ZSH**: `~/.config/zsh/.zshrc` - Shell configuration, aliases, functions
- **P10k**: `~/.config/zsh/.p10k.zsh` - Powerlevel10k prompt theme  
- **Tmux**: `~/.config/tmux/tmux.conf` - Terminal multiplexer settings
- **Neovim**: Multiple files in `~/.config/nvim/` - Editor configuration

---

## 8. Customizing Your Environment (Forking & Modifying)

This setup is designed to be easily customizable via forking. By creating your own fork, you can tailor every aspect of the environment to your specific needs and have your changes persist across new installations and updates.

### How to Fork this Repository

1.  **On GitHub:** Go to the main `Arch_Dev_Env` repository page (e.g., `https://github.com/CorneliusWalters/Arch_Dev_Env`).
2.  Click the **"Fork"** button in the top right corner.
3.  Follow the prompts to create a fork under your GitHub account.

### How to Modify and Maintain Your Fork

1.  **Clone Your Fork Locally:**
    In your PowerShell terminal, clone *your* fork instead of the original repository.
    ```powershell
    # Update Install.ps1 to point to your fork's URL ($githubRepoUrl variable).
    # Then, run Install.ps1 as described in the installation guide.
    ```
2.  **Edit Files:**
    Open the cloned repository on your Windows machine (e.g., in VS Code) or directly within your WSL instance.
    You can modify any of the scripts and configuration files to your liking:
    *   **Add/Remove Packages:** Edit the `install_base_packages`, `install_dev_tools`, `install_db_tools`, or `install_python_environment` functions in `Setup/lib/4_install.sh` to change the default software installed.
    *   **Customize Dotfiles:** Modify the `.zshrc`, `.p10k.zsh`, `tmux.conf`, or Neovim Lua files directly within their respective `Setup/lib/config/zxc_*.sh` scripts (or create new ones and update the sourcing). Remember that these scripts use `cat >` to overwrite, so make your changes directly in the source `zxc_*.sh` files.
    *   **Adjust Paths/Variables:** Change any paths or variables within the `.ps1` or `.sh` scripts to match your preferences.
    *   **Extend Functionality:** Add new scripts, functions, or integrations to `Setup/lib/` to expand the setup's capabilities.
3.  **Commit Your Changes:**
    After making modifications, commit them to your fork's repository:
    ```bash
    # In your WSL terminal, navigate to your cloned repo root
    cd /mnt/c/wsl/wsl-dev-setup/ # Or your $localClonePath in WSL format
    git add .
    git commit -m "My custom changes to the dev environment"
    git push
    ```
    Make sure your WSL user has Git credentials set up for pushing to your fork.
4.  **Redeploy/Update Your Environment:**
    To apply your custom changes to an existing WSL instance or a new one:
    *   If you've just made changes and pushed, you can rerun the `Install.ps1` script from PowerShell (`& "C:\wsl\scripts\Install.ps1"`). The script will pull the latest version of your fork and reapply your customized setup.
    *   If you manually update the repository in WSL (`git pull`), running `Setup/1_sys_init.sh` from within WSL (e.g., `bash Setup/1_sys_init.sh`) will also reapply your configurations.

By following this process, your personal Arch Linux WSL environment will always reflect the latest state of your customized fork.

## 9. Troubleshooting

*   **Installation Failure:** Check the main log file for `1_sys_init.sh` at:
    `C:\wsl\tmp\logs\YYYYMMDD_HHMMSS\sys_init.log` (timestamp will vary).
*   **Pacman Hook Failures:** Check the dedicated log for the hook at:
    `C:\wsl\tmp\logs\pacman_git_sync.log`
*   **Git Push Failures in Hook:** Ensure your Git credentials (SSH key, Git Credential Manager) are correctly set up for your WSL user. Try a manual `git push` from your repository root (`/mnt/c/wsl/wsl-dev-setup`) in your WSL terminal to diagnose.
*   **Zsh or Neovim Not Working as Expected:** Verify that the configuration files in `~/.config/zsh` and `~/.config/nvim` exist and contain the expected content. If they were accidentally overwritten, you may need to re-clone the repository and re-run the setup, or manually restore them from your Git history.

## 10. Usage

#### **Starting Your Environment**
```
bash
# Launch WSL (tmux starts automatically)
wsl -d Arch

# Or launch specific session
wsl -d Arch -- tmux new-session -A -s dev
```

#### **Navigation & File Management**
```
bash
# Modern file listing
ls          # Actually runs: lsd -lah
ll          # Long format: lsd -l  
la          # Tree view: lsd --tree ./*

# Finding files and content
find        # Actually runs: fd (faster find alternative)
grep        # Actually runs: rg (ripgrep - faster grep)
```

#### **Development Commands**
```
bash
# Quick editor access
v file.txt  # Opens in Neovim
nvim        # Full Neovim

# Version control
g status    # Git status (g = git alias)
lg          # Opens lazygit TUI

# Python development  
py script.py    # Run Python
ipy            # IPython interactive shell

# System monitoring
top            # Actually runs: btop (better htop)
```

#### **Configuration Management**
```
bash
# Quick config edits
zshconf     # Edit ZSH configuration
tmuxconf    # Edit Tmux configuration  
nvimconf    # Edit Neovim configuration

# System updates
update      # Runs: sudo pacman -Syu
```

### Service Management

#### **Checking Services**
```
bash
# View systemd services
systemctl --user list-units --type=service

# Check config watcher status
systemctl --user status config-watcher
```

#### **Package Management**
```
bash
# Install new packages (automatically synced to Git)
sudo pacman -S package-name

# Check installed packages
pacman -Qqet > /tmp/packages.txt && cat /tmp/packages.txt
```



Once the setup is complete and you've logged back into your WSL Arch terminal:

*   **Zsh:** Your default shell should now be Zsh with Powerlevel10k.
*   **Neovim:**
    *   `nvim`: Launch Neovim.
    *   `<leader>e` (`<space>e`): Toggle NvimTree file explorer.
    *   `gd`: Go to definition (LSP).
    *   `K`: Show hover info (LSP).
    *   `<leader>ff`: Find files (Telescope).
    *   `<leader>fg`: Live grep (Telescope).
    *   `<leader>db`: Toggle Dadbod UI for database interaction.
*   **Tmux:**
    *   `Ctrl-a`: Your new Tmux prefix. 
    *   `Ctrl-a c`: Create new window.
    *   `Ctrl-a |`: Split pane horizontally.
    *   `Ctrl-a -`: Split pane vertically.
    *   `Alt-h/j/k/l`: Navigate panes.
    *   `tmux ls`: List sessions
    *   `tmux new-session -s name`: Create named session
    *   `tmux attach -t name`: Attach to session
    *   `tmux kill-session -t name`: Kill session
*   **Aliases:** A range of useful aliases are defined in `~/.config/zsh/.zshrc`:
    *   `ls`, `ll`, `la`: Enhanced `ls` using `lsd`.
    *   `cat`: Uses `bat` for syntax highlighting.
    *   `top`: Uses `btop` for resource monitoring.
    *   `find`: Uses `fd`.
    *   `grep`: Uses `rg` (ripgrep).
    *   `g`: Alias for `git`.
    *   `lg`: Launch `lazygit`.
    *   `v`: Alias for `nvim`.
    *   `update`: Runs `sudo pacman -Syu`.
    *   `zshconf`, `tmuxconf`, `nvimconf`: Quick edit your shell, tmux, and Neovim configs.
    *   `proj`: cd to ~/project
    *   `wrk`: cd to ~/work
    

## License

This software is released into the public domain under the [Unlicense](LICENSE).