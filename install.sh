#!/bin/bash
# ----- SETTINGS ----- #
# initial user, will have root permisions
user_name="assuero" 
user_password="" # if empty, this will be the same as root password

# the disk where gentoo will be installed
disk="vda" # run lsblk in the live install to check for your disk

# Link of the stage file that will be used in the installation
# you can find it here: https://www.gentoo.org/downloads/mirrors/
# TODO leave this empty
stage_file_link="https://distfiles.gentoo.org/releases/amd64/autobuilds/20260712T170110Z/stage3-amd64-desktop-openrc-20260712T170110Z.tar.xz"

host_name="Gentoo"

# TODO leave this empty
swap_gb=4

core_count=8

# the locale that you want to use in the system
default_locale="pt_BR.UTF-8"
#default_locale="en_US.UTF-8"

# set this to false if you want to compile the pached kernel install of downloading the binary
bin_dkernel=true

# remove this line after every variable is set up to your installation
config_done=0

# ----- INSTALL SETUP ----- #
# $config_done check
if [[ -n $config_done ]]; then
	echo 'ERROR: Installation configuration variables not fully reviewed. Edit the variables under SETTINGS acording to your machine and remove the config_done variable to proceed.'
	# TODO uncomment this 
	#exit 1
fi


# password check
read -p "Root password: " root_password
if [[ -z $root_password || $root_password = "" ]]; then
	echo "ERROR: Root password is empty."
	exit 1
fi
if [[ "$user_password" = "" ]]; then
	user_password="$root_password"
fi
# echo "$root_password" > "PASSWORDS.txt"
# echo "$user_password" >> "PASSWORDS.txt"

### common variables / functions
# dir where the script is running
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )


# ----- NETWORK ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Networking
# TODO

# ----- DISK PARTITIONING ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Disks
# "$disk"1: EFI
# "$disk"2: swap (half of $ram_gb)
# "$disk"1: / (ext4)

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
# this one dosent need formating

### FORMATING THE FILESYSTEM
mkfs.vfat -F 32 "/dev/$disk"1
mkfs.ext4 "/dev/$disk"3
mkswap "/dev/$disk"2
swapon "/dev/$disk"2

### MOUNTING
mkdir --parents /mnt/gentoo
sudo mount "/dev/$disk"3 /mnt/gentoo
mkdir --parents /mnt/gentoo/efi

# exit if anything after here dosen't return 0
set -e
# ----- STAGE FILE ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Stage

cd /mnt/gentoo

wget "$stage_file_link"
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo

# overwrite the default make.conf with the one in here
cp -fr "$SCRIPT_DIR"/make.conf /mnt/gentoo/etc/portage/
# also overwrite this for locale config
cp -fr "$SCRIPT_DIR"/locale.gen /mnt/gentoo/etc/

# ----- INSTALLING THE BASE SYSTEM ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Base

cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

# prepare for chroot
sudo mount --types proc /proc /mnt/gentoo/proc
sudo mount --rbind /sys /mnt/gentoo/sys
sudo mount --make-rslave /mnt/gentoo/sys
sudo mount --rbind /dev /mnt/gentoo/dev
sudo mount --make-rslave /mnt/gentoo/dev
sudo mount --bind /run /mnt/gentoo/run
sudo mount --make-slave /mnt/gentoo/run 

# chroot
printf 'source /etc/profile 
export PS1="(chroot) ${PS1}"
mount /dev/%s1 /efi
emerge-webrsync
emerge --sync
locale-gen
eselect locale set $(eselect locale list | grep -m1 "%s" | grep -oP "\[\K\d+(?=\])")
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
' "$disk" "$default_locale" | sudo chroot /mnt/gentoo /bin/bash

# ----- KERNEL CONFIG ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Kernel
# distro kernel patches
binp=""
if [[ $bin_dkernel = true ]]; then
	binp="emerge sys-kernel/gentoo-kernel-bin"
else
	binp="emerge sys-kernel/gentoo-kernel"
fi

printf 'emerge sys-kernel/linux-firmware sys-firmware/sof-firmware
echo "sys-kernel/installkernel grub dracut" > /etc/portage/package.use/installkernel
emerge sys-kernel/installkernel
%s
emerge --depclean
emerge @module-rebuild
' "$binp"| sudo chroot /mnt/gentoo /bin/bash
# ----- SYSTEM CONFIGURATION ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/System

# fstab file
fstab_file=$(printf "$(cat "$SCRIPT_DIR/fstab")" "$disk" "$disk" "$disk") 
printf 'echo "%s" > /etc/fstab
' "$fstab_file"| sudo chroot /mnt/gentoo /bin/bash

# host name
hosts_file=$(printf "$(cat $SCRIPT_DIR/hosts)" "$host_name" "$host_name" "$host_name" "$host_name") 
printf 'echo "%s" > /etc/hostname
echo "%s" > /etc/hosts
' "$host_name" "$hosts_file"| sudo chroot /mnt/gentoo /bin/bash

# network
printf 'emerge net-misc/networkmanager
rc-update add NetworkManager default
' | sudo chroot /mnt/gentoo /bin/bash
# to prevent networkmanager changing the host name
printf 'printf "[main]\n# Stop NetworkManager from changing the hostname\nhostname-mode=none" > /etc/NetworkManager/NetworkManager.conf
' | sudo chroot /mnt/gentoo /bin/bash

### SYSTEM INFO
# root password
printf 'printf "%s\n%s" | passwd
' "$root_password" "$root_password" | sudo chroot /mnt/gentoo /bin/bash

# init and boot configuration
# TODO
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/System#Init_and_boot_configuration

# ----- INSTALLIING TOOLS ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Tools

# system logger
printf 'emerge app-admin/sysklogd
rc-update add sysklogd default
' | sudo chroot /mnt/gentoo /bin/bash

# cron daemon
printf 'emerge sys-process/cronie
rc-update add cronie default
' | sudo chroot /mnt/gentoo /bin/bash

# ----- BOOTLOADER CONFIGURATION ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Bootloader

printf 'emerge --verbose sys-boot/grub
grub-install --efi-directory=/efi
grub-mkconfig -o /boot/grub/grub.cfg
' | sudo chroot /mnt/gentoo /bin/bash

# ----- FINALIZING ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Finalizing

printf 'emerge app-portage/gentoolkit
' | sudo chroot /mnt/gentoo /bin/bash

# adding the default user
printf 'useradd -m -G audio,cdrom,cron,floppy,usb,video,wheel -s /bin/bash "%s"
printf "%s\n%s\n" | passwd %s
' "$user_name" "$user_password" "$user_password" "$user_name" | sudo chroot /mnt/gentoo /bin/bash

# configuring sudo (optional)
printf 'emerge app-admin/sudo
' | sudo chroot /mnt/gentoo /bin/bash

printf 'echo "%s" > /etc/sudoers
' "$(cat "$SCRIPT_DIR/sudoers")"| sudo chroot /mnt/gentoo /bin/bash

# remove the tar file
printf 'rm /stage3-*.tar.*'| sudo chroot /mnt/gentoo /bin/bash

# umonting everything
printf 'umount /efi'| sudo chroot /mnt/gentoo /bin/bash
# NOTE: if using arch-chroot, remove this
umount /mnt/gentoo/proc
umount /mnt/gentoo/sys
umount /mnt/gentoo/sys
umount /mnt/gentoo/dev
umount /mnt/gentoo/dev
umount /mnt/gentoo/run
umount /mnt/gentoo/run 

umount /mnt/gentoo

echo "SUCESS: Installation complete(at $date)! Reboot your system, remove the live image and enjoy your Gentoo :D"
