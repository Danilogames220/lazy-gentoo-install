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

cat <<END | multi_pipe "sudo fdsisk /dev/$disk_name"
p
p
END


