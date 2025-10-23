# SecureWave VPN

A secure, cloud-based VPN solution built on AWS infrastructure using Infrastructure as Code (IaC) principles.

## Project Overview

SecureWave VPN provides a self-hosted VPN server running on AWS EC2 with WireGuard protocol for secure, fast connections. The entire infrastructure is managed through CloudFormation templates and automated CI/CD pipelines.

## Architecture

### Network Infrastructure
- **VPC**: Isolated virtual network (10.0.0.0/16)
- **Public Subnet**: Internet-facing subnet for VPN server (10.0.1.0/24)
- **Private Subnet**: Internal subnet for future expansion (10.0.3.0/24)
- **Internet Gateway**: Provides internet access to public subnet

### Security
- **Security Groups**: Strict firewall rules
  - SSH (22): Admin IP only
  - HTTPS (443): Public access for web management
  - WireGuard (51820/UDP): Public access for VPN connections
- **IAM Role**: EC2 instance permissions for AWS Systems Manager

### Compute
- **EC2 Instance**: t3.micro running Amazon Linux 2
- **EBS Volume**: 20GB gp3 storage
- **Key Pair**: SSH access for administration
- **WireGuard VPN**: Configured on 10.8.0.1/24 network
- **Flask Dashboard**: Python web interface for client management
- **Nginx Proxy**: HTTPS frontend with Flask backend integration

## Infrastructure as Code

### CloudFormation Templates
- `infra/network-stack.yml` - VPC, subnets, routing
- `infra/security-groups.yml` - Security group rules
- `infra/vpn-stack.yml` - EC2 instance, IAM roles

### Automation Scripts
- `scripts/install-wireguard.sh` - Automated WireGuard, Nginx, and Flask dashboard installation
- `scripts/manage-clients.sh` - Client management utilities
- `dashboard/` - Flask web dashboard for client management

### Flask Dashboard Architecture
- `dashboard/app.py` - Main Flask application with API endpoints
- `dashboard/templates/index.html` - Dashboard HTML template
- `dashboard/static/css/style.css` - Dashboard styling
- `dashboard/static/js/app.js` - Frontend JavaScript for API calls
- `dashboard/requirements.txt` - Python dependencies

### Environment Management
- **Development**: `dev/test` branch → dev environment
- **Production**: `main` branch → production environment

## CI/CD Pipeline

### GitHub Actions Workflow (`.github/workflows/deploy.yml`)
- **Validation**: Template syntax checking on PRs
- **Deployment**: Automated stack deployment on branch merges
- **Environment Separation**: Different AWS resources per environment

### Deployment Flow
1. Feature development on feature branches
2. PR to `dev/test` → validates templates
3. Merge to `dev/test` → deploys to dev environment
4. PR to `main` → validates templates
5. Merge to `main` → deploys to production

## Getting Started

### Quick Start
For detailed step-by-step instructions, see [Setup Guide](docs/setup.md).

### Prerequisites
- AWS Account with administrative permissions
- AWS CLI installed and configured
- GitHub repository with secrets configured
- Git for repository management

### Deployment Overview
1. **Setup AWS CLI** and configure credentials
2. **Create EC2 key pairs** for dev and production
3. **Configure GitHub secrets** with AWS credentials and parameters
4. **Deploy to dev/test** branch for development environment
5. **Deploy to main** branch for production environment

### AWS CLI Deployment Commands
```bash
# Deploy network infrastructure
aws cloudformation deploy \
  --template-file infra/network-stack.yml \
  --stack-name dev-network-stack

# Deploy security groups
aws cloudformation deploy \
  --template-file infra/security-groups.yml \
  --stack-name dev-security-groups \
  --parameter-overrides AdminIP=YOUR_IP/32 EnvironmentName=dev

# Deploy VPN server
aws cloudformation deploy \
  --template-file infra/vpn-stack.yml \
  --stack-name dev-vpn-stack \
  --parameter-overrides KeyPairName=dev-vpn-key EnvironmentName=dev \
  --capabilities CAPABILITY_NAMED_IAM
```

