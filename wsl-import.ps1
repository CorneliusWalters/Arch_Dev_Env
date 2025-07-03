#!/bin/bash
###     file: wsl-import.ps1
###     dir: c:\wsl\scripts\wsl-import.ps1


$distroName = "Arch"
$installDir = "C:\WSL\$distroName"
$tarPath = "C:\wsl\tmp\arch_clean.tar"
$scriptDir = "C:\WSL\scripts"

# Import WSL distribution
wsl --terminate $distroName
wsl --unregister $distroName
wsl --import $distroName $installDir $tarPath

# Copy setup scripts to Windows directory
robocopy "$PSScriptRoot\scripts" $scriptDir /MIR /NP /NFL /NDL

# Configure first launch
wsl -d $distroName -u root bash -c "echo 'source /mnt/c/WSL/scripts/sys_init.sh' >> /etc/bash.bashrc"
wsl -d $distroName -u root bash -c "echo 'source /mnt/c/WSL/scripts/sys_init.sh' >> /etc/zsh/zshenv"

# Launch the instance
wsl -d $distroName