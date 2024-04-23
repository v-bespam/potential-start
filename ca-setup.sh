#!/bin/bash
# Setting Easy-RSA directory
dir="~/easy-rsa"

# Installing Easy-RSA and preparing directories
sudo apt update
sudo apt install easy-rsa
  if [[ "$?" -eq 1 ]]; then
    echo "Can't install Easy-RSA. Please try again."
    exit 1
  fi
mkdir "$dir"
ln -s /usr/share/easy-rsa/* "$dir"
chmod 700 "$dir"
"$dir"/easyrsa init-pki

# Write some vars for Easy-RSA
read -p "Enter the country name: " option
echo "set_var EASYRSA_REQ_COUNTRY     \"$option\"" >> "$dir"/vars

read -p "Enter the province name: " option
echo "set_var EASYRSA_REQ_PROVINCE    \"$option\"" >> "$dir"/vars

read -p "Enter the city name: " option
echo "set_var EASYRSA_REQ_CITY        \"$option\"" >> "$dir"/vars

read -p "Enter the organization name: " option
echo "set_var EASYRSA_REQ_ORG         \"$option\"" >> "$dir"/vars

read -p "Enter email: " option
echo "set_var EASYRSA_REQ_EMAIL       \"$option\"" >> "$dir"/vars

read -p "Enter the organizational unit: " option
echo "set_var EASYRSA_REQ_OU          \"$option\"" >> "$dir"/vars

echo "set_var EASYRSA_ALGO            \"ec\"" >> "$dir"/vars

echo "set_var EASYRSA_DIGEST          \"sha512\"" >> "$dir"/vars

# Creating root public and private key pair for CA
cd "$dir"
./easyrsa build-ca
