#!/bin/bash
###     file name: 0_prepare_root.sh
###     dir: /mnt/c/wsl/wsl_dev_setup/lib/.

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
pacman -Syu --noconfirm sudo git inetutils curl

echo "--> Installing essential packages: sudo..."
pacman -S --noconfirm sudo git inetutils curl

echo "--> Creating sudoers directory..."
mkdir -p /etc/sudoers.d

echo "--> Creating user '${USERNAME}' with home directory..."
useradd -m -G wheel -s /bin/bash "${USERNAME}"

echo "--> Unlocking user account..."
passwd -d "${USERNAME}"

echo "--> Granting passwordless sudo to 'wheel' group..."
echo echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >"/etc/sudoers.d/10-$USERNAME-temp-setup"

echo "--- Root Preparation Complete ---"
