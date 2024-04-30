#!/bin/bash

# Checking that script not runs from root
if [[ $EUID -eq 0 ]]; then
   echo "This script must be run as regular user with administrative rules" 
   exit 1
fi

# Setting Easy-RSA directory
dir="/home/"$(whoami)"/easy-rsa"

# Function for installing OpenVPN if CA is configured on a separate server
openvpn_inst ()
{
  # Installing Easy-RSA and preparing directories
  sudo apt-get update -q
  sudo apt-get install openvpn easy-rsa -y
  if [[ "$?" -eq 1 ]]; then
    echo "Can't install Easy-RSA. Please try again."
    exit 1
  fi
}

#Function for init PKI
init-pki ()
{
  mkdir "$dir"
  ln -s /usr/share/easy-rsa/* "$dir"
  chmod 700 "$dir"
  cd "$dir"
  
  # Write some vars for Easy-RSA and init PKI
  echo "set_var EASYRSA_ALGO            \"ec\"" > "$dir"/vars
  echo "set_var EASYRSA_DIGEST          \"sha512\"" >> "$dir"/vars
  
  "$dir"/easyrsa init-pki
}

# Function for creating an OpenVPN Server Certificate Request and Private Key
openvpn_req ()
{
  "$dir"/easyrsa gen-req server nopass
  sudo cp "$dir"/pki/private/server.key /etc/openvpn/server/
  
  echo "Please sign the following OpenVPN server request in CA"
  echo ""
  cat "$dir"/pki/reqs/server.req
}

echo "Please choose where you configured a CA server"

case "$option" in
  1) echo "On a separate server. Not here"
    openvpn_inst
    init-pki
    openvpn_req
  ;;
  2) echo "On this server. Right here"
    openvpn_inst
    openvpn_req
  ;;
  *) echo "Bad option"
    exit 1
  ;;
esac
