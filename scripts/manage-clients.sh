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

# Get next available IP address
get_next_ip() {
    # Start from 10.8.0.2 (server uses 10.8.0.1)
    local next_ip=2
    while grep -q "10.8.0.$next_ip/32" "$WG_CONFIG" 2>/dev/null; do
        ((next_ip++))
    done
    echo "10.8.0.$next_ip"
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
    local client_ip=$(get_next_ip)
    
    echo "Assigned IP: $client_ip"
    
    # Get server info
    local server_public_key=$(cat /etc/wireguard/server_public.key)
    local server_endpoint="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):51820"
    
    # Create client config file
    cat > "$CLIENT_DIR/$client_name.conf" << EOF
[Interface]
PrivateKey = $private_key
Address = $client_ip/24
DNS = 8.8.8.8

[Peer]
PublicKey = $server_public_key
Endpoint = $server_endpoint
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
    
    # Add client to server config
    cat >> "$WG_CONFIG" << EOF

[Peer]
PublicKey = $public_key
AllowedIPs = $client_ip/32
EOF
    
    # Reload WireGuard to apply changes
    systemctl reload wg-quick@wg0
    
    echo "Client '$client_name' created successfully!"
    echo "Config saved to: $CLIENT_DIR/$client_name.conf"
    echo "Client can now connect to the VPN"
}

# Test with command line argument
if [ "$1" = "add" ]; then
    add_client "$2"
else
    list_clients
fi
