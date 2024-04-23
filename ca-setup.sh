#!/bin/bash

#Installing Easy-RSA and preparing directories
sudo apt update
sudo apt install easy-rsa
  if [[ "$?" -eq 1 ]]; then
    echo "Can't install Easy-RSA. Please try again."
    exit 1
  fi
mkdir ~/easy-rsa
ln -s /usr/share/easy-rsa/* ~/easy-rsa/
chmod 700 ~/easy-rsa
~/easy-rsa/easyrsa init-pki

# Write some vars for Easy-RSA
read -p "Enter the country name: " option
echo "set_var EASYRSA_REQ_COUNTRY     \"$option\"" >> ~/easy-rsa/vars

read -p "Enter the province name: " option
echo "set_var EASYRSA_REQ_PROVINCE    \"$option\"" >> ~/easy-rsa/vars

read -p "Enter the city name: " option
echo "set_var EASYRSA_REQ_CITY        \"$option\"" >> ~/easy-rsa/vars

read -p "Enter the organization name: " option
echo "set_var EASYRSA_REQ_ORG         \"$option\"" >> ~/easy-rsa/vars

read -p "Enter email: " option
echo "set_var EASYRSA_REQ_EMAIL       \"$option\"" >> ~/easy-rsa/vars

read -p "Enter the organizational unit: " option
echo "set_var EASYRSA_REQ_OU          \"$option\"" >> ~/easy-rsa/vars

echo "set_var EASYRSA_ALGO            \"ec\"" >> ~/easy-rsa/vars

echo "set_var EASYRSA_DIGEST          \"sha512\"" >> ~/easy-rsa/vars

# Creating root public and private key pair for CA
~/easy-rsa/easyrsa build-ca ~/easy-rsa/
