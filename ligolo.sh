#!/bin/bash

# Prompt the user for the IP address to set the route
read -p "Enter the IP address to set the route (e.g., 172.16.10.0/24): " ip_address

# Create the TUN interface
sudo ip tuntap add user p3ta mode tun ligolo

# Bring the TUN interface up
sudo ip link set ligolo up
# Add the route using the provided IP address
sudo ip route add "$ip_address" dev ligolo

# Add the fixed route
sudo ip route add 240.0.0.1/32 dev ligolo

# Start the Ligolo proxy
sudo /opt/ligolo/proxy -selfcert -laddr 0.0.0.0:8443


