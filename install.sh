#!/bin/bash
# ----- SETTINGS ----- #
# initial user, will have root permisions
user_name="assuero" 
user_password="" # if empty, this will be the same as root password

# the disk where gentoo will be installed
disk="vda" # run lsblk in the live install to check for your disk

# Link of the stage file that will be used in the installation
# you can find it here: https://www.gentoo.org/downloads/mirrors/
stage_file_link=""

host_name="Gentoo"

# how much ram do you want for the swap partition
swap_gb=

# the locale that you want to use in the system
default_locale="en_US.UTF-8"

# set this to false if you want to compile the pached kernel install of downloading the binary
bin_dkernel=true

# set this to false if you don't want a copy of the log file in your home directory 
copy_log_to_home_dir=true

# remove this line after every variable is set up to your installation
config_done="delete me"

# ----- INSTALL SETUP ----- #
# $config_done check
if [[ -n $config_done ]]; then
	echo 'ERROR: Installation configuration variables not fully reviewed. Edit the variables under SETTINGS acording to your machine and remove the config_done variable to proceed.'
	exit 1
fi

# password check
read -p "Root password(The password is visible): " root_password
if [[ -z $root_password || $root_password = "" ]]; then
	echo "ERROR: Root password is empty."
	exit 1
fi
if [[ "$user_password" = "" ]]; then
	user_password="$root_password"
fi

### common variables / functions
# dir where the script is running
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# file where the install log goes to
log_file="lazy-log.txt"
function log_echo () {
	echo "Lazy Gentoo Install - ($(date '+%d/%m/%Y; %H:%M:%S')) $1"
	echo "($(date '+%d/%m/%Y; %H:%M:%S')) $1" >> "$log_file"
}

# ----- NETWORK ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Networking
# TODO

log_echo "Starting installation"
# ----- DISK PARTITIONING ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Disks
# "$disk"1: EFI
# "$disk"2: swap (half of $ram_gb)
# "$disk"1: / (ext4)

log_echo "Partiioning the disk"
# set disk system to gpt
printf "g
w
" | sudo fdisk "/dev/$disk"
### EFI PARTITION
# make partition
printf "n
1

+1G
y
w
" | sudo fdisk "/dev/$disk"
# format partition
printf "t
1
1
w
" | sudo fdisk "/dev/$disk"

### SWAP PARTITION
# make partition
printf "n
2

+%sG
w
" "$swap_gb"| sudo fdisk "/dev/$disk"
# format partition
printf "t
2
19
w
" | sudo fdisk "/dev/$disk"

### ROOT PARTITION
# make partition
printf "n
3


w
" | sudo fdisk "/dev/$disk"
log_echo "SUCCESS: Disk partiioning complete"
# this one dosent need formating

### FORMATING THE FILESYSTEM
log_echo "Formating the filesystem"
mkfs.vfat -F 32 "/dev/$disk"1
mkfs.ext4 "/dev/$disk"3
mkswap "/dev/$disk"2
swapon "/dev/$disk"2
log_echo "SUCCESS: Formating complete"

### MOUNTING
log_echo "Mounting the root partition"
mkdir --parents /mnt/gentoo
sudo mount "/dev/$disk"3 /mnt/gentoo
mkdir --parents /mnt/gentoo/efi
log_echo "SUCCESS: Mounting complete"

# exit if anything after here dosen't return 0
set -e
# ----- STAGE FILE ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Stage

log_echo "Downloading stage3 file"
cd /mnt/gentoo

wget "$stage_file_link"
log_echo "SUCCESS: Stage3 downloading complete, extracting the stage tar"
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo
log_echo "SUCCESS: Stage3 extraction complete"

# overwrite the default make.conf with the one in here
log_echo "Overwriting /etc/portage/make.conf"
cp -fr "$SCRIPT_DIR"/make.conf /mnt/gentoo/etc/portage/
log_echo "SUCCESS /etc/portage/make.conf successfully overwritten"

# also overwrite this for locale config
log_echo "Overwriting /etc/locale.gen"
cp -fr "$SCRIPT_DIR"/locale.gen /mnt/gentoo/etc/
log_echo "SUCCESS /etc/locale.gen successfully overwritten"

# ----- INSTALLING THE BASE SYSTEM ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Base

log_echo "Copying DNS info"
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
log_echo "SUCCESS: DNS info copied"

# prepare for chroot
log_echo "Mounting necessary filesystems for chroot"
sudo mount --types proc /proc /mnt/gentoo/proc
sudo mount --rbind /sys /mnt/gentoo/sys
sudo mount --make-rslave /mnt/gentoo/sys
sudo mount --rbind /dev /mnt/gentoo/dev
sudo mount --make-rslave /mnt/gentoo/dev
sudo mount --bind /run /mnt/gentoo/run
sudo mount --make-slave /mnt/gentoo/run 
log_echo "SUCCESS: Mounting complete"

# chroot
log_echo "Installing portage"
printf 'source /etc/profile 
export PS1="(chroot) ${PS1}"
mount /dev/%s1 /efi
emerge-webrsync
emerge --sync
' "$disk" | sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: Portage installation complete"

