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
cd ~/easy-rsa
./easyrsa init-pki
