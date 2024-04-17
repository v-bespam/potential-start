#/bin/bash

# Asking for username and groupname
read -p "Enter the username: " USERNAME

# Creating user
useradd -m "$USERNAME"

# Creating user password
passwd "$USERNAME"

# Adding them to sudo group
usermod -aG sudo "$USERNAME"

echo "User "$USERNAME" has been successfully added."

# Import ssh key from root
rsync --archive --chown="$USERNAME":"$USERNAME" ~/.ssh /home/"$USERNAME"

# Disabling root login for ssh
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

# Enabling firewall
ufw allow OpenSSH
ufw enable -y
