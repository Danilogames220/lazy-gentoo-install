> [!WARNING]
> The script works but isn't done yet. If you find any massive issue in the code, please create a pull request

> [!NOTE]
> This branch is for testing the script and fixing bugs in the script
# Lazy Gentoo Install
Automatic script for a minimal installation of Gentoo Linux

## About the installation
This script was made based on the official Gentoo Linux AMD64 handbook, this was made mostly for making the process for installing Gentoo in virtual machines easier, so thats why some important stuff isn't covered yet. After the script is done you should have a minimal installation with the desktop-openrc profile.

## How to use:
> [!WARNING]
> Do not use this script if you don't already know how to install gentoo or if this is your first time doing so, please verify each part of the script manualy before using it and caution if your using this outside of a virtual machine

> [!NOTE]
> This script assumes that the disk is empty and the time is set correctly
> - How to syncronise the time in the live ISO: https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Stage#Downloading_the_stage_file

### Before running the script

Clone this repo in a live environment(preferably, in one of the gentoo live images), configure your own setting in the install.sh variables, then run install.sh. After so, you will be prompted for a root password, then just wait for the instalation to end, then reboot.