### Accessing the VPN Server
- **Web Dashboard**: `https://INSTANCE_PUBLIC_IP` (ignore SSL warning)
- **Flask Dashboard**: `http://INSTANCE_PUBLIC_IP:5000` (development)
- **SSH Access**: `ssh -i your-key.pem ec2-user@INSTANCE_PUBLIC_IP`
- **Systems Manager**: Connect via AWS Console → EC2 → Session Manager
- **WireGuard Port**: 51820/UDP for VPN connections

### Flask Dashboard Features
- **Real-time Status**: WireGuard service status and system uptime
- **Client Management UI**: Web interface for adding/removing VPN clients
- **Configuration Download**: One-click download of client .conf files
- **QR Code Generation**: Mobile-friendly QR codes for easy client setup
- **Connection Status**: Real-time monitoring of client online/offline status
- **Auto-refresh**: Automatic updates every 30 seconds
- **API Endpoints**: RESTful API for status and client management
- **Automated Deployment**: Complete Flask app deployment via CloudFormation
- **External Access**: Accessible at `http://SERVER_IP:5000`
- **Systemd Integration**: Runs as system service with auto-restart
- **Secure Permissions**: Automated sudo configuration for file access

### Client Management
```bash
# Download client management script
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/securewave-vpn/dev/test/scripts/manage-clients.sh -o manage-clients.sh
chmod +x manage-clients.sh

# List clients
sudo ./manage-clients.sh list

# Add a client
sudo ./manage-clients.sh add john

# Remove a client
sudo ./manage-clients.sh remove john

# View client config (for manual setup)
sudo cat /etc/wireguard/clients/john.conf
```

## Current Status

✅ **Completed**
- Network infrastructure (VPC, subnets, routing)
- Security groups with proper access controls
- EC2 instance provisioning with IAM roles
- CI/CD pipeline for automated deployments
- Environment separation (dev/prod)
- **WireGuard VPN server installation and configuration**
- **Nginx web dashboard with HTTPS**
- **Automated server setup via UserData scripts**
- **Server public key display via web interface**
- **Complete client management script (add/remove/list)**
- **Automatic IP assignment and configuration generation**
- **Secure client removal with immediate disconnection**
- **Flask dashboard with real server status monitoring**
- **Fully automated Flask deployment (templates, static files, systemd service)**
- **Real-time WireGuard service status and system uptime**
- **External access on port 5000 with proper security group rules**
- **Complete web-based client management interface (add/remove clients via UI)**
- **Client configuration download functionality with automatic file generation**
- **QR code generation for mobile client setup**
- **Client connection status monitoring with real-time updates**
- **Automated sudo permissions for Flask app to access client files**
- **Full client management workflow: add clients via web UI, list all clients with IPs, download configs, remove clients**
- **Resolved permission issues with comprehensive sudoers configuration for Flask app**

🚧 **In Progress**
- Bandwidth usage tracking
- Enhanced monitoring and logging

📋 **Next Steps**
- Bandwidth usage tracking
- Enhanced monitoring and logging setup
- Backup and disaster recovery
- Custom domain and proper SSL certificates
- Multi-user admin interface

## Resource Naming Convention

Resources are automatically named with environment prefixes:
- Dev: `dev-network-stack-VPC`, `dev-vpn-stack-VPNInstance`
- Prod: `prod-network-stack-VPC`, `prod-vpn-stack-VPNInstance`

## Security Features

- Network isolation with private/public subnet separation
- Minimal security group rules (principle of least privilege)
- SSH access restricted to admin IP addresses
- IAM roles instead of hardcoded credentials
- Environment-specific access controls
- WireGuard modern cryptography (ChaCha20, Poly1305)
- Self-signed SSL certificates for web dashboard
- Secure key generation and management

## Documentation

- **[Setup Guide](docs/setup.md)** - Complete deployment instructions from scratch
- **[Development Guide](DEVELOPMENT.md)** - Technical details, architecture decisions, and troubleshooting
- **[Client Management](#client-management)** - VPN client setup and management