log_echo "Configuring the locale"
printf 'locale-gen
eselect locale set $(eselect locale list | grep -m1 "%s" | grep -oP "\[\K\d+(?=\])")
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
' "$default_locale" | sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: Locale successfully configured"

# ----- KERNEL CONFIG ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Kernel
# distro kernel patches
binp=""
if [[ $bin_dkernel = true ]]; then
	binp="emerge sys-kernel/gentoo-kernel-bin"
else
	binp="emerge sys-kernel/gentoo-kernel"
fi

log_echo "Installing the kernel"
printf 'emerge sys-kernel/linux-firmware sys-firmware/sof-firmware
echo "sys-kernel/installkernel grub dracut" > /etc/portage/package.use/installkernel
emerge sys-kernel/installkernel
%s
emerge --depclean
emerge @module-rebuild
' "$binp"| sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: Kernel installed"
# ----- SYSTEM CONFIGURATION ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/System

# fstab file
log_echo "Creating fstab file"
fstab_file=$(printf "$(cat "$SCRIPT_DIR/fstab")" "$disk" "$disk" "$disk") 
printf 'echo "%s" > /etc/fstab
' "$fstab_file"| sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: fstab file created"

# host name
log_echo "Setting the host name"
hosts_file=$(printf "$(cat $SCRIPT_DIR/hosts)" "$host_name" "$host_name" "$host_name" "$host_name") 
printf 'echo "%s" > /etc/hostname
echo "%s" > /etc/hosts
' "$host_name" "$hosts_file"| sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: Host name configured"

# network
log_echo "Installing NetworkManager"
printf 'emerge net-misc/networkmanager
rc-update add NetworkManager default
' | sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: NetworkManager installed"
# to prevent networkmanager changing the host name
log_echo "creating NetworkManager.conf"
printf 'printf "[main]\n# Stop NetworkManager from changing the hostname\nhostname-mode=none" > /etc/NetworkManager/NetworkManager.conf
' | sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: NetworkManager.conf successfully created"

### SYSTEM INFO
# root password
log_echo "Configuring root password"
printf 'printf "%s\n%s" | passwd
' "$root_password" "$root_password" | sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: Root password configured"

# init and boot configuration
# TODO
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/System#Init_and_boot_configuration

# ----- INSTALLIING TOOLS ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Tools
log_echo "Installing system tools"

# system logger
log_echo "Installing system logger(app-admin/sysklogd)"
printf 'emerge app-admin/sysklogd
rc-update add sysklogd default
' | sudo chroot /mnt/gentoo /bin/bash

# cron daemon
log_echo "Installing cron daemon(sys-process/cronie)"
printf 'emerge sys-process/cronie
rc-update add cronie default
' | sudo chroot /mnt/gentoo /bin/bash

log_echo "SUCCESS: System tools installed"

# ----- BOOTLOADER CONFIGURATION ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Bootloader
log_echo "Installing and configuring GRUB"

printf 'emerge --verbose sys-boot/grub
grub-install --efi-directory=/efi
grub-mkconfig -o /boot/grub/grub.cfg
' | sudo chroot /mnt/gentoo /bin/bash

log_echo "SUCCESS: GRUB installed and configured"

# ----- FINALIZING ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Finalizing

log_echo "Installing app-portage/gentoolkit"
printf 'emerge app-portage/gentoolkit
' | sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: app-portage/gentoolkit installed"

# adding the inital user
log_echo "Creating the initial user"
printf 'mkdir "/home/%s"
useradd -m -G audio,cdrom,cron,floppy,usb,video,wheel -s /bin/bash -d "/home/%s" "%s"
printf "%s\n%s\n" | passwd %s
' "$user_name" "$user_name" "$user_name" "$user_password" "$user_password" "$user_name" | sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: Initial user created"

# configuring sudo (optional)
log_echo "Installing and configuring sudo (app-admin/sudo)"
printf 'emerge app-admin/sudo
' | sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: sudo installed"
printf 'echo "%s" > /etc/sudoers
' "$(cat "$SCRIPT_DIR/sudoers")"| sudo chroot /mnt/gentoo /bin/bash
log_echo "SUCCESS: /etc/sudoers file created"

# remove the tar file
log_echo "Removing stage3 tar file"
printf 'rm /stage3-*.tar.*'| sudo chroot /mnt/gentoo /bin/bash

# umonting everything
log_echo "Unmounting /efi"
printf 'umount /efi'| sudo chroot /mnt/gentoo /bin/bash

log_echo "SUCCESS: Installation complete! Enjoy your new Gentoo system ;)"
if [[ $copy_log_to_home_dir = true ]]; then
	log_echo "Copying log file to '/etc/$user_name'"
	printf 'printf %s > %s' "$(cat $SCRIPT_DIR/$log_file)" "$log_file" | sudo chroot /mnt/gentoo /bin/bash
fi

log_echo "Unmounting /mnt/gentoo"
umount /mnt/gentoo

log_echo "You can reboot now."
