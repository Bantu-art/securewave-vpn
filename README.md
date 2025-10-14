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
- **Web Dashboard**: HTTPS interface for server management

## Infrastructure as Code

### CloudFormation Templates
- `infra/network-stack.yml` - VPC, subnets, routing
- `infra/security-groups.yml` - Security group rules
- `infra/vpn-stack.yml` - EC2 instance, IAM roles

### Automation Scripts
- `scripts/install-wireguard.sh` - Automated WireGuard and Nginx installation
- `scripts/manage-clients.sh` - Client management utilities (in development)

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

### Prerequisites
- AWS Account with appropriate permissions
- GitHub repository with secrets configured:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `DEV_ADMIN_IP` / `PROD_ADMIN_IP`
  - `DEV_KEY_PAIR` / `PROD_KEY_PAIR`

### Deployment
1. Create EC2 key pairs in AWS console
2. Configure GitHub secrets
3. Push to `dev/test` branch to deploy development environment
4. Merge to `main` to deploy production environment

### Accessing the VPN Server
- **Web Dashboard**: `https://INSTANCE_PUBLIC_IP` (ignore SSL warning)
- **SSH Access**: `ssh -i your-key.pem ec2-user@INSTANCE_PUBLIC_IP`
- **Systems Manager**: Connect via AWS Console → EC2 → Session Manager
- **WireGuard Port**: 51820/UDP for VPN connections

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

🚧 **In Progress**
- Web-based client management interface

📋 **Next Steps**
- QR code generation for mobile clients
- Enhanced web dashboard with client status
- Web-based client management interface
- Monitoring and logging setup
- Backup and disaster recovery
- Custom domain and proper SSL certificates

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

## Development

For detailed development information, architecture decisions, and troubleshooting, see [DEVELOPMENT.md](DEVELOPMENT.md).