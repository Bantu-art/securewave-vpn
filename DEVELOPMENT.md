# SecureWave VPN - Development Documentation

This document chronicles every decision, challenge, and solution encountered during the development of SecureWave VPN.

## Project Genesis

### Initial Requirements
- Build a secure, self-hosted VPN solution on AWS
- Use Infrastructure as Code (IaC) principles
- Implement CI/CD for automated deployments
- Support multiple environments (dev/prod)
- Use WireGuard protocol for performance and security

### Technology Stack Decisions

**Why AWS?**
- Reliable cloud infrastructure
- Comprehensive IaC support via CloudFormation
- Global availability and scalability
- Strong security features (IAM, VPC, Security Groups)

**Why WireGuard?**
- Modern, lightweight VPN protocol
- Better performance than OpenVPN
- Simpler configuration
- Strong cryptography (ChaCha20, Poly1305)

**Why CloudFormation over Terraform?**
- Native AWS integration
- No state file management complexity
- Built-in rollback capabilities
- Cross-stack references for modular design

## Architecture Evolution

### Phase 1: Network Foundation

**Decision: Single AZ vs Multi-AZ**
- **Initial Plan**: Multi-AZ for redundancy
- **Reality Check**: VPN servers typically single-instance
- **Final Decision**: Single AZ for simplicity and cost
- **Reasoning**: VPN clients can reconnect if server fails, multi-AZ adds complexity without significant benefit

**VPC Design Decisions:**
```
10.0.0.0/16 - VPC CIDR
├── 10.0.1.0/24 - Public Subnet (VPN server)
└── 10.0.3.0/24 - Private Subnet (future expansion)
```

**Why this CIDR scheme?**
- 10.0.0.0/16 provides 65,536 IPs (plenty for growth)
- 10.0.1.0/24 for public subnet (254 usable IPs)
- 10.0.3.0/24 for private subnet (skipped .2 for future use)
- Follows AWS best practices for subnet sizing

### Phase 2: Security Implementation

**Security Group Strategy:**
```yaml
SSH (22/tcp): Admin IP only     # Principle of least privilege
HTTPS (443/tcp): 0.0.0.0/0     # Web dashboard access
WireGuard (51820/udp): 0.0.0.0/0  # VPN client access
```

**Why these ports?**
- SSH: Administrative access (restricted to admin IP)
- HTTPS: Web management interface (public but secured)
- 51820/UDP: WireGuard default port (industry standard)

**IAM Role Decision:**
- **Alternative**: Store AWS credentials on instance
- **Chosen**: IAM instance profile with AmazonSSMManagedInstanceCore
- **Reasoning**: No credential management, Systems Manager access, security best practice

### Phase 3: CI/CD Pipeline Design

**Branch Strategy:**
```
main branch → Production environment
dev/test branch → Development environment
feature branches → No deployment (PR validation only)
```

**Why this strategy?**
- Clear separation of environments
- Safe testing in dev before production
- PR validation prevents broken deployments
- Follows GitFlow principles

**GitHub Actions Workflow Decisions:**

**Validation on PRs:**
```yaml
on:
  pull_request:
    branches: [dev/test, main]
```
- Catches template syntax errors early
- Prevents broken code from being merged
- No actual deployment on PRs (safety)

**Deployment on Push:**
```yaml
on:
  push:
    branches: [dev/test, main]
```
- Only deploys when code is merged
- Environment determined by branch
- Automatic parameter selection

**Environment Variable Strategy:**
```yaml
if [ "${{ github.ref }}" == "refs/heads/main" ]; then
  echo "ENV_NAME=prod" >> $GITHUB_ENV
else
  echo "ENV_NAME=dev" >> $GITHUB_ENV
fi
```
- Dynamic environment selection
- Consistent naming convention
- Supports future branch additions

## Implementation Challenges & Solutions

### Challenge 1: Cross-Stack References

**Problem**: Security groups need VPC ID, VPN instance needs security group ID
**Initial Approach**: Hardcoded resource names
**Issue**: Doesn't work with environment prefixes (dev-network-stack vs network-stack)

**Solution**: Dynamic imports with environment parameters
```yaml
VpcId: 
  Fn::ImportValue: 
    Fn::Sub: ${EnvironmentName}-network-stack-VPC
```

