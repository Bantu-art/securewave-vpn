#!/usr/bin/env python3
from flask import Flask, render_template, jsonify

app = Flask(__name__)

@app.route('/')
def dashboard():
    return render_template('index.html')

@app.route('/api/status')
def get_status():
    return jsonify({
        'status': 'running',
        'message': 'Flask dashboard is operational'
    })

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=False)