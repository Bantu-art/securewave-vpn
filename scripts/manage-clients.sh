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

# Run the function
list_clients
