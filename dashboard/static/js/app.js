function checkStatus() {
    fetch('/api/status')
        .then(response => response.json())
        .then(data => {
            document.getElementById('status-text').textContent = 
                'Status: ' + data.status + ' - ' + data.message;
        })
        .catch(error => {
            document.getElementById('status-text').textContent = 'Error loading status';
        });
}

function loadClients() {
    fetch('/api/clients')
        .then(response => response.json())
        .then(data => {
            const container = document.getElementById('clients-container');
            if (data.clients && data.clients.length > 0) {
                container.innerHTML = data.clients.map(client => 
                    createClientHTML(client)
                ).join('');
            } else {
                container.innerHTML = '<p>No clients registered yet.</p>';
            }
        })
        .catch(error => {
            document.getElementById('clients-container').innerHTML = 
                '<p>Failed to load clients.</p>';
        });
}

function createClientHTML(client) {
    const statusClass = client.connected ? 'status-online' : 'status-offline';
    const statusText = client.connected ? 'Online' : 'Offline';
    
    return `
        <div class="client-item">
            <div class="client-info">
                <div class="client-name">${client.name}</div>
                <div class="client-ip">${client.ip}</div>
                <div class="client-status ${statusClass}">${statusText}</div>
            </div>
            <div class="client-actions">
                <button class="btn-small" onclick="downloadConfig('${client.name}')">
                    Download Config
                </button>
                <button class="btn-small" onclick="showQRCode('${client.name}')">
                    Show QR Code
                </button>
                <button class="btn-small btn-danger" onclick="removeClient('${client.name}')">
                    Remove
                </button>
            </div>
        </div>
    `;
}

function addClient() {
    const nameInput = document.getElementById('client-name');
    const clientName = nameInput.value.trim();
    
    if (!clientName) {
        showMessage('Please enter a client name', 'error');
        return;
    }

    fetch('/api/clients', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ name: clientName })
    })
    .then(response => response.json())
    .then(data => {
        if (data.message) {
            showMessage(data.message, 'success');
            nameInput.value = '';
            loadClients();
        } else {
            showMessage(data.error || 'Failed to add client', 'error');
        }
    })
    .catch(error => {
        showMessage('Failed to add client', 'error');
    });
}

function removeClient(clientName) {
    if (!confirm(`Are you sure you want to remove client "${clientName}"?`)) {
        return;
    }

    fetch(`/api/clients/${clientName}`, {
        method: 'DELETE'
    })
    .then(response => response.json())
    .then(data => {
        if (data.message) {
            showMessage(data.message, 'success');
            loadClients();
        } else {
            showMessage(data.error || 'Failed to remove client', 'error');
        }
    })
    .catch(error => {
        showMessage('Failed to remove client', 'error');
    });
}

function downloadConfig(clientName) {
    fetch(`/api/clients/${clientName}/config`)
        .then(response => response.json())
        .then(data => {
            if (data.config) {
                const blob = new Blob([data.config], { type: 'text/plain' });
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `${clientName}.conf`;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                window.URL.revokeObjectURL(url);
                showMessage(`Configuration downloaded for ${clientName}`, 'success');
            } else {
                showMessage(data.error || 'Failed to download configuration', 'error');
            }
        })
        .catch(error => {
            showMessage('Failed to download configuration', 'error');
        });
}

function showQRCode(clientName) {
    fetch(`/api/clients/${clientName}/qr`)
        .then(response => response.json())
        .then(data => {
            if (data.qr_code) {
                // Create modal for QR code display
                const modal = document.createElement('div');
                modal.className = 'qr-modal';
                modal.innerHTML = `
                    <div class="qr-modal-content">
                        <span class="qr-close" onclick="closeQRModal()">&times;</span>
                        <h3>QR Code for ${clientName}</h3>
                        <img src="${data.qr_code}" alt="QR Code" class="qr-image">
                        <p>Scan this QR code with your WireGuard mobile app</p>
                    </div>
                `;
                document.body.appendChild(modal);
                modal.style.display = 'block';
            } else {
                showMessage(data.error || 'Failed to generate QR code', 'error');
            }
        })
        .catch(error => {
            showMessage('Failed to generate QR code', 'error');
        });
}

function closeQRModal() {
    const modal = document.querySelector('.qr-modal');
    if (modal) {
        document.body.removeChild(modal);
    }
}

function showMessage(message, type) {
    const container = document.getElementById('message-container');
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${type}`;
    messageDiv.textContent = message;
    
    container.appendChild(messageDiv);
    
    setTimeout(() => {
        if (messageDiv.parentNode) {
            messageDiv.parentNode.removeChild(messageDiv);
        }
    }, 5000);
}

// Load status and clients on page load
document.addEventListener('DOMContentLoaded', () => {
    checkStatus();
    loadClients();
    
    // Setup form submission
    document.getElementById('add-client-form').addEventListener('submit', (e) => {
        e.preventDefault();
        addClient();
    });
    
    // Auto-refresh status and clients every 30 seconds
    setInterval(() => {
        checkStatus();
        loadClients();
    }, 30000);
});