#!/bin/bash

# Basic configuration - where files are stored
WG_CONFIG="/etc/wireguard/wg0.conf"  # Server config file
CLIENT_DIR="/etc/wireguard/clients"   # Where we store client configs

# Create directory for client configs
mkdir -p $CLIENT_DIR

# List all clients
list_clients() {
    echo "=== Client List ==="
    
    # Show client config files (registered clients)
    echo "Registered clients:"
    if ls "$CLIENT_DIR"/*.conf 2>/dev/null; then
        for config in "$CLIENT_DIR"/*.conf; do
            client_name=$(basename "$config" .conf)
            echo "- $client_name"
        done
    else
        echo "No clients registered yet"
    fi
    
    echo ""
    # Show currently connected clients
    echo "Currently connected:"
    wg show wg0 peers 2>/dev/null || echo "No clients connected"
}

# Add a new client
add_client() {
    local client_name="$1"
    
    # Check if client name provided
    if [ -z "$client_name" ]; then
        echo "Usage: add_client <client_name>"
        return 1
    fi
    
    # Check if client already exists
    if [ -f "$CLIENT_DIR/$client_name.conf" ]; then
        echo "Client '$client_name' already exists"
        return 1
    fi
    
    echo "Creating client: $client_name"
    
    # Generate client keys
    local private_key=$(wg genkey)
    local public_key=$(echo "$private_key" | wg pubkey)
    
    echo "Keys generated for $client_name"
    echo "Public key: $public_key"
}

# Test with command line argument
if [ "$1" = "add" ]; then
    add_client "$2"
else
    list_clients
fi
