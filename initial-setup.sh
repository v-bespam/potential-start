#!/bin/bash

# Checking that script runs from root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Checking system
lsb_dist="$(. /etc/os-release && echo "$ID")"
if [[ $lsb_dist != "ubuntu" ]]; then
  echo "This script is meant to work in Ubuntu. Do you want to continue? (y/n)"
  read $option 
  case "$option" in
    n) echo "Aborting."
      exit 1
    ;;
    y) continue
    ;;
    *) echo "Bad option"
      exit 1
    ;;
  esac
fi

# Asking for hostname
read -p "Enter new hostname: " HOSTNAME
hostnamectl hostname "$HOSTNAME"

# Asking for username
read -p "Enter the username: " USERNAME

# Creating user
useradd -m "$USERNAME"
  if [[ "$?" -eq 1 ]]; then
    echo "Something went wrong. Please try again."
    exit 1
  fi

# Creating user password
passwd "$USERNAME"

# Adding them to sudo group
usermod -aG sudo "$USERNAME"
echo "User "$USERNAME" has been successfully added."

# Import ssh key from root
mkdir -p /home/"$USERNAME"/.ssh/
cat ~/.ssh/authorized_keys > /home/"$USERNAME"/.ssh/authorized_keys
chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/.ssh/

# Disabling root login for ssh
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
systemctl restart sshd

# Enabling firewall
apt-get update -qq > /dev/null
apt-get install ufw -y
ufw allow OpenSSH
  if [[ "$?" -eq 1 ]]; then
    echo "Something went wrong, can't enable OpenSSH for firewall."
    exit 1
  fi
ufw enable
echo "Everything looks good. You can now login with user $USERNAME and your ssh key."
exit 0
