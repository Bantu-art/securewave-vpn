# Troubleshooting Guide

## Client Management Issues

### Problem: Web interface shows "Client added successfully" but client doesn't appear in list

**Cause**: Flask app missing `sudo` permissions for manage-clients.sh script

**Solution**: 
1. Update sudoers configuration:
```bash
sudo tee /etc/sudoers.d/vpn-dashboard << 'EOF'
vpn-dashboard ALL=(ALL) NOPASSWD: /usr/local/bin/manage-clients.sh, /usr/local/bin/manage-clients.sh *, /bin/ls /etc/wireguard/clients/, /bin/cat /etc/wireguard/clients/*, /bin/touch /etc/wireguard/clients/*
EOF
```

2. Ensure Flask app uses `sudo` in subprocess calls:
```python
result = subprocess.run(['sudo', '/usr/local/bin/manage-clients.sh', 'add', name], 
                      capture_output=True, text=True)
```

### Problem: Config download returns "Client configuration not found"

**Cause**: Flask app doesn't have permission to read client config files

**Solution**: Use `sudo` to read config files:
```python
result = subprocess.run(['sudo', 'cat', f'/etc/wireguard/clients/{name}.conf'], 
                      capture_output=True, text=True)
```

### Problem: Client removal fails with "Permission denied"

**Cause**: manage-clients.sh script needs write permissions to /etc/wireguard/

**Solution**: Ensure comprehensive sudoers permissions as shown above

## Service Issues

### Problem: Flask service fails to start

**Check**: 
```bash
sudo systemctl status vpn-dashboard
sudo journalctl -u vpn-dashboard -n 20
```

**Common causes**:
- Syntax errors in app.py
- Missing Python dependencies
- Port 5000 already in use

### Problem: "Address already in use" error

**Solution**:
```bash
sudo systemctl restart vpn-dashboard
```

## Permission Debugging

### Test Flask app permissions manually:
```bash
# Test as vpn-dashboard user
sudo -u vpn-dashboard sudo /usr/local/bin/manage-clients.sh list
sudo -u vpn-dashboard sudo cat /etc/wireguard/clients/testuser.conf
```

### Verify sudoers configuration:
```bash
sudo cat /etc/sudoers.d/vpn-dashboard
```