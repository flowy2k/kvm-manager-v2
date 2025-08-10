class KVMManager {
    constructor() {
        // Debug: Log environment variables
        console.log('Environment variables loaded:', window.ENV);
        
        this.defaultSettings = {
            apiHostname: window.ENV?.API_HOSTNAME || 'http://localhost:8081',  // Express server API
            kvmUiUrl: window.ENV?.KVM_UI_URL || window.ENV?.KVM_WEB_UI_URL || '',
            serialPort: '/dev/ttyUSB0',
            theme: 'light',
            portNames: {
                1: window.ENV?.KVM_PORT_1_NAME || 'Server 1',
                2: window.ENV?.KVM_PORT_2_NAME || 'Server 2',
                3: window.ENV?.KVM_PORT_3_NAME || 'Server 3',
                4: window.ENV?.KVM_PORT_4_NAME || 'Server 4',
                5: window.ENV?.KVM_PORT_5_NAME || 'Server 5',
                6: window.ENV?.KVM_PORT_6_NAME || 'Server 6',
                7: window.ENV?.KVM_PORT_7_NAME || 'Server 7',
                8: window.ENV?.KVM_PORT_8_NAME || 'Server 8',
                9: window.ENV?.KVM_PORT_9_NAME || 'Server 9',
                10: window.ENV?.KVM_PORT_10_NAME || 'Server 10',
                11: window.ENV?.KVM_PORT_11_NAME || 'Server 11',
                12: window.ENV?.KVM_PORT_12_NAME || 'Server 12',
                13: window.ENV?.KVM_PORT_13_NAME || 'Server 13',
                14: window.ENV?.KVM_PORT_14_NAME || 'Server 14',
                15: window.ENV?.KVM_PORT_15_NAME || 'Server 15',
                16: window.ENV?.KVM_PORT_16_NAME || 'Server 16'
            }
        };
        
        this.settings = this.loadSettings();
        this.availablePorts = [];
        this.serialPorts = [];
        this.currentPort = null;
        this.eventListenersSetup = false;
        
        this.init();
        this.applyTheme();
    }

    init() {
        this.loadInitialData();
        this.setupEventListeners();
        this.updateKVMDisplay();
        this.checkBackendStatus();
        this.applyTheme();
    // Re-run display update after a short delay to handle late layout / env injection
    setTimeout(() => this.updateKVMDisplay(), 300);
    }

    loadSettings() {
        const saved = localStorage.getItem('kvmManagerSettings');
        console.log('Saved settings from localStorage:', saved);
        console.log('Default settings with env vars:', this.defaultSettings);
        
        if (saved) {
            try {
                const savedSettings = JSON.parse(saved);
                // Merge saved settings with defaults, prioritizing saved values
                const mergedSettings = { 
                    ...this.defaultSettings, 
                    ...savedSettings,
                    portNames: {
                        ...this.defaultSettings.portNames,
                        ...(savedSettings.portNames || {})
                    }
                };
                console.log('Merged settings:', mergedSettings);
                return mergedSettings;
            } catch (error) {
                console.error('Error parsing saved settings:', error);
                return { ...this.defaultSettings };
            }
        }
        console.log('Using default settings (no saved settings):', this.defaultSettings);
        return { ...this.defaultSettings };
    }

    saveSettings() {
        localStorage.setItem('kvmManagerSettings', JSON.stringify(this.settings));
    }

    applyTheme() {
        const theme = this.settings.theme || 'light';
        const root = document.documentElement;
        // Remove prior theme classes
        ['theme-light','theme-dark','theme-blue','dark'].forEach(c=>root.classList.remove(c));
        if (theme === 'dark') {
            root.classList.add('theme-dark','dark');
        } else if (theme === 'blue') {
            // Blue inherits dark base for contrast
            root.classList.add('theme-blue','dark');
        } else { // light
            root.classList.add('theme-light');
        }
        console.log('Applied theme:', theme, root.className);
    }

    async checkBackendStatus() {
        try {
            const response = await fetch('/api/service/status');
            const status = await response.json();
            
            if (status.python_service_healthy) {
                this.updateApiStatus('Connected');
            } else if (status.python_process_running) {
                this.updateApiStatus('Starting...');
                // Retry after a delay
                setTimeout(() => this.checkBackendStatus(), 2000);
            } else {
                this.updateApiStatus('Disconnected');
                this.showNotification('Python backend service is not running', 'warning');
            }
        } catch (error) {
            console.error('Error checking backend status:', error);
            this.updateApiStatus('Error');
        }
    }

    async loadInitialData() {
        try {
            await Promise.all([
                this.loadPorts(),
                this.loadSerialPorts()
            ]);
            this.renderPortGrid();
            this.updateStatus();
        } catch (error) {
            console.error('Failed to load initial data:', error);
            this.showNotification('Failed to connect to KVM Manager API', 'error');
            this.updateApiStatus('Error');
        }
    }

    async loadPorts() {
        try {
            const response = await fetch(`${this.settings.apiHostname}/ports`);
            if (!response.ok) throw new Error('Failed to fetch ports');
            
            const data = await response.json();
            this.availablePorts = data.available_ports || [];
            
            // Merge port names: localStorage > API response > defaults
            if (data.port_names) {
                const savedSettings = localStorage.getItem('kvmManagerSettings');
                let savedPortNames = {};
                
                if (savedSettings) {
                    try {
                        const parsed = JSON.parse(savedSettings);
                        savedPortNames = parsed.portNames || {};
                    } catch (e) {
                        console.error('Error parsing saved port names:', e);
                    }
                }
                
                // Update port names with priority: saved > API > default
                this.availablePorts.forEach(port => {
                    if (savedPortNames[port]) {
                        // Use saved name from localStorage
                        this.settings.portNames[port] = savedPortNames[port];
                    } else if (data.port_names[port]) {
                        // Use name from API (environment variables)
                        this.settings.portNames[port] = data.port_names[port];
                    }
                    // Otherwise keep existing default
                });
                
                console.log('🔀 Updated port names:', this.settings.portNames);
            }
            
            this.updateApiStatus('Connected');
        } catch (error) {
            console.error('Error loading ports:', error);
            this.updateApiStatus('Error');
            throw error;
        }
    }

    async loadSerialPorts() {
        try {
            const response = await fetch(`${this.settings.apiHostname}/serial_ports`);
            if (!response.ok) throw new Error('Failed to fetch serial ports');
            
            const data = await response.json();
            this.serialPorts = data.serial_ports || [];
            
            // Update default serial port if not already set by user
            if (!localStorage.getItem('kvmManagerSettings') && data.default_port) {
                this.settings.serialPort = data.default_port;
            }
        } catch (error) {
            console.error('Error loading serial ports:', error);
            throw error;
        }
    }

    renderPortGrid() {
        const portGrid = document.getElementById('portGrid');
        portGrid.innerHTML = '';

        this.availablePorts.forEach(port => {
            const portBtn = document.createElement('button');
            portBtn.className = 'port-btn';
            portBtn.onclick = () => this.switchPort(port);
            
            const portName = this.settings.portNames[port] || `Server ${port}`;
            
            portBtn.innerHTML = `
                <div class="port-name">${portName}</div>
                <div class="port-number">Port ${port}</div>
            `;
            
            portGrid.appendChild(portBtn);
        });
    }

    async switchPort(port) {
        if (this.currentPort === port) return;

        this.showLoading(true);
        
        try {
            const url = `${this.settings.apiHostname}/switch?serial_port=${encodeURIComponent(this.settings.serialPort)}&port=${port}`;
            const response = await fetch(url);
            
            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || 'Failed to switch port');
            }
            
            const data = await response.json();
            
            if (data.success) {
                this.currentPort = port;
                this.updatePortButtons();
                this.updateStatus();
                this.showNotification(`Successfully switched to Port ${port}`, 'success');
            } else {
                throw new Error(data.error || 'Switch operation failed');
            }
        } catch (error) {
            console.error('Error switching port:', error);
            this.showNotification(`Failed to switch to Port ${port}: ${error.message}`, 'error');
        } finally {
            this.showLoading(false);
        }
    }

    updatePortButtons() {
        const portButtons = document.querySelectorAll('.port-btn');
        portButtons.forEach((btn, index) => {
            const port = this.availablePorts[index];
            btn.classList.toggle('active', port === this.currentPort);
        });
    }

    updateStatus() {
        document.getElementById('currentPort').textContent = 
            this.currentPort ? `Port ${this.currentPort}` : 'None';
        document.getElementById('currentSerial').textContent = this.settings.serialPort;
    }

    updateApiStatus(status) {
        const statusElement = document.getElementById('apiStatus');
        statusElement.textContent = status;
    // Reset style classes (Tailwind friendly)
    const baseClasses = 'text-sm font-semibold';
    let colorClass = 'text-slate-300';
    if (status === 'Connected') colorClass = 'text-emerald-400';
    else if (status === 'Error' || status === 'Disconnected') colorClass = 'text-rose-400';
    else if (status === 'Starting...' || status === 'Starting') colorClass = 'text-amber-300';
    else colorClass = 'text-amber-300';
    statusElement.className = `${baseClasses} ${colorClass}`;
    }

    updateKVMDisplay() {
        const iframe = document.getElementById('kvmFrame');
        const emptyStateOverlay = document.getElementById('emptyStateOverlay');
        const wrapper = iframe?.parentElement;
        if (!iframe) {
            console.warn('Iframe element not found');
            return;
        }
        const url = (this.settings.kvmUiUrl || '').trim();
        if (url) {
            console.log('[KVM] Loading iframe URL:', url);
            // Prevent redundant reload
            if (iframe.src !== url) iframe.src = url;
            if (emptyStateOverlay) emptyStateOverlay.classList.add('hidden');
            iframe.style.opacity = '1';
            iframe.style.visibility = 'visible';
            iframe.onload = () => {
                console.log('[KVM] Iframe loaded');
                iframe.style.opacity = '1';
            };
            iframe.onerror = (e) => {
                console.error('[KVM] Iframe load error', e);
                if (emptyStateOverlay) emptyStateOverlay.classList.remove('hidden');
            };
        } else {
            console.log('[KVM] No URL configured; showing empty state');
            iframe.removeAttribute('src');
            iframe.style.opacity = '0';
            iframe.style.visibility = 'hidden';
            if (emptyStateOverlay) emptyStateOverlay.classList.remove('hidden');
        }
        if (wrapper) {
            // Ensure wrapper has a height
            if (!wrapper.style.minHeight) wrapper.style.minHeight = '900px';
        }
    }

    setupEventListeners() {
        // Only set up the modal close listener once
        if (!this.eventListenersSetup) {
            // Escape key to close modal
            document.addEventListener('keydown', (event) => {
                if (event.key === 'Escape') {
                    const modal = document.getElementById('settingsModal');
                    if (modal && !modal.classList.contains('hidden')) {
                        this.closeSettings();
                    }
                }
            });
            
            this.eventListenersSetup = true;
        }
    }

    showLoading(show) {
        const overlay = document.getElementById('loadingOverlay');
        if (show) {
            overlay.classList.remove('hidden');
            overlay.classList.add('flex');
        } else {
            overlay.classList.add('hidden');
            overlay.classList.remove('flex');
        }
    }

    showNotification(message, type = 'success') {
        const notification = document.getElementById('notification');
        if (notification && typeof notification.show === 'function') {
            notification.show(message, type);
            return;
        }
        // Fallback plain style
        notification.textContent = message;
        notification.style.display = 'block';
        setTimeout(() => { notification.style.display = 'none'; }, 4000);
    }

    openSettings() {
        this.populateSettingsModal();
        const modal = document.getElementById('settingsModal');
        modal.classList.remove('hidden');
        modal.classList.add('flex');
        
        // Add a one-time click handler specifically for this modal instance
        const modalBackdropHandler = (event) => {
            const modalContent = modal.querySelector('.w-full.max-w-4xl');
            // Only close if clicking outside the modal content
            if (!modalContent.contains(event.target)) {
                this.closeSettings();
                modal.removeEventListener('click', modalBackdropHandler);
            }
        };
        
        // Use a small delay to prevent immediate closure from the click that opened the modal
        setTimeout(() => {
            modal.addEventListener('click', modalBackdropHandler);
        }, 100);
    }

    closeSettings() {
        const modal = document.getElementById('settingsModal');
        modal.classList.add('hidden');
        modal.classList.remove('flex');
    }

    populateSettingsModal() {
        // Populate API settings
        document.getElementById('apiHostname').value = this.settings.apiHostname;
        document.getElementById('kvmUiUrl').value = this.settings.kvmUiUrl;
        document.getElementById('theme').value = this.settings.theme;
        // Live preview listener (attach once)
        const themeSelect = document.getElementById('theme');
        if (!themeSelect._kvmBound) {
            themeSelect.addEventListener('change', (e) => {
                this.settings.theme = e.target.value;
                this.applyTheme();
            });
            themeSelect._kvmBound = true;
        }

        // Populate serial port dropdown
        const serialSelect = document.getElementById('serialPort');
        serialSelect.innerHTML = '';
        
        if (this.serialPorts.length === 0) {
            serialSelect.innerHTML = '<option value="">No serial ports available</option>';
        } else {
            this.serialPorts.forEach(port => {
                const option = document.createElement('option');
                option.value = port.device;
                option.textContent = `${port.device} - ${port.description}`;
                option.selected = port.device === this.settings.serialPort;
                serialSelect.appendChild(option);
            });
        }

        // Populate port names
        this.populatePortNames();
    }

    populatePortNames() {
        const portNamesContainer = document.getElementById('portNames');
        portNamesContainer.innerHTML = '';

        this.availablePorts.forEach(port => {
            const div = document.createElement('div');
            div.className = 'space-y-1';
            
            const label = document.createElement('label');
            label.className = 'block text-xs font-medium text-slate-400';
            label.textContent = `Port ${port}`;
            
            const input = document.createElement('input');
            input.type = 'text';
            input.className = 'w-full rounded-lg bg-slate-800/70 border border-slate-700/70 focus:border-brand-400 focus:ring-brand-400 text-slate-200 placeholder-slate-500 text-sm';
            input.value = this.settings.portNames[port] || `Server ${port}`;
            input.placeholder = `Server ${port}`;
            input.id = `portName${port}`;
            
            div.appendChild(label);
            div.appendChild(input);
            portNamesContainer.appendChild(div);
        });
    }

    async saveSettingsFromForm() {
        try {
            // Update settings object
            this.settings.apiHostname = document.getElementById('apiHostname').value.trim();
            this.settings.kvmUiUrl = document.getElementById('kvmUiUrl').value.trim();
            this.settings.serialPort = document.getElementById('serialPort').value;
            this.settings.theme = document.getElementById('theme').value;

            // Update port names
            this.availablePorts.forEach(port => {
                const input = document.getElementById(`portName${port}`);
                if (input) {
                    this.settings.portNames[port] = input.value.trim() || `Server ${port}`;
                }
            });

            // Validate URLs
            if (this.settings.apiHostname && !this.isValidUrl(this.settings.apiHostname)) {
                throw new Error('Invalid API hostname URL');
            }
            if (this.settings.kvmUiUrl && !this.isValidUrl(this.settings.kvmUiUrl)) {
                throw new Error('Invalid KVM UI URL');
            }

            // Save to localStorage
            this.saveSettings();
            this.applyTheme();

            // Update UI
            this.renderPortGrid();
            this.updateStatus();
            this.updateKVMDisplay();

            // Reload data with new API hostname
            await this.loadInitialData();

            this.closeSettings();
            this.showNotification('Settings saved successfully', 'success');
        } catch (error) {
            console.error('Error saving settings:', error);
            this.showNotification(`Error saving settings: ${error.message}`, 'error');
        }
    }

    isValidUrl(string) {
        try {
            new URL(string);
            return true;
        } catch (_) {
            return false;
        }
    }

    // Additional utility methods for backend service management
    async startPythonService() {
        try {
            const response = await fetch('/api/service/start', { method: 'POST' });
            const data = await response.json();
            
            if (data.success) {
                this.showNotification('Python service start initiated', 'success');
                this.updateApiStatus('Starting...');
                
                // Check status after delay
                setTimeout(() => this.checkBackendStatus(), 3000);
            } else {
                this.showNotification('Failed to start Python service', 'error');
            }
        } catch (error) {
            console.error('Error starting Python service:', error);
            this.showNotification('Error starting Python service', 'error');
        }
    }

    async testSerialPort(serialPort) {
        try {
            const response = await fetch(`/api/test_serial/${encodeURIComponent(serialPort)}`);
            const data = await response.json();
            
            if (data.success) {
                this.showNotification(`Serial port ${serialPort} is working`, 'success');
            } else {
                this.showNotification(`Serial port test failed: ${data.error}`, 'error');
            }
        } catch (error) {
            console.error('Error testing serial port:', error);
            this.showNotification('Error testing serial port', 'error');
        }
    }
}

// Global functions for HTML onclick handlers
function openSettings() {
    kvmManager.openSettings();
}

function closeSettings() {
    kvmManager.closeSettings();
}

function saveSettings() {
    kvmManager.saveSettingsFromForm();
}

// Temporary function for testing - clears localStorage
function clearStorageForTesting() {
    localStorage.removeItem('kvmManagerSettings');
    console.log('🗑️ localStorage cleared for testing');
    location.reload();
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.kvmManager = new KVMManager();
});
