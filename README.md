# Arch_Dev_Env
Arch Development Environment

#Exeute following in WSL terminal 

cd /mnt/c/wsl/wsl-dev-setup/ # or wherever your repo is cloned
pacman -Qqet > installed_packages.txt
git add installed_packages.txt
git commit -m "Initial baseline of installed packages"
git push