#!/bin/bash
# ----- SETTINGS ----- #
user_name="assuero" # initial user, will have root permisions
user_password="" # if empty, this will be the same as root password

host_name="Gentoo"
disk_name="vda" # run lsblk to check for your disk

ram_gb=8
ssd_size_gb=32
core_count=8

# ----- READING ROOT PASSWORD ----- #
read -p "Root password: " root_password
if [[ -z $root_password || $root_password = "" ]]; then
	echo "ERROR: Root password is empty"
	exit 1
fi
echo "$root_password" > "PASSWORDS.txt"
echo "$user_password" >> "PASSWORDS.txt"

# ----- NETWORK ----- #
# TODO

# ----- DISK PARTITIONING ----- #
# "$disk_name"1: EFI
# "$disk_name"2: swap (half of $ram_gb)
# "$disk_name"1: / (ext4)

function multi_pipe() {
	while read -r a; do
		printf "%s" "$a" | $1
	done 
}

#cat <<END | multi_pipe "sudo fdsisk /dev/$disk_name"
#n 
#1
#t
#1
#1
#END

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

+4G
w
" | sudo fdisk "/dev/$disk"
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
