# 🚀 Arch Linux WSL Development Environment

**An automated, comprehensive development setup for Arch Linux on Windows Subsystem for Linux with modern tools and intelligent configuration management.**

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Features](#-features)
- [Quick Start](#-quick-start)
- [Installation Guide](#-installation-guide)
- [Configuration Management](#-configuration-management)
- [Development Tools](#-development-tools)
- [Usage Guide](#-usage-guide)
- [Troubleshooting](#-troubleshooting)
- [Customization](#-customization)
- [Contributing](#-contributing-and-forking)
- [Locale Configuration](#-locale-configuration)

---

## 🎯 Overview

This project provides a **fully automated setup system** for creating a professional Arch Linux development environment within WSL (Windows Subsystem for Linux). It transforms a fresh Arch Linux WSL installation into a complete development workstation with modern tools, intelligent configuration management, and seamless Windows integration.

### Why This Setup?

- **Time-Saving**: Complete environment setup in minutes, not hours
- **Professional Grade**: Enterprise-ready development tools and configurations
- **Intelligent Sync**: Automated Git synchronization of packages and configurations
- **Patch-Based Management**: Non-destructive configuration customization system
- **Modern Stack**: Latest development tools with sensible defaults
- **WSL Optimized**: Full systemd support with Windows integration

---

## ✨ Features

### 🔧 **Core System**
- **Automated WSL Distro Management**: Import/export functionality for environment versioning
- **Systemd Support**: Full systemd integration via distrod for proper service management
- **Real-time Logging**: Comprehensive installation progress with PowerShell integration
- **Mirror Optimization**: Automatic package mirror selection for optimal performance
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

## ⚡ Quick Start

### Prerequisites
- Windows 10/11 with WSL 2 support
- PowerShell with Administrator privileges  
- Git installed on Windows
- Internet connection for package downloads

### One-Command Installation
'''
powershell
# Open PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
git clone https://github.com/CorneliusWalters/Arch_Dev_Env.git c:\wsl\wsl_dev_setup
cd c:\wsl\wsl_dev_setup\Setup
.\Install.ps1
'''

The installation will:
1. Prompt for your desired WSL username
2. Download and import a clean Arch Linux WSL image
3. Configure the system with your username
4. Install all development tools and configurations
5. Export the configured environment for future use

**Total Installation Time**: ~15-30 minutes depending on internet speed

---

## 📚 Installation Guide

### Detailed Installation Steps

#### 1. **System Preparation**
'''
powershell
# Ensure WSL 2 is installed
wsl --install --no-distribution

# Verify WSL version
wsl --version


#### 2. **Repository Setup**
'''
powershell
# Clone the repository
git clone https://github.com/CorneliusWalters/Arch_Dev_Env.git c:\wsl\wsl_dev_setup
cd c:\wsl\wsl_dev_setup\Setup
'''

#### 3. **Run Installation**
'''
powershell
# Execute the main installer
.\Install.ps1
'''

#### 4. **Post-Installation**
'''
bash
# First login - verify installation
wsl -d Arch

# Update system packages
sudo pacman -Syu

# Start Neovim to install plugins
nvim
# Wait for plugins to install, then exit with :q
'''

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

---

## 🔧 Configuration Management

### Patch-Based System

This setup uses an innovative **patch-based configuration management system** that preserves your customizations while allowing for easy updates and sharing.

#### How It Works

'''

~/.config/dotfiles-pristine/    # Original configurations
~/.config/zsh/.zshrc           # Your working configuration
~/.config/zsh/.zshrc.patch     # Your customizations as a patch file
'''

#### Making Changes

1. **Edit Configuration Files Normally**:
'''
bash
# Edit your shell configuration
zshconf

# Edit Neovim configuration  
nvimconf

# Edit Tmux configuration
tmuxconf
'''

2. **Automatic Patch Generation**: The config watcher service detects changes and automatically creates patch files and commits them to Git.

3. **Version Control**: All your customizations are tracked in Git as patch files, making them easy to share and version.

#### Restoring Configurations

If you need to start fresh or reapply patches:

'''
bash
# Force overwrite all configurations (during next login)
export FORCE_OVERWRITE=true

# Or manually apply patches
cd $REPO_ROOT
patch ~/.config/zsh/.zshrc < ~/.config/zsh/.zshrc.patch
'''

### Configuration Files Managed

- **ZSH**: `~/.config/zsh/.zshrc` - Shell configuration, aliases, functions
- **P10k**: `~/.config/zsh/.p10k.zsh` - Powerlevel10k prompt theme  
- **Tmux**: `~/.config/tmux/tmux.conf` - Terminal multiplexer settings
- **Neovim**: Multiple files in `~/.config/nvim/` - Editor configuration

---

## 🛠️ Development Tools

### Programming Languages & Runtimes

| Language | Version Manager | Tools Included |
|----------|----------------|----------------|
| **Python** | System pacman | pip, pipx, poetry, pynvim, debugpy |
| **Node.js** | System pacman | npm, development packages |
| **Go** | System pacman | Latest stable version |
| **Rust** | System pacman | rustc, cargo, rust-analyzer |
| **Zig** | System pacman | zig compiler, zls language server |

### Development Environment

#### **Shell Environment (ZSH)**
'''
bash
# Modern shell with powerful features
- Oh My Zsh framework
- Powerlevel10k theme (Kanagawa-inspired colors)
- Auto-suggestions and syntax highlighting
- Extensive aliases and functions
- Automatic tmux session management
'''

#### **Editor (Neovim)**
'''
lua
-- Modern modal editor with IDE features
- LSP support for multiple languages
- Treesitter syntax highlighting  
- Fuzzy finding with Telescope
- File explorer with nvim-tree
- Database management with vim-dadbod
- Git integration with gitsigns
- Auto-completion and snippets
'''

#### **Terminal Multiplexer (Tmux)**
'''
bash
# Enhanced terminal session management
- Custom key bindings (Ctrl+a prefix)
- Mouse support enabled
- Modern color scheme
- Intuitive pane splitting
- Status bar customization
'''

### Database Tools
- **PostgreSQL**: Client libraries and tools
- **SQLite**: Command-line interface and libraries
- **GUI Tools**: Database management via Neovim plugins

### Version Control
- **Git**: Core version control
- **lazygit**: Terminal UI for Git operations
- **git-delta**: Enhanced diff viewer  
- **GitHub CLI**: Command-line GitHub integration

---

##  Usage Guide

### Daily Workflow

#### **Starting Your Environment**
'''
bash
# Launch WSL (tmux starts automatically)
wsl -d Arch

# Or launch specific session
wsl -d Arch -- tmux new-session -A -s dev
'''

#### **Navigation & File Management**
'''
bash
# Modern file listing
ls          # Actually runs: lsd -lah
ll          # Long format: lsd -l  
la          # Tree view: lsd --tree ./*

# Finding files and content
find        # Actually runs: fd (faster find alternative)
grep        # Actually runs: rg (ripgrep - faster grep)
'''

#### **Development Commands**
'''
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
'''

#### **Configuration Management**
'''
bash
# Quick config edits
zshconf     # Edit ZSH configuration
tmuxconf    # Edit Tmux configuration  
nvimconf    # Edit Neovim configuration

# System updates
update      # Runs: sudo pacman -Syu
'''

### Service Management

#### **Checking Services**
'''
bash
# View systemd services
systemctl --user list-units --type=service

# Check config watcher status
systemctl --user status config-watcher
'''

#### **Package Management**
'''
bash
# Install new packages (automatically synced to Git)
sudo pacman -S package-name

# Check installed packages
pacman -Qqet > /tmp/packages.txt && cat /tmp/packages.txt
'''

### Tmux Session Management

#### **Key Bindings (Prefix: Ctrl+a)**
'''
bash
Ctrl+a |    # Split pane horizontally
Ctrl+a -    # Split pane vertically
Ctrl+a h/j/k/l  # Navigate panes (vim-style)
Alt+Arrow   # Navigate panes (arrow keys)
Ctrl+a d    # Detach session
Ctrl+a ?    # Show help
'''

#### **Session Commands**
'''
bash
tmux ls                    # List sessions
tmux new-session -s name   # Create named session
tmux attach -t name        # Attach to session
tmux kill-session -t name  # Kill session
'''

---

## 🚨 Troubleshooting

### Common Issues & Solutions

#### **Installation Issues**

**Problem**: WSL installation fails with "Virtual Machine Platform not enabled"
'''
powershell
# Solution: Enable required Windows features
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
# Restart computer after enabling
'''

**Problem**: Package downloads are slow
'''
bash
# Solution: Update mirror list
sudo reflector --country ZA --protocol https --latest 50 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syy
'''

**Problem**: Git authentication issues
'''
bash
# Solution: Configure Git credentials
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Use Windows Credential Manager (if available)
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/libexec/git-core/git-credential-wincred.exe"
'''

#### **Runtime Issues**

**Problem**: Systemd services not starting
'''
bash
# Check if systemd is running
ps aux | grep systemd

# If not running, check distrod status
sudo /opt/distrod/bin/distrod status

# Re-enable systemd
sudo /opt/distrod/bin/distrod enable
'''

**Problem**: Config watcher service not working
'''
bash
# Check service status
systemctl --user status config-watcher

# Check logs
journalctl --user -u config-watcher -f

# Restart service
systemctl --user restart config-watcher
'''

**Problem**: Neovim plugins not loading
'''
bash
# Ensure plugins are installed
nvim
:PackerSync

# Check for errors
:checkhealth

# Reset plugin state
rm -rf ~/.local/share/nvim
nvim # Plugins will reinstall
'''

#### **Performance Issues**

**Problem**: Slow file operations
'''
bash
# Check if running WSL 2
wsl -l -v

# Convert to WSL 2 if needed (from PowerShell)
wsl --set-version Arch 2
'''

**Problem**: High memory usage
'''
powershell
# Configure WSL memory limits in ~/.wslconfig
[wsl2]
memory=8GB
processors=4
swap=2GB
'''

### Log Files & Debugging

#### **Installation Logs**
'''

Windows: C:\wsl\tmp\logs\[timestamp]\
WSL: ~/.local/logs/[timestamp]/sys_init.log
'''

#### **Service Logs**
'''
bash
# Config watcher
journalctl --user -u config-watcher

# Systemd status
systemctl status

# Package sync logs
tail -f /mnt/c/wsl/tmp/logs/pacman_git_sync.log
'''

#### **Debug Mode**
'''
bash
# Enable debug logging
export DEBUG=1

# Increase verbosity for specific commands
pacman -Syyu --verbose
'''

---

## 🎨 Customization

### Adding Custom Packages

#### **Method 1: Direct Installation (Recommended)**
'''
bash
# Install packages - they're automatically synced to Git
sudo pacman -S package-name another-package

# The pacman hook will automatically:
# 1. Update installed_packages.txt
# 2. Commit changes to Git
# 3. Push to repository
'''

#### **Method 2: Pre-Installation List**
'''
bash
# Edit the custom package list before installation
# File: /path/to/repo/installed_packages.txt
echo "package-name" >> installed_packages.txt
echo "another-package" >> installed_packages.txt

# Packages will be installed during next setup
'''

### Shell Customization

#### **Adding Custom Aliases**
Edit `~/.config/zsh/.zshrc` and add your aliases:
'''
bash
# Custom aliases
alias ll='lsd -la'
alias grep='rg --color=always'
alias find='fd'

# Development shortcuts
alias dc='docker-compose'
alias k='kubectl'
alias tf='terraform'

# Project shortcuts
alias proj='cd ~/projects'
alias work='cd ~/work'
'''

#### **Custom Functions**
'''
bash
# Add to ~/.config/zsh/.zshrc
mkcd() {
    mkdir -p "$1" && cd "$1"
}

gitignore() {
    curl -sL "https://www.gitignore.io/api/$1"
}

weather() {
    curl -s "wttr.in/$1"
}
'''

### Theme Customization

#### **Powerlevel10k Theme**
'''
bash
# Reconfigure theme
p10k configure

# Edit theme manually
nvim ~/.config/zsh/.p10k.zsh
'''

#### **Neovim Colorscheme**
Edit `~/.config/nvim/init.lua`:
'''
lua
-- Available colorschemes:
-- kanagawa (default), tokyonight, gruvbox, catppuccin
vim.cmd([[colorscheme kanagawa]])
'''

### Adding New Configuration Files

#### **Extending the Patch System**
1. **Add to Watcher Service**:
'''
bash
# Edit ~/repo/Setup/lib/config/watcher.sh
FILES_TO_WATCH=(
    ".config/zsh/.zshrc"
    ".config/tmux/tmux.conf"
    ".config/nvim/init.lua"
    ".config/git/config"          # Add new file
    ".config/alacritty.yml"       # Add another
)
'''

2. **Create Configuration Script**:
'''
bash
# Create ~/repo/Setup/lib/config/git.sh
setup_git() {
    if [[ ! -f ~/.config/git/config ]] || [[ "$FORCE_OVERWRITE" == "true" ]]; then
        print_status "GIT" "Setting up Git configuration..."
        source "$SCRIPT_DIR/lib/config/zxc_git.sh"
        print_success "GIT" "Git configuration complete."
    fi
}
'''

3. **Create Worker Script**:
'''
bash
# Create ~/repo/Setup/lib/config/zxc_git.sh with pristine config generation
'''

### Environment Variables

#### **Custom Environment Setup**
Add to `~/.config/zsh/.zshrc`:
'''
bash
# Development paths
export GOPATH="$HOME/go"
export CARGO_HOME="$HOME/.cargo"
export RUSTUP_HOME="$HOME/.rustup"

# Editor preferences  
export EDITOR="nvim"
export VISUAL="nvim"

# Custom tool paths
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
'''

---

## 🤝 Contributing and Forking

### Forking the Repository

#### **1. Fork on GitHub**
'''
bash
# Fork the repository on GitHub UI
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/Arch_Dev_Env.git
cd Arch_Dev_Env
'''

#### **2. Update Repository References**
'''
bash
# Update Install.ps1 to point to your fork
# Edit Install.ps1, line ~45:
$gitCloneTarget = "C:\wsl\wsl_dev_setup"
$result = git clone "https://github.com/YOUR_USERNAME/Arch_Dev_Env.git" $gitCloneTarget
'''

#### **3. Customize for Your Needs**
- Edit `installed_packages.txt` with your preferred packages
- Modify configuration files in `Setup/lib/config/zxc_*.sh`
- Update locale settings in `Setup/lib/4_install.sh` if needed
- Add custom setup scripts in `Setup/lib/config/`

### Contributing Back

#### **1. Development Setup**
'''
bash
# Clone the original repository
git clone https://github.com/CorneliusWalters/Arch_Dev_Env.git
cd Arch_Dev_Env

# Create feature branch
git checkout -b feature/your-improvement

# Make changes
# Test thoroughly

# Commit changes
git add .
git commit -m "Add: Description of improvement"
git push origin feature/your-improvement
'''

#### **2. Pull Request Guidelines**

**Before Submitting:**
- [ ] Test installation from scratch in clean WSL environment
- [ ] Verify all services start correctly
- [ ] Check that configuration patching works
- [ ] Update documentation if needed
- [ ] Test with different package combinations

**PR Template:**
'''
markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Configuration improvement

## Testing
- [ ] Fresh installation tested
- [ ] Service functionality verified
- [ ] Configuration patching works
- [ ] No breaking changes

## Checklist
- [ ] Code follows project conventions
- [ ] Documentation updated
- [ ] Testing completed successfully
'''

### Repository Structure

'''

Arch_Dev_Env/
├── Setup/
│   ├── Install.ps1              # Main PowerShell installer
│   ├── 1_sys_init.sh           # Main bash installation script
│   ├── PowerShell/             # PowerShell helper modules
│   │   ├── Logging.ps1         # Advanced logging system
│   │   ├── Utils.ps1           # WSL interaction utilities
│   │   └── ...
│   └── lib/                    # Bash library modules
│       ├── 2_logging.sh        # Bash logging functions
│       ├── 3_set_dirs.sh       # Directory structure setup
│       ├── 4_install.sh        # Package installation logic
│       ├── 5_sync_packs.sh     # Package synchronization hook
│       ├── 6_commit_config.sh  # Configuration commit script
│       ├── 99_wrapper.sh       # PowerShell execution wrapper
│       └── config/             # Configuration management
│           ├── nvim.sh         # Neovim setup coordinator
│           ├── tmux.sh         # Tmux setup coordinator
│           ├── zsh.sh          # ZSH setup coordinator
│           ├── p10k.sh         # P10k setup coordinator
│           ├── watcher.sh      # Configuration watcher service
│           ├── zxc_nvim.sh     # Neovim config generator
│           ├── zxc_tmux.sh     # Tmux config generator
│           ├── zxc_zsh.sh      # ZSH config generator
│           └── zxc_p10k.sh     # P10k config generator
├── installed_packages.txt      # Custom package list
├── export_repo.py             # Repository export utility
└── README.md                  # This file
'''

---

## 🌍 Locale Configuration

### Default Locale Setup

The system is pre-configured for **South African English (en_ZA.UTF-8)**:

'''
bash
# System-wide locale settings
LANG=en_ZA.UTF-8
LC_ALL=en_ZA.UTF-8
# All LC_* categories set to en_ZA.UTF-8
'''

### Changing to Different Locale

#### **Method 1: Edit Installation Script (Before Installation)**
Edit `Setup/lib/4_install.sh`, function `setup_locale()`:

'''
bash
# Change this line (around line 230):
execute_and_log "sudo sed -i 's/#en_ZA.UTF-8/en_ZA.UTF-8/' /etc/locale.gen" \

# To your preferred locale:
execute_and_log "sudo sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen" \

# Also update the locale.conf generation:
"Setting system-wide locale configuration" \
        "LOCALE" || return 1
'''

#### **Method 2: Change After Installation**
'''
bash
# Edit locale generation
sudo nvim /etc/locale.gen
# Uncomment your desired locale, e.g.:
# en_US.UTF-8 UTF-8

# Regenerate locales
sudo locale-gen

# Update system locale
sudo nvim /etc/locale.conf
# Change to:
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
# ... (all other LC_* variables)

# Update shell environment
echo 'export LANG=en_US.UTF-8' >> ~/.config/zsh/.zshrc
echo 'export LC_ALL=en_US.UTF-8' >> ~/.config/zsh/.zshrc

# Restart WSL for changes to take effect
exit
# From PowerShell: wsl --terminate Arch
'''

### Supported Locales

Popular locale options you might want to use:

| Locale | Description |
|--------|-------------|
| `en_US.UTF-8` | US English (most common) |
| `en_GB.UTF-8` | British English |
| `en_ZA.UTF-8` | South African English (default) |
| `en_AU.UTF-8` | Australian English |
| `en_CA.UTF-8` | Canadian English |
| `de_DE.UTF-8` | German |
| `fr_FR.UTF-8` | French |
| `es_ES.UTF-8` | Spanish |

### Timezone Configuration

'''
bash
# List available timezones
timedatectl list-timezones | grep -E "(Africa|Europe|America)/"

# Set timezone
sudo timedatectl set-timezone Africa/Johannesburg

# Or for other regions:
sudo timedatectl set-timezone America/New_York
sudo timedatectl set-timezone Europe/London
sudo timedatectl set-timezone Asia/Tokyo
'''

---

## 🏆 Benefits

### **For Individual Developers**
- **Rapid Environment Setup**: From zero to fully configured development environment in under 30 minutes
- **Consistency**: Identical setup across multiple machines
- **Version Control**: All customizations tracked and portable
- **Modern Toolchain**: Latest development tools with sensible defaults
- **Low Maintenance**: Automated updates and synchronization

### **For Teams**
- **Standardized Environment**: Everyone works with the same tool stack
- **Easy Onboarding**: New team members productive immediately  
- **Shared Configurations**: Team-specific settings distributed via Git
- **Collaboration Ready**: Built-in tools for code review and collaboration
- **Documentation**: Self-documenting through configuration files

### **For Organizations**
- **Compliance**: Controlled software stack with audit trail
- **Security**: Isolated development environment  
- **Cost Effective**: No need for dedicated Linux machines
- **Scalable**: Easy deployment across development teams
- **Windows Integration**: Leverages existing Windows infrastructure

### **Technical Advantages**
- **Modern Architecture**: SystemD support for proper service management
- **Intelligent Patching**: Non-destructive configuration management
- **Real-time Sync**: Live configuration backup and restoration
- **Performance Optimized**: WSL 2 with optimized package mirrors
- **Extensible**: Plugin architecture for easy customization

---

## 📞 Support & Community

### Getting Help

**Documentation**: Check this README first - it covers most common scenarios

**Issues**: [GitHub Issues](https://github.com/CorneliusWalters/Arch_Dev_Env/issues)
- Bug reports
- Feature requests  
- Installation problems

**Discussions**: [GitHub Discussions](https://github.com/CorneliusWalters/Arch_Dev_Env/discussions)
- General questions
- Configuration help
- Show your customizations

### Feedback Welcome

This project benefits from user feedback and contributions:

- **Success Stories**: Share your experience and use cases
- **Pain Points**: What could be improved?
- **Feature Ideas**: What would make this more useful?
- **Documentation**: Help improve setup instructions

---


## 📜 License

This project is released into the **public domain** under [The Unlicense](LICENSE).

**You are free to:**
- Use for any purpose (personal, commercial, educational)
- Modify and distribute
- Create derivative works
- Use in proprietary software

**No attribution required**, but appreciated! 🙏

---

## 🚀 Getting Started

Ready to transform your Windows development experience? 

'''
powershell
git clone https://github.com/CorneliusWalters/Arch_Dev_Env.git c:\wsl\wsl_dev_setup
cd c:\wsl\wsl_dev_setup\Setup  
.\Install.ps1
'''