**Why this works:**
- Environment name passed as parameter
- Dynamic stack name resolution
- Supports multiple environments

### Challenge 2: IAM Capabilities

**Problem**: CloudFormation deployment failed with "InsufficientCapabilitiesException"
**Root Cause**: Named IAM resources require CAPABILITY_NAMED_IAM
**Solution**: Updated workflow capability
```yaml
--capabilities CAPABILITY_NAMED_IAM
```

**Learning**: AWS requires explicit acknowledgment when creating named IAM resources

### Challenge 3: UserData Script Management

**Problem**: Should we inline scripts in CloudFormation or use external files?
**Decision**: External files with dynamic branch selection
```yaml
curl -fsSL https://raw.githubusercontent.com/.../scripts/install-wireguard.sh | bash
```

**Reasoning:**
- DRY principle (Don't Repeat Yourself)
- Version control for scripts
- Easier maintenance and testing
- Branch-specific script versions

**Branch Selection Logic:**
```bash
BRANCH="main"
if [ "${EnvironmentName}" = "dev" ]; then
  BRANCH="dev/test"
fi
```

### Challenge 4: SSL Certificate Issues

**Problem**: Nginx SSL setup failed - "/etc/ssl/private: No such file or directory"
**Root Cause**: Amazon Linux 2 doesn't create SSL directories by default
**Solution**: Create directories before certificate generation
```bash
mkdir -p /etc/ssl/private /etc/ssl/certs
```

**Learning**: Always verify directory existence before file operations

### Challenge 5: Web Dashboard Display Issues

**Problem**: Dashboard showed Amazon Linux welcome page instead of custom content
**Root Cause**: Nginx serving from /usr/share/nginx/html (default) vs /var/www/html (our content)
**Investigation Process:**
1. Checked file existence: Files were created
2. Checked Nginx config: Config was correct
3. Discovered symlink: `/usr/share/nginx/html/index.html → ../../doc/HTML/index.html`

**Solution**: Remove symlink and copy custom content
```bash
rm -f /usr/share/nginx/html/index.html
cp /var/www/html/index.html /usr/share/nginx/html/index.html
```

**Learning**: Always check for existing files/symlinks that might override your content

## WireGuard Configuration Decisions

### Server Configuration
```ini
[Interface]
PrivateKey = [server_private_key]
Address = 10.8.0.1/24
ListenPort = 51820
PostUp = iptables rules for NAT
PostDown = iptables cleanup rules
```

**Network Choice: 10.8.0.0/24**
- Doesn't conflict with common home networks (192.168.x.x, 10.0.x.x)
- Provides 254 client IPs (10.8.0.2 - 10.8.0.254)
- Industry standard for VPN networks

**NAT Configuration:**
```bash
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```
- Allows VPN clients to access internet through server
- %i represents WireGuard interface (wg0)
- MASQUERADE handles dynamic IP changes

## Client Management Strategy Evolution

### Initial Approach: Manual Configuration
- SSH into server
- Generate keys manually
- Edit config files by hand
- **Problem**: Not scalable, error-prone

### Evolved Approach: Scripted Management
**Decision**: Create `manage-clients.sh` script
**Development Strategy**: Incremental development
1. ✅ Basic setup and configuration
2. ✅ List clients function
3. ✅ Add client function (complete with IP assignment, config generation, server update)
4. ✅ Remove client function (secure removal with immediate disconnection)
5. ✅ Flask dashboard infrastructure setup
6. Web interface implementation (in progress)

**Why incremental?**
- Easier to understand and debug
- Test each function independently
- Commit working code frequently
- Reduce complexity

### Script Design Decisions

**File Organization:**
```
/etc/wireguard/wg0.conf          # Server config
/etc/wireguard/clients/          # Client configs directory
/etc/wireguard/server_*.key      # Server keys
```

**Why this structure?**
- Follows Linux filesystem conventions
- Separates server and client configs
- Easy to backup and manage
- Secure permissions (root only)

**Function Design Philosophy:**
- Single responsibility principle
- Input validation for all functions
- Graceful error handling
- Clear user feedback
- Automatic resource management (IP assignment, config generation)
- Zero-downtime updates (systemctl reload vs restart)

**Client Management Implementation:**
```bash
# Automatic IP assignment starting from 10.8.0.2
get_next_ip() { ... }

# Complete client provisioning (add_client):
# 1. Generate unique keys
# 2. Assign next available IP
# 3. Create client config file
# 4. Update server configuration
# 5. Reload WireGuard service

# Secure client removal (remove_client):
# 1. Extract client public key from config
# 2. Remove [Peer] section from server config
# 3. Delete client configuration file
# 4. Reload WireGuard (immediate disconnection)
# 5. Provide clear feedback
```

**CLI Interface Design:**
```bash
./manage-clients.sh {add|remove|list} [client_name]
# - Consistent command structure
# - Input validation and error handling
# - Clear usage examples and help
# - Immediate feedback on operations
```

## Security Considerations

### Key Management
- Server keys: 600 permissions (root only)
- Client keys: Generated per client, never reused
- Private keys never transmitted over network

### Network Security
- VPN traffic encrypted with WireGuard protocol
- Admin access restricted to specific IP
- No default passwords or credentials
- IAM roles instead of access keys

### Operational Security
- Systems Manager for secure remote access
- CloudFormation for infrastructure immutability
- Version controlled configurations
- Environment separation

## Performance Optimizations

### Instance Sizing
**Choice**: t3.micro
**Reasoning**: 
- Sufficient for small-scale VPN usage
- Burstable performance for occasional high load
- Cost-effective for personal/small team use
- Can be upgraded if needed

### Network Performance
- Single AZ deployment reduces latency
- WireGuard's efficient protocol design
- Direct internet gateway connection
- Optimized iptables rules

## Monitoring and Observability

### Current Monitoring
- Web dashboard for basic status
- WireGuard built-in peer status
- CloudFormation stack monitoring
- AWS CloudWatch (basic EC2 metrics)

### Planned Monitoring
- Client connection logs
- Bandwidth usage tracking
- Performance metrics
- Alerting for service issues

## Cost Optimization

### Infrastructure Costs
- t3.micro: ~$8.50/month (eligible for free tier)
- EBS gp3 20GB: ~$1.60/month
- Data transfer: Variable based on usage
- **Total**: ~$10-15/month for light usage

### Cost Optimization Strategies
- Single AZ deployment
- Right-sized instance
- gp3 storage (better price/performance than gp2)
- No NAT Gateway (not needed for our architecture)

## Lessons Learned

### Technical Lessons
1. **Always validate assumptions**: Check if directories exist before using them
2. **Test incrementally**: Small, testable changes are easier to debug
3. **Environment parity**: Dev should match prod as closely as possible
4. **Documentation matters**: Complex systems need detailed documentation

### Process Lessons
1. **Commit frequently**: Small, working commits are better than large changes
2. **Understand before implementing**: Don't copy-paste without understanding
3. **Plan for failure**: Always have rollback strategies
4. **Security first**: Build security in from the beginning

### AWS-Specific Lessons
1. **IAM capabilities**: Named resources need special permissions
2. **CloudFormation exports**: Must match exactly between stacks
3. **UserData limitations**: Scripts run once at launch, not on every boot
4. **Systems Manager**: Excellent alternative to SSH for management

## Future Enhancements

### Short Term (Next Sprint)
- **Phase 3: Client Management API** - Add/remove/list clients via web interface
- **Phase 4: Configuration Download** - Download client configs via web interface
- **Phase 5: Enhanced Status** - Real-time client connection status
- QR code generation for mobile clients
- Integration with existing Nginx setup

## Flask Dashboard Architecture

### Technology Decision: Flask vs PHP vs Node.js
**Chosen**: Python Flask
**Reasoning**:
- Developer familiarity with Python over PHP
- Lightweight and simple for VPN management use case
- Easy integration with existing bash scripts via subprocess
- Rich Python ecosystem for future features (QR codes, etc.)
- JSON API design for modern frontend integration

### Installation Strategy: Direct vs Virtual Environment
**Chosen**: Direct system installation
**Reasoning**:
- Single-purpose VPN server (no dependency conflicts)
- Simpler deployment and service management
- Better systemd integration
- Easier maintenance and updates

### Implementation Evolution

**Phase 1: Minimal Foundation (✅ Completed)**
```python
# Basic Flask structure
@app.route('/')
def dashboard():
    return render_template('index.html')

@app.route('/api/status')
def get_status():
    return jsonify({'status': 'running', 'message': 'Flask dashboard is operational'})
```

**Phase 2: Real Server Status (✅ Completed)**
```python
# System integration with subprocess
wg_result = subprocess.run(['systemctl', 'is-active', 'wg-quick@wg0'], 
                         capture_output=True, text=True)
uptime_result = subprocess.run(['uptime', '-p'], 
                             capture_output=True, text=True)

# Status logic
if wg_status == 'active':
    status = 'running'    # Green status
else:
    status = 'warning'    # Yellow/warning status
```

**Phase 3: Full Automation (✅ Completed)**
```bash
# CloudFormation UserData automatically:
# 1. Sets BRANCH variable based on environment
export BRANCH
if [ "${EnvironmentName}" = "dev" ]; then
  BRANCH="dev/test"
fi

# 2. Downloads install script from GitHub
curl -fsSL https://raw.githubusercontent.com/.../install-wireguard.sh | bash

# 3. Install script downloads all Flask files:
curl -fsSL https://raw.githubusercontent.com/.../dashboard/app.py
curl -fsSL https://raw.githubusercontent.com/.../dashboard/templates/index.html
curl -fsSL https://raw.githubusercontent.com/.../dashboard/static/css/style.css
curl -fsSL https://raw.githubusercontent.com/.../dashboard/static/js/app.js

# 4. Creates systemd service and starts Flask
systemctl enable vpn-dashboard
systemctl start vpn-dashboard
```

**Automation Achievements:**
- ✅ Complete Flask file structure deployment
- ✅ Automatic Flask version compatibility handling (`Flask>=2.2.0,<3.0.0`)
- ✅ External access configuration (`app.run(host='0.0.0.0', port=5000)`)
- ✅ Security group port 5000 opening
- ✅ Systemd service creation and startup
- ✅ Zero manual intervention required

**Current Status Display:**
- WireGuard service status (active/inactive)
- System uptime (real server uptime)
- Error handling for subprocess failures
- Dynamic status determination
- External web access at `http://SERVER_IP:5000`

**Frontend Integration:**
```javascript
// Status fetching with proper template system
fetch('/api/status')
    .then(response => response.json())
    .then(data => {
        document.getElementById('status-text').textContent = 
            'Status: ' + data.status + ' - ' + data.message;
    })
```

### Security Architecture
```bash
# Dedicated user for Flask application
useradd -r -s /bin/false vpn-dashboard

# Sudo access only for client management script
vpn-dashboard ALL=(ALL) NOPASSWD: /usr/local/bin/manage-clients.sh

# Flask runs on 0.0.0.0:5000 for external access
```

### Service Architecture
```
Client (HTTP) → Flask (5000) → System Commands → WireGuard
                    ↓
             manage-clients.sh
```

### Medium Term
- Enhanced monitoring and logging
- Automated client provisioning API
- Custom domain with proper SSL certificates
- Backup and disaster recovery

### Long Term
- Multi-region deployment
- Load balancing for high availability
- Advanced user management (LDAP/SSO integration)
- Bandwidth limiting and QoS

## Development Environment Setup

### Local Development
- Git repository with proper branching strategy
- Local testing of CloudFormation templates
- AWS CLI for manual testing and debugging

### Testing Strategy
- Template validation in CI/CD pipeline
- Manual testing in dev environment
- Incremental feature development
- Documentation of all changes

## Troubleshooting Guide

### Common Issues
1. **Permission Denied**: Use sudo for WireGuard operations
2. **Template Validation Errors**: Check YAML syntax and AWS resource properties
3. **Import/Export Mismatches**: Verify stack names and environment parameters
4. **Service Not Starting**: Check logs in /var/log/ and systemctl status

### Debugging Tools
- AWS CloudFormation console for stack events
- Systems Manager for secure server access
- CloudWatch logs for application debugging
- WireGuard built-in diagnostics (wg show)

## Conclusion

SecureWave VPN represents a modern approach to VPN infrastructure, combining cloud-native technologies with security best practices. The incremental development approach has allowed us to build a solid foundation while maintaining flexibility for future enhancements.

The project demonstrates the power of Infrastructure as Code, automated deployments, and careful architectural planning. Each decision was made with security, maintainability, and scalability in mind.

This documentation serves as both a historical record and a guide for future development, ensuring that the reasoning behind each decision is preserved for future team members and enhancements.