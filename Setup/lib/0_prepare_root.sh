#!/bin/bash
# 0_prepare_root.sh - Run as root to prepare the pristine system.

set -e # Exit on any error

# The username is passed as the first argument from the PowerShell script
USERNAME="$1"

if [ -z "$USERNAME" ]; then
    echo "FATAL: No username provided to the preparation script." >&2
    exit 1
fi

echo "--- Starting Root Preparation for user: ${USERNAME} ---"

echo "--> Initializing pacman keyring..."
pacman-key --init
pacman-key --populate archlinux

echo "--> Updating package databases..."
pacman -Sy 

echo "--> Installing essential packages: sudo..."
pacman -S --noconfirm sudo git inetutils curl

echo "--> Configuring WSL mount options for executable permissions..."


cat > /etc/wsl.conf << EOL
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = false

[user]
default = ${USERNAME}
EOL

echo "--> Creating sudoers directory..."
mkdir -p /etc/sudoers.d

echo "--> Creating user '${USERNAME}' with home directory..."
useradd -m -G wheel -s /bin/bash "${USERNAME}"

echo "--> Unlocking user account..."
passwd -d "${USERNAME}"

echo "--> Granting passwordless sudo to 'wheel' group..."
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel

echo "--- Root Preparation Complete ---"