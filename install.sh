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
stage_file_link="https://gentoo.c3sl.ufpr.br/releases/amd64/autobuilds/20260510T170106Z/stage3-amd64-desktop-openrc-20260510T170106Z.tar.xz"

host_name="Gentoo"

# TODO leave this empty
swap_gb=4

core_count=8

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
function multi_pipe() {
	while read -r a; do
		printf "%s" "$a" | $1
	done 
}

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

# ----- STAGE FILE ----- #
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Stage

cd /mnt/gentoo

wget "$stage_file_link"
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo

# overwrite the default make.conf with the one in here
cp -fr "$SCRIPT_DIR"/make.conf /mnt/gentoo/etc/portage/

# ----- INSTALLING THE BASE SYSTEM ----- #
