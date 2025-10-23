#!/usr/bin/env python3
from flask import Flask, render_template, jsonify, request, send_file
import subprocess
import os
import qrcode
import io
import base64

app = Flask(__name__)

@app.route('/')
def dashboard():
    return render_template('index.html')

@app.route('/api/status')
def get_status():
    try:
        # Check WireGuard status
        wg_result = subprocess.run(['systemctl', 'is-active', 'wg-quick@wg0'], 
                                 capture_output=True, text=True)
        wg_status = wg_result.stdout.strip()
        
        # Get uptime
        uptime_result = subprocess.run(['uptime', '-p'], 
                                     capture_output=True, text=True)
        uptime = uptime_result.stdout.strip()
        
        # Create status message
        if wg_status == 'active':
            message = f'WireGuard active, {uptime}'
            status = 'running'
        else:
            message = f'WireGuard {wg_status}, {uptime}'
            status = 'warning'
            
        return jsonify({
            'status': status,
            'message': message
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Error getting status: {str(e)}'
        })

@app.route('/api/clients', methods=['GET'])
def get_clients():
    try:
        # Get actively connected clients (with recent handshakes)
        wg_result = subprocess.run(['sudo', 'wg', 'show', 'wg0'], 
                                 capture_output=True, text=True)
        active_ips = set()
        if wg_result.returncode == 0:
            lines = wg_result.stdout.split('\n')
            current_peer_ip = None
            has_recent_handshake = False
            
            for line in lines:
                if 'allowed ips:' in line and '/32' in line:
                    # Extract IP from "allowed ips: 10.8.0.3/32"
                    current_peer_ip = line.split(':')[1].strip().split('/')[0]
                elif 'latest handshake:' in line:
                    # Check if handshake is recent (within last 5 minutes)
                    if 'seconds ago' in line or 'minute ago' in line or ('minutes ago' in line and int(line.split()[2]) <= 5):
                        has_recent_handshake = True
                elif line.strip() == '' or line.startswith('peer:'):
                    # End of peer block - check if this peer is active
                    if current_peer_ip and has_recent_handshake:
                        active_ips.add(current_peer_ip)
                    current_peer_ip = None
                    has_recent_handshake = False
            
            # Handle last peer
            if current_peer_ip and has_recent_handshake:
                active_ips.add(current_peer_ip)
        
        # Get all registered clients
        result = subprocess.run(['sudo', 'ls', '/etc/wireguard/clients/'], 
                              capture_output=True, text=True)
        clients = []
        if result.returncode == 0:
            for filename in result.stdout.strip().split('\n'):
                if filename.endswith('.conf'):
                    client_name = filename[:-5]
                    config_result = subprocess.run(['sudo', 'cat', f'/etc/wireguard/clients/{filename}'], 
                                                 capture_output=True, text=True)
                    if config_result.returncode == 0:
                        ip = None
                        for line in config_result.stdout.split('\n'):
                            if line.startswith('Address = '):
                                ip = line.split('=')[1].strip().split('/')[0]
                                break
                        
                        if ip:
                            is_connected = ip in active_ips
                            clients.append({
                                'name': client_name, 
                                'ip': ip, 
                                'connected': is_connected
                            })
        return jsonify({'clients': clients})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/clients', methods=['POST'])
def add_client():
    try:
        data = request.get_json()
        name = data.get('name', '').strip()
        if not name:
            return jsonify({'error': 'Client name required'}), 400
            
        result = subprocess.run(['sudo', '/usr/local/bin/manage-clients.sh', 'add', name], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            return jsonify({'message': f'Client {name} added successfully'})
        else:
            return jsonify({'error': result.stderr.strip()}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/clients/<name>', methods=['DELETE'])
def remove_client(name):
    try:
        result = subprocess.run(['sudo', '/usr/local/bin/manage-clients.sh', 'remove', name], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            return jsonify({'message': f'Client {name} removed successfully'})
        else:
            return jsonify({'error': result.stderr.strip()}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/clients/<name>/config')
def get_client_config(name):
    try:
        result = subprocess.run(['sudo', 'cat', f'/etc/wireguard/clients/{name}.conf'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            return jsonify({'config': result.stdout})
        else:
            return jsonify({'error': 'Client configuration not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/clients/<name>/qr')
def get_client_qr(name):
    try:
        result = subprocess.run(['sudo', 'cat', f'/etc/wireguard/clients/{name}.conf'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            # Generate QR code
            qr = qrcode.QRCode(version=1, box_size=10, border=5)
            qr.add_data(result.stdout)
            qr.make(fit=True)
            
            # Create QR code image
            img = qr.make_image(fill_color="black", back_color="white")
            
            # Convert to base64 for JSON response
            img_buffer = io.BytesIO()
            img.save(img_buffer, format='PNG')
            img_buffer.seek(0)
            img_base64 = base64.b64encode(img_buffer.getvalue()).decode()
            
            return jsonify({'qr_code': f'data:image/png;base64,{img_base64}'})
        else:
            return jsonify({'error': 'Client configuration not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)