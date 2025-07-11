# Arch_Dev_Env: WSL Arch Linux Development Environment Setup

This repository provides a fully automated and opinionated setup for a powerful Arch Linux development environment running inside Windows Subsystem for Linux (WSL). The goal is a "ready-as-is" configuration, allowing for quick and consistent deployment across multiple machines.

## Table of Contents

- [Structure](#Structure)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Managing WSL Images (Import/Export)](#managing-wsl-images-importexport)
- [Installation Guide](#installation-guide)
  - [1. Windows Host Setup](#1-windows-host-setup)
  - [2. Initial WSL Arch Linux Setup (for `pacman` hook)](#2-initial-wsl-arch-linux-setup-for-pacman-hook)
  - [3. Configure and Run the Setup Script](#3-configure-and-run-the-setup-script)
  - [4. Locale Configuration](#4-locale-configuration)
  - [5. Post-Installation Steps](#5-post-installation-steps)
- [Configuration Management (Dotfiles)](#configuration-management-dotfiles)
- [Customizing Your Environment (Forking & Modifying)](#customizing-your-environment-forking--modifying)
- [Pacman Package Synchronization Hook](#pacman-package-synchronization-hook)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Structure

#Arch_Dev_Env/
#├── Setup/                       # Main setup directory
#│   ├── 1_sys_init.sh            # Main Bash setup script
#│   ├── Install.ps1              # Main PowerShell installation script
#│   ├── PowerShell/              # Modular PowerShell components
#│   │   ├── Export-Image.ps1     # Exports WSL distro image after install
#│   │   ├── Import-Distro.ps1    # Imports and configures WSL distro
#│   │   ├── Logging.ps1          # PowerShell logging functionality
#│   │   └── Test.ps1             # WSL version and prerequisite tests
#│   └── lib/                     # Bash library functions
#│       ├── 2_set_dirs.sh        # Directory creation and permissions
#│       ├── 3_logging.sh         # Bash logging functions
#│       ├── 4_install.sh         # Package installation functions
#│       ├── 5_sync_packs.sh      # Package list synchronization
#│       ├── snapshots.sh         # WSL snapshot functions (currently disabled)
#│       └── config/              # Configuration templates
#│           ├── nvim.sh          # Neovim setup functions
#│           ├── tmux.sh          # Tmux setup functions
#│           ├── zsh.sh           # Zsh setup functions
#│           ├── p10k.sh          # Powerlevel10k setup functions
#│           ├── zxc_nvim.sh      # Neovim configuration content
#│           ├── zxc_tmux.sh      # Tmux configuration content
#│           ├── zxc_zsh.sh       # Zsh configuration content
#│           └── zxc_p10k.sh      # Powerlevel10k configuration content

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
*   **Git for Windows:** Download and install from [https://git-scm.com/download/win](https://git-scm.com/download/win).
*   **PowerShell:** The `Install.ps1` script requires PowerShell.

## Managing WSL Images (Import/Export)

This setup leverages WSL's import/export functionality to provide consistent starting points and allow for quick recovery or redeployment.

*   **`arch_clean.tar` (Initial Base Image):**
    This is a `.tar` archive of a **fresh, clean Arch Linux WSL distribution**, typically just after its initial installation and user setup.
    *   **Purpose:** The `Install.ps1` script can use this tarball to import a new Arch WSL instance if one isn't already present. This ensures a consistent, known-good starting point.
    *   **How to Obtain:**
        *   **Recommended:** Download a pre-built Arch Linux WSL tarball from a reliable source (e.g., the "ArchWSL" project releases on GitHub, or similar community projects).
        *   **Manually Create:** If you manually installed a pristine Arch WSL instance (e.g., by downloading a rootfs tarball and using `wsl --import` yourself, or if `wsl --install -d Arch` worked for your specific environment) and want to use it as your `arch_clean.tar` for future deployments:
            1.  Ensure no other Arch instances are running: `wsl --terminate Arch`
            2.  Export it: `wsl --export Arch C:\wsl\tmp\arch_clean.tar`
            3.  (Optional) Unregister the original: `wsl --unregister Arch`
    *   **Placement:** Place your `arch_clean.tar` file in `C:\wsl\tmp\` as this is the default path `Install.ps1` will look for.

*   **`arch_configured.tar` (Configured Golden Image):**
    After a successful run of `Install.ps1` and `1_sys_init.sh`, the script offers to export the *fully configured* WSL Arch instance into a `arch_configured.tar` file.
    *   **Purpose:** This acts as a "golden image" or a snapshot of your complete, working development environment. You can use this tarball to quickly import a fully set-up instance onto another machine, or to revert to a known good state if future configurations break.
    *   **How to Use:**
        1.  Save `arch_configured.tar` in a safe place.
        2.  To import it:
            ```powershell
            # First, terminate and unregister the existing Arch instance if it's there
            wsl --terminate Arch
            wsl --unregister Arch
            # Then, import from your configured tarball
            wsl --import Arch C:\WSL\Arch C:\wsl\tmp\arch_configured.tar
            # Set default user for the newly imported distro
            wsl -d Arch config --default-user YourUsername
            ```

## Installation Guide

Follow these steps to set up your Arch Linux development environment in WSL.

### 1. Windows Host Setup

1.  **Download and Configure the Setup Script:**
    Download the `Install.ps1` script from your repository (e.g., from the GitHub raw file link or a release asset). Save it to a convenient location, for example, `C:\wsl\scripts\Install.ps1`.

    Open `C:\wsl\scripts\Install.ps1` (or wherever you saved it) in a text editor (like Notepad, VS Code, or Notepad++). **Carefully review and edit the following variables** at the top of the script:

    ```powershell
    # --- CONFIGURATION: EDIT THESE VARIABLES ---
    $githubRepoUrl = "https://github.com/CorneliusWalters/Arch_Dev_Env.git" # Your repository URL (e.g., your fork)
    $localClonePath = "C:\wsl\wsl-dev-setup"                               # <-- Recommended: Change clone location if desired
    $wslDistroName = "Arch"                                            # <-- Your WSL distribution name (e.g., "Arch")
    $wslUsername = "CHW"                                               # <-- VERY IMPORTANT: EDIT THIS to your default WSL username
    $cleanArchTarballDefaultPath = "C:\wsl\tmp\arch_clean.tar"         # Default for importing a clean distro
    $configuredArchTarballExportPath = "C:\wsl\tmp\arch_configured.tar" # Default for exporting configured distro
    # -------------------------------------------
    ```
    Ensure `$wslUsername` matches the user you want to set up inside Arch Linux.

2.  **Prepare your `arch_clean.tar` (if needed):**
    If you do not currently have a WSL distribution named "Arch", the `Install.ps1` script will attempt to import one from the path specified in `$cleanArchTarballDefaultPath`. Make sure you have this `arch_clean.tar` file present. Refer to the [Managing WSL Images (Import/Export)](#managing-wsl-images-importexport) section for details on how to obtain or create it.

### 2. Initial WSL Arch Linux Setup (for `pacman` hook)

The `pacman` hook will automatically track your installed packages. For this to work correctly, you need to create an initial baseline `installed_packages.txt` file in your repository. This step is for the first time you set up or if `installed_packages.txt` is missing from your repository.

1.  **Open your Arch Linux WSL terminal.**
    *   If you just imported the Arch distro via `Install.ps1`, you might need to close and reopen your PowerShell terminal once for WSL to fully register the new distro. Then open a fresh Arch WSL terminal.
2.  **Navigate to the intended clone path for your repository:**
    ```bash
    # This path should match your $localClonePath from Install.ps1, but in WSL format.
    # Example:
    cd /mnt/c/wsl/wsl-dev-setup/
    ```
3.  **Generate and commit the initial package list:**
    ```bash
    pacman -Qqet > installed_packages.txt
    git add installed_packages.txt
    git commit -m "Initial baseline of installed packages"
    git push
    ```
    **Important:** You must have Git credentials (e.g., SSH key configured for GitHub or Git Credential Manager) set up for your WSL user to push successfully. The `pacman` hook will use these credentials automatically in the future.

### 3. Configure and Run the Setup Script

1.  **Execute `Install.ps1`:**
    Return to your **PowerShell** terminal and run the `Install.ps1` script.
    ```powershell
    & "C:\wsl\scripts\Install.ps1" # Adjust path if you saved it elsewhere
    ```
    This script will now:
    *   Check for and optionally import/configure the Arch WSL distro.
    *   Clone this repository to the `$localClonePath` you configured (overwriting existing contents if the directory exists).
    *   Execute `Setup/1_sys_init.sh` from the newly cloned repository inside your WSL Arch Linux instance as the specified `$wslUsername`.
    *   You will be prompted for your `sudo` password within the WSL terminal during this process.
    *   **Upon successful completion, it will prompt you if you want to export a `arch_configured.tar` snapshot.**

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

## Customizing Your Environment (Forking & Modifying)

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