#/bin/bash

# Asking for username and groupname
read -p "Enter the username: " USERNAME
read -p "Enter the groupname (optional): " GROUPNAME

# Creating user
useradd -m "$USERNAME"

# Creating group if needed
if [ -n "$GROUPNAME" ]; then
    usermod -aG "$GROUPNAME" "$USERNAME"
fi

# Creating user password
passwd "$USERNAME"

# Adding them to sudo group
usermod -aG sudo "$USERNAME"

echo "User "$USERNAME" has been successfully added."

# Adding ssh key
mkdir -p /home/"$USERNAME"/.ssh/

# Asking for public ssh key
read -p "Enter public ssh key: " > /home/"$USERNAME"/.ssh/authorized_keys

# Disabling root login for ssh
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
