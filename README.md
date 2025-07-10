# Arch_Dev_Env: WSL Arch Linux Development Environment Setup

This repository provides a fully automated and opinionated setup for a powerful Arch Linux development environment running inside Windows Subsystem for Linux (WSL). The goal is a "ready-as-is" configuration, allowing for quick and consistent deployment across multiple machines.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation Guide](#installation-guide)
  - [1. Windows Host Setup](#1-windows-host-setup)
  - [2. Initial WSL Arch Linux Setup](#2-initial-wsl-arch-linux-setup)
  - [3. Configure the Dev Environment](#3-configure-the-dev-environment)
  - [4. Locale Configuration](#4-locale-configuration)
  - [5. Post-Installation Steps](#5-post-installation-steps)
- [Configuration Management (Dotfiles)](#configuration-management-dotfiles)
- [Pacman Package Synchronization Hook](#pacman-package-synchronization-hook)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

*   **Automated Installation:** Bootstrap script handles most of the heavy lifting.
*   **Arch Linux in WSL:** Leverages the power and flexibility of Arch Linux with seamless Windows integration.
*   **XDG Base Directory Compliant:** Organizes configuration files under `~/.config` for a cleaner home directory.
*   **Optimized Pacman:** Configures parallel downloads, colors, and multilib repository.
*   **Essential Development Tools:** Installs a wide array of tools for Git, Python, Node.js, Go, Rust, Zig, databases, and more.
*   **Customized Shell (Zsh + Powerlevel10k):** Sets up Zsh with Oh My Zsh, zsh-autosuggestions, zsh-syntax-highlighting, and Powerlevel10k theme for an enhanced terminal experience.
*   **Neovim Configuration:** Provides a feature-rich Neovim setup with Lazy.nvim for plugin management, LSP, completion, fuzzy finding, database support, API testing, and Treesitter.
*   **Tmux Configuration:** Sets up Tmux for efficient terminal multiplexing with sensible defaults.
*   **Integrated WSL Clipboard:** Configures `win32yank` for seamless clipboard integration between WSL and Windows.
*   **Automated Package List Sync:** A `pacman` hook automatically updates `installed_packages.txt` in the Git repository after package installations/removals, ensuring future setups include your current software.
*   **Robust Logging:** Detailed logs of the installation process for easy troubleshooting.

## Prerequisites

Before you begin, ensure you have the following set up on your **Windows host**:

*   **Windows 10/11 (version 2004 or higher)** with WSL enabled.
*   **WSL 2 installed and configured.** You can install it by running `wsl --install` in an elevated PowerShell/CMD.
*   **Arch Linux WSL distribution installed.** You can install it via the Microsoft Store or manually using `wsl --import`. Ensure you've completed the initial user setup within Arch Linux.
*   **Git for Windows:** Download and install from [https://git-scm.com/download/win](https://git-scm.com/download/win).
*   **PowerShell:** The `Install.ps1` script requires PowerShell.

## Installation Guide

Follow these steps to set up your Arch Linux development environment in WSL.

### 1. Windows Host Setup

1.  **Clone this Repository:**
    Open a **PowerShell** terminal (not WSL Bash) on your Windows machine.
    ```powershell
    $githubRepoUrl = "https://github.com/CorneliusWalters/Arch_Dev_Env.git" # Your repository URL
    $localClonePath = "C:\wsl\wsl-dev-setup"                               # Recommended clone location

    # If the directory exists, it will be removed for a clean clone.
    # WARNING: This will delete any existing contents in $localClonePath!
    if (Test-Path $localClonePath) {
        Write-Host "Setup directory already exists at '$localClonePath'. Removing for a clean clone."
        Remove-Item -Recurse -Force $localClonePath
    }
    git clone $githubRepoUrl $localClonePath
    ```
    *Adjust `$githubRepoUrl` if you are using a fork.*

2.  **Verify WSL Arch Linux Instance:**
    Ensure your Arch Linux WSL distribution is installed and running.
    ```powershell
    wsl -l -v
    # You should see your "Arch" distribution listed. If not, install it:
    # wsl --install -d ArchLinux # (If you have a direct Arch Linux installer)
    # OR follow official Arch WSL installation guides.
    ```

### 3. Configure the Dev Environment

1.  **Execute the Main Setup Script:**
    Return to your **PowerShell** terminal.
    ```powershell
    # --- CONFIGURATION: EDIT THESE VARIABLES ---
    $wslDistroName = "Arch"           # Your WSL distribution name (e.g., "Arch", "Ubuntu")
    $wslUsername = "CHW"              # VERY IMPORTANT: EDIT THIS to your default WSL username
    # -------------------------------------------

    # This will clone the repository and execute the main setup script inside WSL.
    # You will be prompted for your sudo password within the WSL terminal.
    & "$localClonePath\Setup\Install.ps1"
    ```
    This script will:
    *   Clone this repository (if not already done, overwriting existing `$localClonePath` if it exists).
    *   Execute `Setup/1_sys_init.sh` inside your WSL Arch Linux instance as the specified `$wslUsername`.

### 4. Locale Configuration

During the setup, the system-wide locale is automatically configured to `en_ZA.UTF-8` (South African English UTF-8). This ensures consistent date, time, currency, and sorting formats.

If you prefer a different locale, you can change it after the installation is complete by editing `/etc/locale.conf` and `/etc/locale.gen` manually, then regenerating the locales:

1.  Edit `/etc/locale.conf` (as root):
    ```bash
    sudo nvim /etc/locale.conf
    # Change LANG and other LC_ variables to your preferred locale, e.g., en_US.UTF-8
    ```
2.  Edit `/etc/locale.gen` (as root):
    ```bash
    sudo nvim /etc/locale.gen
    # Uncomment the line corresponding to your desired locale (e.g., en_US.UTF-8 UTF-8)
    # Comment out en_ZA.UTF-8
    ```
3.  Generate the new locales:
    ```bash
    sudo locale-gen
    ```
4.  Log out and back in, or restart your WSL instance for changes to take effect.

### 5. Post-Installation Steps

1.  **Logout and Log back in:** For all shell and configuration changes (like default Zsh shell, paths, etc.) to take full effect, you should close your current WSL terminal and open a new one.
2.  **Neovim Plugin Installation:**
    Once in the new Arch WSL terminal, open Neovim:
    ```bash
    nvim
    ```
    Neovim will automatically detect and install its plugins (managed by Lazy.nvim). This may take some time depending on your internet connection. After installation, exit Neovim (`:q`) and restart it if prompted for plugin compilation.

## Configuration Management (Dotfiles)

This setup uses the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html) by placing most configuration files under `~/.config`.

**Important Note on Configuration Overwrites:**
The current setup is designed for a "ready-as-is" experience, which means certain configuration files are *overwritten* during the installation process by the scripts. This ensures a consistent environment matching the repository's intent.

Specifically, the following configuration files are regenerated and **will overwrite any manual changes** if you rerun the `Install.ps1` (or `1_sys_init.sh`) script:

*   `/etc/locale.conf`
*   `~/.config/zsh/.zshenv`
*   `~/.config/zsh/.zshrc`
*   `~/.config/zsh/.p10k.zsh`
*   `~/.config/tmux/tmux.conf`
*   `~/.config/nvim/init.lua`
*   `~/.config/nvim/preferences.lua`
*   `~/.config/nvim/plugins.lua`
*   `~/.config/nvim/keymaps.lua`

If you intend to make permanent, personal customizations to these files, you have two options:

1.  **Fork this repository:** Make your changes directly in your fork and use your fork for future deployments.
2.  **Manual Merging/Management:** Be aware that rerunning the setup will overwrite changes. You would need to manually back up your customizations and re-apply them, or use a separate dotfile management tool like `GNU Stow` to overlay your custom changes.

## Pacman Package Synchronization Hook

To keep track of all explicitly installed Arch Linux packages across your development environments, a `pacman` hook is installed.

*   **What it does:** After every `pacman -S` (install/upgrade) or `pacman -R` (remove) operation, a script runs to capture the list of explicitly installed packages (`pacman -Qqet`).
*   **Git Integration:** If the list of packages has changed, the script automatically `git add`s, `git commit`s, and `git push`es the `installed_packages.txt` file in your repository.
*   **Benefits:**
    *   Your `installed_packages.txt` is always up-to-date.
    *   New installations using this repository will pull in the latest set of your preferred software.
    *   Facilitates disaster recovery or setting up new machines to match your existing environment.
*   **Location:**
    *   The hook script is located at `/usr/local/bin/sync_installed_packages.sh`.
    *   The pacman hook definition is at `/etc/pacman.d/hooks/auto-git-sync.hook`.
    *   Logs for the hook are written to `/mnt/c/wsl/tmp/logs/pacman_git_sync.log`.
*   **Git Credentials:** For the `git push` to succeed, your WSL user needs Git credentials configured (e.g., SSH key added to GitHub, or Git Credential Manager set up).

## Usage

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
    *   `Ctrl-a %`: Split pane horizontally.
    *   `Ctrl-a "`: Split pane vertically.
    *   `Alt-h/j/k/l`: Navigate panes.
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

## Troubleshooting

*   **Installation Failure:** Check the main log file for `1_sys_init.sh` at:
    `C:\wsl\tmp\logs\YYYYMMDD_HHMMSS\sys_init.log` (timestamp will vary).
*   **Pacman Hook Failures:** Check the dedicated log for the hook at:
    `C:\wsl\tmp\logs\pacman_git_sync.log`
*   **Git Push Failures in Hook:** Ensure your Git credentials (SSH key, Git Credential Manager) are correctly set up for your WSL user. Try a manual `git push` from your repository root (`/mnt/c/wsl/wsl-dev-setup`) in your WSL terminal to diagnose.
*   **Zsh or Neovim Not Working as Expected:** Verify that the configuration files in `~/.config/zsh` and `~/.config/nvim` exist and contain the expected content. If they were accidentally overwritten, you may need to re-clone the repository and re-run the setup, or manually restore them from your Git history.

## License

This software is released into the public domain under the [Unlicense](LICENSE).
