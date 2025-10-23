#!/usr/bin/env bash

function procedure() {
  
# Install the required dependency (Fedora-specific)
  dnf install dhcp-server

  routerIP=$1
  externalNet=$2
  internalNet=$3

  # Allow ipv4 forwarding
  echo "net.ipv4.ip_forward = 1" > /etc/sysctl.conf

  # Reload the config to apply changes
  sysctl -p

  # Add a static ip to the device on the interface
  # that will be the gateway of the internal network
  ip addr add "$routerIP" dev "$internalNet"

  # We append a rule to the nat table that handles
  # outgoing packets, by masquerading the src address
  # of the packet as the device's address on the external network
  iptables -t nat -A POSTROUTING -o "$externalNet" -j MASQUERADE

  # We append to the filter table (default table) that handles
  # packets being routed, on the condition that the packet
  # is associated with a connection which has seen packets in 
  # both directions or that it is starting a new connection 
  # associated with an existing one
  iptables -A FORWARD -i "$externalNet" -o "$internalNet" -m state --state RELATED,ESTABLISHED -j ACCEPT
  
  # Same thing but without a condition
  iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT

  # Configures dhcp server
  rm /etc/dhcpd.conf
  cp ./dhcpd.conf.example /etc/dhcp/dhcpd.conf
  systemctl enable dhcpd
  systemctl start dhcpd

  rm /etc/resolv.conf
  echo "nameserver 198.168.10.173" > /etc/resolv.conf

}



# Should be run with sudo

# Hard-coded because it is way too dependent
# on what the user wants and his device/distribution
internalNet="enp46s0"
externalNet="wlp45s0"
routerIP="198.168.10.1/24"

procedure $routerIP $externalNet $internalNet
