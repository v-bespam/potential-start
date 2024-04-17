#/bin/bash

# Asking for username
read -p "Enter the username: " USERNAME

# Creating user
useradd -m "$USERNAME"

# Creating user password
passwd "$USERNAME"

# Adding them to sudo group
usermod -aG sudo "$USERNAME"
  if [[ "$?" -eq 1 ]]; then
    echo "Something went wrong. Please try again."
    exit 1
  fi
echo "User "$USERNAME" has been successfully added."

# Import ssh key from root
#rsync --archive --chown="$USERNAME":"$USERNAME" ~/.ssh /home/"$USERNAME"
mkdir -p /home/"$USERNAME"/.ssh/
cat ~/.ssh/authorized_keys > /home/"$USERNAME"/.ssh/authorized_keys
chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/.ssh/

# Disabling root login for ssh
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

# Enabling firewall
apt update -qq > /dev/null
apt install ufw -yqq
ufw allow OpenSSH
  if [[ "$?" -eq 0 ]]; then
    echo "Everything was Ok."
  else
    echo "Something went wrong, can't enable OpenSSH for firewall."
    exit 1
  fi
ufw enable -y
echo "Everything looks good. You can now login with user $USERNAME and your ssh key."
exit 0
