#!/bin/bash

# Basic configuration - where files are stored
WG_CONFIG="/etc/wireguard/wg0.conf"  # Server config file
CLIENT_DIR="/etc/wireguard/clients"   # Where we store client configs

# Create directory for client configs
mkdir -p $CLIENT_DIR

echo "Client management script initialized"
echo "Server config: $WG_CONFIG"
echo "Client configs will be stored in: $CLIENT_DIR"
