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

// Load status on page load
document.addEventListener('DOMContentLoaded', () => {
    checkStatus();
});