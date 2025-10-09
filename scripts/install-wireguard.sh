#!/bin/bash
set -e

# Update system
yum update -y

# Install EPEL repository for WireGuard
amazon-linux-extras install epel -y

# Install WireGuard
yum install wireguard-tools -y

# Install Nginx
yum install nginx -y

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Generate WireGuard server keys
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key

# Get server private key
SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)

# Create WireGuard server configuration
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.8.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

# Enable and start WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Configure Nginx for basic dashboard
cat > /etc/nginx/conf.d/wireguard.conf << 'EOF'
server {
    listen 443 ssl;
    server_name _;
    
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    
    location / {
        root /var/www/html;
        index index.html;
    }
    
    location /api/status {
        return 200 '{"status":"running","service":"wireguard"}';
        add_header Content-Type application/json;
    }
}
EOF

# Create SSL directories
mkdir -p /etc/ssl/private /etc/ssl/certs

# Generate self-signed SSL certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=wireguard-vpn"

# Create basic dashboard
mkdir -p /var/www/html
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>SecureWave VPN</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .status { padding: 20px; background: #f0f0f0; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>SecureWave VPN Server</h1>
    <div class="status">
        <h2>Server Status</h2>
        <p>WireGuard VPN server is running</p>
        <p>Server Public Key: <code id="pubkey">Loading...</code></p>
    </div>
    <script>
        fetch('/etc/wireguard/server_public.key')
            .then(response => response.text())
            .then(key => document.getElementById('pubkey').textContent = key.trim())
            .catch(() => document.getElementById('pubkey').textContent = 'Unable to load');
    </script>
</body>
</html>
EOF

# Enable and start Nginx
systemctl enable nginx
systemctl start nginx

# Create log entry
echo "WireGuard and Nginx installation completed at $(date)" >> /var/log/wireguard-install.log