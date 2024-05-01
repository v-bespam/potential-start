#!/bin/bash

# Checking that script not runs from root
if [[ $EUID -eq 0 ]]; then
   echo "This script must be run as regular user with administrative rules" 
   exit 1
fi

# Setting Easy-RSA and client configs directories
dir="/home/"$(whoami)"/easy-rsa"
clientdir="/home"$(whoami)"/client-configs"

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
init_pki ()
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
  # Checking for arguments
  if [ $# -ne 1 ]; then
    echo "Использование: $0 <имя_запроса>"
    exit 1
  fi
  reqname="$1"
  cd "$dir"
  "$dir"/easyrsa gen-req "$reqname" nopass
  if [[ "$?" -eq 1 ]]; then
    echo "Can't generate OpenVPN server request. Please try again."
    exit 1
  fi
  #sudo cp -f "$dir"/pki/private/server.key /etc/openvpn/server/
}

# Function for Signing the OpenVPN Server’s Certificate Request and generating TLS pre-shared key
openvpn_sign ()
{
  # Checking for arguments
  if [ $# -ne 3 ]; then
    echo "Использование: $0 <имя_запроса>"
    exit 1
  fi

  reqfile="$1"
  reqname="$2"
  type="$3"
  cd "$dir"
  "$dir"/easyrsa import-req "$reqfile" "$reqname"
  "$dir"/easyrsa sign-req "$type" "$reqname"
  if [[ "$?" -eq 1 ]]; then
    echo "Can't sign OpenVPN server request. Please try again."
    exit 1
  fi
#  sudo cp -f "$dir"/pki/issued/server.crt /etc/openvpn/server/
#  sudo cp -f "$dir"/pki/ca.crt /etc/openvpn/server/
}

# Generating TLS pre-shared key
openvpn_ta ()
{
  cd "$dir"
  openvpn --genkey --secret ta.key
  if [[ "$?" -eq 1 ]]; then
    echo "Can't generate OpenVPN TLS pre-shared key. Please try again."
    exit 1
  fi
  sudo cp ta.key /etc/openvpn/server
}

# Generating a Client Certificate and Key Pair
openvpn_client ()
{
 mkdir -p "$clientdir"/keys
 chmod -R 700 "$clientdir"
 read -p "Please enter a OpenVPN client name: " clientname
 cd "$dir"
 "$dir"/easyrsa gen-req "$clientname" nopass
 cp pki/private/"$clientname".key "$clientdir"/keys/
 "$dir"/easyrsa import-req
}

echo "Please choose where you configured a CA server (1 or 2)"
echo "1 - On a separate server. Not here"
echo "2 - On this server. Right here"
echo "3 - OpenVPN server request seccefully singed. Continue to setup OpenVPN server"
read option

case "$option" in
  1)openvpn_inst
    init_pki
    openvpn_req
    echo "Please sign the following OpenVPN server request in CA"
    echo ""
    cat "$dir"/pki/reqs/server.req
    exit 0
  ;;
  2)openvpn_inst
    openvpn_req
    openvpn_sign
    openvpn_ta
  ;;
  3)echo "Creating request and sign it"
    openvpn_req server
    openvpn_sign "$dir"/pki/server.req server server
  ;;
  *) echo "Bad option"
    exit 1
  ;;
esac
