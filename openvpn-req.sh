#!/bin/bash

# Checking that script not runs from root
if [[ $EUID -eq 0 ]]; then
   echo "This script must be run as regular user with administrative rules" 
   exit 1
fi

# Setting Easy-RSA and clients config directories
dir="/home/"$(whoami)"/easy-rsa"
clientdir="/home/"$(whoami)"/client-configs"

# Function for installing OpenVPN and Easy-RSA
openvpn_inst ()
{
  sudo apt-get update -q
  sudo apt-get install openvpn easy-rsa -y
  if [[ "$?" -eq 1 ]]; then
    echo "Can't install OpenVPN or Easy-RSA. Please try again."
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

# Function for creating an Certificate Request and Private Key
openvpn_req ()
{
  # Checking for arguments
  if [ $# -ne 1 ]; then
    echo "Please specify request name"
    echo "Usage: $0 <reqname>"
    exit 1
  fi
  reqname="$1"
  cd "$dir"
  "$dir"/easyrsa gen-req "$reqname" nopass
  if [[ "$?" -eq 1 ]]; then
    echo "Can't generate OpenVPN server request. Please try again."
    exit 1
  fi
}

# Function for Signing Certificate Request
openvpn_sign ()
{
  # Checking for arguments
  if [ $# -ne 3 ]; then
    echo "Please specify arguments. Full path to request file, name of the request and type (server or client)"
    echo "Usage: $0 <reqfile> <reqname> <type>"
    exit 1
  fi
  reqfile="$1"
  reqname="$2"
  type="$3"
  cd "$dir"
  "$dir"/easyrsa import-req "$reqfile" "$reqname"
  "$dir"/easyrsa sign-req "$type" "$reqname"
  if [[ "$?" -eq 1 ]]; then
    echo "Can't sign Certificate Request. Please try again."
    exit 1
  fi
}

# Generating TLS pre-shared key
openvpn_ta ()
{
  cd "$dir"
  openvpn --genkey secret ta.key
  if [[ "$?" -eq 1 ]]; then
    echo "Can't generate OpenVPN TLS pre-shared key. Please try again."
    exit 1
  fi
}

# Configuaring OpenVPN server
openvpn_conf ()
{
  # sudo cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf /etc/openvpn/server/
  # sudo sed -i -e 's/^tls-auth ta.key 0 # This file is secret/;&\ntls-crypt ta.key/' /etc/openvpn/server/server.conf
  # sudo sed -i -e 's/^cipher AES-256-CBC/;&\ncipher AES-256-GCM\nauth SHA256/' /etc/openvpn/server/server.conf
  # sudo sed -i -e '/^dh dh2048.pem/ { s/^/;/; n; s/^/dh none\n/ }' -e '/^dh dh.pem/ { s/^/;/; n; s/^/dh none\n/ }' /etc/openvpn/server/server.conf
  # sudo sed -i 's/^;user nobody/user nobody/' /etc/openvpn/server/server.conf
  # sudo sed -i 's/^;group nogroup/group nogroup/' /etc/openvpn/server/server.conf
  
  # Creating simple OpenVPN config
  sudo echo -e "port 1194
  proto udp
  dev tun
  ca ca.crt
  cert server.crt
  key server.key
  dh none
  server 10.8.0.0 255.255.255.0
  ifconfig-pool-persist /var/log/openvpn/ipp.txt
  keepalive 10 120
  tls-crypt ta.key
  cipher AES-256-GCM
  auth SHA256
  user nobody
  group nogroup
  persist-key
  persist-tun
  status /var/log/openvpn/openvpn-status.log
  verb 3
  explicit-exit-notify 1" > /etc/openvpn/server/server.conf
  
  # Asking for LZ4-v2 compression
  until [[ $ANSWER =~ (y|n) ]]; do
    read -rp "Do you want to enable LZ4-v2 compression? [y/n]: " -e ANSWER
  done
  if [[ $ANSWER == "y" ]]; then
    sudo echo "compress lz4-v2" >> /etc/openvpn/server/server.conf
    sudo echo 'push "compress lz4-v2"' >> /etc/openvpn/server/server.conf
  elif [[ $ANSWER == "n" ]]; then
    echo ""
  fi

  echo "Do you want to use the VPN to route all of your clients traffic over the VPN? (y/n)"
  echo ""
  read -r option
  if [[ "$option" == "y" ]]; then
    sudo echo "push \"redirect-gateway def1 bypass-dhcp\"" >> /etc/openvpn/server/server.conf
    
    echo "Please choose a DNS server:"
    echo "1 - Cloudflare"
    echo "2 - OpenDNS"
    echo "3 - Google"
    echo "4 - Yandex"
    echo "5 - Custom DNS"

    read -p option2
    case "$option2" in
      1) # Cloudflare
        sudo echo 'push "dhcp-option DNS 1.0.0.1"' >>/etc/openvpn/server.conf
        sudo echo 'push "dhcp-option DNS 1.1.1.1"' >>/etc/openvpn/server.conf
      ;;
      2) # OpenDNS
        sudo echo 'push "dhcp-option DNS 208.67.222.222"' >>/etc/openvpn/server.conf
        sudo echo 'push "dhcp-option DNS 208.67.220.220"' >>/etc/openvpn/server.conf
      ;;
      3) # Google
        sudo echo 'push "dhcp-option DNS 8.8.8.8"' >>/etc/openvpn/server.conf
        sud echo 'push "dhcp-option DNS 8.8.4.4"' >>/etc/openvpn/server.conf
      ;;
      4) # Yandex
        sudo echo 'push "dhcp-option DNS 77.88.8.8"' >>/etc/openvpn/server.conf
        sudo echo 'push "dhcp-option DNS 77.88.8.1"' >>/etc/openvpn/server.conf
      ;;
      4) # Custom DNS
        while true; do
          echo "Enter the DNS server address:"
          echo ""
          read dns_server

          if [[ $dns_server =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "You entered DNS server address: $dns_server"
            read -p "Is this the correct DNS server address? (y/n): " confirmation
            if [[ $confirmation == "y" ]]; then
              sudo echo "push \"dhcp-option DNS $dns_server\"" >>/etc/openvpn/server.conf

              read -p "Do you want to enter another DNS server address? (y/n): " add_more
              if [[ $add_more == "y" ]]; then
                continue
              else
                break
              fi
            else
              echo "Please enter the address again."
            fi
          else
            echo "Error: Invalid DNS server address entered. Please enter the address in the format xxx.xxx.xxx.xxx"
          fi
        done
      ;;
      # *) echo default
      # ;;
    esac
  elif [[ "$option" == "n" ]]; then
    echo "Traffic from your clients will not not be pushed through VPN"
  fi
}

same_vps ()
{
  # Installing OpenVPN
  openvpn_inst
  sudo cp -f "$dir"/pki/ca.crt /etc/openvpn/server/

  # Create request for OpenVPN server and sign it
  openvpn_req server
  sudo cp -f "$dir"/pki/private/server.key /etc/openvpn/server/
  openvpn_sign "$dir"/pki/reqs/server.req server server
  sudo cp -f "$dir"/pki/issued/server.crt /etc/openvpn/server/
  
  # Creating OpenVPN TLS pre-shared key
  openvpn_ta
  sudo cp ta.key /etc/openvpn/server
  
  # Generating request for OpenVPN client and sign it
  mkdir -p "$clientdir"/keys
  chmod -R 700 "$clientdir"
  read -p "Please enter a OpenVPN client name: " clientname
  openvpn_req "$clientname"
  cp -f "$dir"/pki/private/"$clientname".key "$clientdir"/keys
  openvpn_sign "$dir"/pki/reqs/"$clientname".req "$clientname" client
  cp -f "$dir"/pki/issued/"$clientname".crt "$clientdir"/keys

  # Copying another keys to clients directory
  cp -f "$dir"/ta.key "$clientdir"/keys
  sudo cp -f /etc/openvpn/server/ca.crt "$clientdir"/keys
  sudo chown "$(whoami)"."$(whoami)" "$clientdir"/keys/*
}

echo "Please choose where you configured a CA server (1 or 2)"
echo "1 - On a separate server. Not here"
echo "2 - On this server. Right here"
echo "3 - Create OpenVPN server request and sign it"
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
  2)echo "Trying to setting-up OpenVPN Server"
    same_vps
  ;;
  3)echo "Creating request and sign it"
    openvpn_req server
    openvpn_sign "$dir"/pki/reqs/server.req server server
  ;;
  *) echo "Bad option"
    exit 1
  ;;
esac
