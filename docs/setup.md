# SecureWave VPN - Complete Setup Guide

This guide provides step-by-step instructions to deploy SecureWave VPN from scratch.

## Prerequisites

### AWS Account Setup
1. **AWS Account** with administrative permissions
2. **AWS CLI** installed and configured
3. **Git** for repository management

### Install AWS CLI
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Windows
# Download and run AWS CLI MSI installer
```

### Configure AWS CLI
```bash
aws configure
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: us-east-1
# Default output format: json
```

## Step 1: Repository Setup

### Clone Repository
```bash
git clone https://github.com/YOUR_USERNAME/securewave-vpn.git
cd securewave-vpn
```

### Create Development Branch
```bash
git checkout -b dev/test
git push -u origin dev/test
```

## Step 2: AWS Infrastructure Prerequisites

### Create EC2 Key Pairs
```bash
# Development environment key pair
aws ec2 create-key-pair \
  --key-name dev-vpn-key \
  --query 'KeyMaterial' \
  --output text > dev-vpn-key.pem

# Production environment key pair
aws ec2 create-key-pair \
  --key-name prod-vpn-key \
  --query 'KeyMaterial' \
  --output text > prod-vpn-key.pem

# Set secure permissions
chmod 400 dev-vpn-key.pem prod-vpn-key.pem
```

### Get Your Public IP
```bash
# Get your current public IP for admin access
curl ifconfig.me
# Note this IP - you'll need it for GitHub secrets
```

## Step 3: GitHub Repository Configuration

### Configure GitHub Secrets
Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:
```
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
DEV_ADMIN_IP=YOUR_IP/32
PROD_ADMIN_IP=YOUR_IP/32
DEV_KEY_PAIR=dev-vpn-key
PROD_KEY_PAIR=prod-vpn-key
```

## Step 4: Deploy Development Environment

### Validate Templates Locally (Optional)
```bash
# Validate CloudFormation templates
aws cloudformation validate-template --template-body file://infra/network-stack.yml
aws cloudformation validate-template --template-body file://infra/security-groups.yml
aws cloudformation validate-template --template-body file://infra/vpn-stack.yml
```

### Deploy via GitHub Actions
```bash
# Push to dev/test branch to trigger deployment
git add .
git commit -m "Initial deployment to dev environment"
git push origin dev/test
```

### Monitor Deployment
1. Go to GitHub → Actions tab
2. Watch the deployment workflow
3. Check AWS CloudFormation console for stack creation

### Manual Deployment (Alternative)
If you prefer manual deployment:

```bash
# Deploy network stack
aws cloudformation deploy \
  --template-file infra/network-stack.yml \
  --stack-name dev-network-stack \
  --no-fail-on-empty-changeset

# Deploy security groups
aws cloudformation deploy \
  --template-file infra/security-groups.yml \
  --stack-name dev-security-groups \
  --parameter-overrides AdminIP=YOUR_IP/32 EnvironmentName=dev \
  --no-fail-on-empty-changeset

# Deploy VPN stack
aws cloudformation deploy \
  --template-file infra/vpn-stack.yml \
  --stack-name dev-vpn-stack \
  --parameter-overrides KeyPairName=dev-vpn-key EnvironmentName=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset
```

## Step 5: Verify Development Deployment

### Get Instance Information
```bash
# Get VPN instance public IP
aws cloudformation describe-stacks \
  --stack-name dev-vpn-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`VPNInstancePublicIP`].OutputValue' \
  --output text
```

### Test Web Dashboard
```bash
# Replace with your instance IP
curl -k https://YOUR_INSTANCE_IP
# Should show SecureWave VPN dashboard
```

### Connect via Systems Manager
```bash
# Get instance ID
INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name dev-vpn-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`VPNInstanceId`].OutputValue' \
  --output text)

# Start SSM session
aws ssm start-session --target $INSTANCE_ID
```

## Step 6: Client Management Setup

### Download Client Management Script
```bash
# On the VPN server (via Systems Manager)
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/securewave-vpn/dev/test/scripts/manage-clients.sh -o manage-clients.sh
chmod +x manage-clients.sh
```

### Test Client Management
```bash
# List clients (should be empty initially)
sudo ./manage-clients.sh list

# Add a test client
sudo ./manage-clients.sh add testuser

