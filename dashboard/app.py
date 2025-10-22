#!/usr/bin/env python3
from flask import Flask, render_template, jsonify
import subprocess

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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)