# Verify client was created
sudo ./manage-clients.sh list
sudo ls -la /etc/wireguard/clients/
```

## Step 7: Deploy Production Environment

### Create Production Branch PR
```bash
# Create PR from dev/test to main
git checkout main
git pull origin main
git merge dev/test
git push origin main
```

### Monitor Production Deployment
1. GitHub Actions will automatically deploy to production
2. Monitor CloudFormation stacks with `prod-` prefix
3. Production will use `PROD_ADMIN_IP` and `PROD_KEY_PAIR`

## Step 8: Client Configuration

### Generate Client Configuration
```bash
# On VPN server, add a client
sudo ./manage-clients.sh add john

# View the client configuration
sudo cat /etc/wireguard/clients/john.conf
```

### Client Setup Instructions
1. **Install WireGuard client** on your device
2. **Copy the client configuration** from the server
3. **Import configuration** into WireGuard client
4. **Connect** to the VPN

### Download Client Config Securely
```bash
# Copy config content via Systems Manager
sudo cat /etc/wireguard/clients/john.conf

# Or via SCP (if using SSH)
scp -i dev-vpn-key.pem ec2-user@YOUR_INSTANCE_IP:/etc/wireguard/clients/john.conf ./john.conf
```

## Step 9: Verification and Testing

### Test VPN Connection
1. **Connect client** to VPN
2. **Check IP address**: Visit whatismyipaddress.com
3. **Verify traffic routing**: Should show VPN server IP

### Monitor Connected Clients
```bash
# On VPN server
sudo ./manage-clients.sh list
sudo wg show
```

### Test Client Management
```bash
# Add multiple clients
sudo ./manage-clients.sh add alice
sudo ./manage-clients.sh add bob

# Remove a client
sudo ./manage-clients.sh remove alice

# Verify removal
sudo ./manage-clients.sh list
```

## Troubleshooting

### Common Issues

**1. CloudFormation Stack Fails**
```bash
# Check stack events
aws cloudformation describe-stack-events --stack-name STACK_NAME

# Check template validation
aws cloudformation validate-template --template-body file://TEMPLATE_FILE
```

**2. Instance Not Accessible**
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx

# Verify instance is running
aws ec2 describe-instances --instance-ids i-xxxxxxxxx
```

**3. WireGuard Not Working**
```bash
# Check WireGuard status
sudo systemctl status wg-quick@wg0

# Check WireGuard configuration
sudo wg show

# Check logs
sudo journalctl -u wg-quick@wg0
```

**4. Web Dashboard Not Loading**
```bash
# Check Nginx status
sudo systemctl status nginx

# Check Nginx configuration
sudo nginx -t

# Check SSL certificates
sudo ls -la /etc/ssl/certs/nginx-selfsigned.crt
```

### Useful Commands

```bash
# Check all CloudFormation stacks
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE

# Get stack outputs
aws cloudformation describe-stacks --stack-name STACK_NAME --query 'Stacks[0].Outputs'

# Connect to instance via SSM
aws ssm start-session --target INSTANCE_ID

# Check instance logs
aws logs describe-log-groups
aws logs get-log-events --log-group-name LOG_GROUP_NAME --log-stream-name LOG_STREAM_NAME
```

## Cleanup

### Delete Development Environment
```bash
# Delete stacks in reverse order
aws cloudformation delete-stack --stack-name dev-vpn-stack
aws cloudformation delete-stack --stack-name dev-security-groups
aws cloudformation delete-stack --stack-name dev-network-stack

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete --stack-name dev-vpn-stack
aws cloudformation wait stack-delete-complete --stack-name dev-security-groups
aws cloudformation wait stack-delete-complete --stack-name dev-network-stack
```

### Delete Production Environment
```bash
# Delete production stacks
aws cloudformation delete-stack --stack-name prod-vpn-stack
aws cloudformation delete-stack --stack-name prod-security-groups
aws cloudformation delete-stack --stack-name prod-network-stack
```

### Clean Up Key Pairs
```bash
# Delete EC2 key pairs
aws ec2 delete-key-pair --key-name dev-vpn-key
aws ec2 delete-key-pair --key-name prod-vpn-key

# Remove local key files
rm dev-vpn-key.pem prod-vpn-key.pem
```

## Next Steps

1. **Set up monitoring** with CloudWatch
2. **Configure custom domain** with Route 53
3. **Implement proper SSL certificates** with ACM
4. **Add backup strategies** for configurations
5. **Enhance web dashboard** with client management UI

## Support

For issues and questions:
1. Check [DEVELOPMENT.md](../DEVELOPMENT.md) for technical details
2. Review CloudFormation stack events in AWS console
3. Check GitHub Actions workflow logs
4. Use AWS Systems Manager for server access and debugging