const express = require('express');
const cors = require('cors');
const axios = require('axios');
const path = require('path');
const { spawn } = require('child_process');
const fs = require('fs');

// Load environment variables from .env file
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const app = express();
const PORT = process.env.PORT || 3000;
const PYTHON_SERVICE_URL = 'http://localhost:8081';


// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname)));

// Global variables for Python process management
let pythonProcess = null;
let pythonServiceReady = false;

// Utility Functions
function log(message, level = 'INFO') {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] [${level}] ${message}`);
}

function startPythonService() {
    if (pythonProcess) {
        log('Python service already running');
        return;
    }

    log('Starting Python KVM service...');
    
    const servicePath = path.join(__dirname, '../kvm-mgr-service');
    pythonProcess = spawn('uv', ['run', 'python', 'main.py'], {
        cwd: servicePath,
        stdio: ['pipe', 'pipe', 'pipe']
    });

    pythonProcess.stdout.on('data', (data) => {
        const output = data.toString().trim();
        if (output.includes('Uvicorn running on')) {
            pythonServiceReady = true;
            log('Python service is ready');
        }
        log(`Python: ${output}`);
    });

    pythonProcess.stderr.on('data', (data) => {
        log(`Python Error: ${data.toString().trim()}`, 'ERROR');
    });

    pythonProcess.on('close', (code) => {
        log(`Python service exited with code ${code}`, code === 0 ? 'INFO' : 'ERROR');
        pythonProcess = null;
        pythonServiceReady = false;
    });

    pythonProcess.on('error', (error) => {
        log(`Failed to start Python service: ${error.message}`, 'ERROR');
        pythonProcess = null;
        pythonServiceReady = false;
    });
}

async function checkPythonService() {
    try {
        const response = await axios.get(`${PYTHON_SERVICE_URL}/health`, { timeout: 2000 });
        return response.status === 200;
    } catch (error) {
        return false;
    }
}

async function ensurePythonService() {
    const isRunning = await checkPythonService();
    if (!isRunning && !pythonProcess) {
        startPythonService();
        // Wait a bit for service to start
        await new Promise(resolve => setTimeout(resolve, 3000));
    }
    return await checkPythonService();
}

// API Routes

// Health check
app.get('/health', async (req, res) => {
    const pythonHealthy = await checkPythonService();
    
    res.json({
        status: 'healthy',
        service: 'KVM Manager Express Server',
        version: '1.0.0',
        python_backend: pythonHealthy ? 'running' : 'unavailable',
        timestamp: new Date().toISOString()
    });
});

// Python environment checks
app.get('/api/python/check', async (req, res) => {
    try {
        const isHealthy = await checkPythonService();
        res.json({
            available: isHealthy,
            url: PYTHON_SERVICE_URL,
            process_running: pythonProcess !== null
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/uv/check', (req, res) => {
    const uvProcess = spawn('uv', ['--version'], { stdio: 'pipe' });
    
    uvProcess.stdout.on('data', (data) => {
        res.json({
            available: true,
            version: data.toString().trim()
        });
    });

    uvProcess.on('error', (error) => {
        res.status(404).json({
            available: false,
            error: error.message
        });
    });
});

app.post('/api/uv/sync', async (req, res) => {
    try {
        const servicePath = path.join(__dirname, '../kvm-mgr-service');
        const syncProcess = spawn('uv', ['sync'], {
            cwd: servicePath,
            stdio: 'pipe'
        });

        let output = '';
        let error = '';

        syncProcess.stdout.on('data', (data) => {
            output += data.toString();
        });

        syncProcess.stderr.on('data', (data) => {
            error += data.toString();
        });

        syncProcess.on('close', (code) => {
            if (code === 0) {
                res.json({
                    success: true,
                    output: output,
                    message: 'Dependencies synced successfully'
                });
            } else {
                res.status(500).json({
                    success: false,
                    error: error,
                    code: code
                });
            }
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Proxy endpoints to Python backend
app.get('/api/serial_ports', async (req, res) => {
    try {
        const serviceReady = await ensurePythonService();
        if (!serviceReady) {
            return res.status(503).json({
                error: 'Python backend service unavailable',
                suggestion: 'Try starting the Python service manually'
            });
        }

        const host = req.query.host;
        const url = host ? `${host}/serial_ports` : `${PYTHON_SERVICE_URL}/serial_ports`;
        
        const response = await axios.get(url, { timeout: 5000 });
        res.json(response.data);
    } catch (error) {
        log(`Error proxying serial_ports: ${error.message}`, 'ERROR');
        res.status(error.response?.status || 500).json({
            error: error.message,
            details: error.response?.data || 'Backend service error'
        });
    }
});

app.get('/api/ports', async (req, res) => {
    try {
        const serviceReady = await ensurePythonService();
        if (!serviceReady) {
            return res.status(503).json({
                error: 'Python backend service unavailable'
            });
        }

        const host = req.query.host;
        const url = host ? `${host}/ports` : `${PYTHON_SERVICE_URL}/ports`;
        
        const response = await axios.get(url, { timeout: 5000 });
        res.json(response.data);
    } catch (error) {
        log(`Error proxying ports: ${error.message}`, 'ERROR');
        res.status(error.response?.status || 500).json({
            error: error.message,
            details: error.response?.data || 'Backend service error'
        });
    }
});

app.get('/api/switch', async (req, res) => {
    try {
        const serviceReady = await ensurePythonService();
        if (!serviceReady) {
            return res.status(503).json({
                error: 'Python backend service unavailable'
            });
        }

        const { serial_port, port, host } = req.query;
        
        if (!serial_port || !port) {
            return res.status(400).json({
                error: 'Missing required parameters: serial_port and port'
            });
        }

        const baseUrl = host || PYTHON_SERVICE_URL;
        const url = `${baseUrl}/switch?serial_port=${encodeURIComponent(serial_port)}&port=${port}`;
        
        log(`Switching KVM: port=${port}, serial_port=${serial_port}`);
        
        const response = await axios.get(url, { timeout: 10000 });
        res.json(response.data);
    } catch (error) {
        log(`Error proxying switch: ${error.message}`, 'ERROR');
        res.status(error.response?.status || 500).json({
            error: error.message,
            details: error.response?.data || 'Backend service error'
        });
    }
});

// Test endpoint for Python service
app.get('/api/test_serial/:serial_port', async (req, res) => {
    try {
        const serviceReady = await ensurePythonService();
        if (!serviceReady) {
            return res.status(503).json({
                error: 'Python backend service unavailable'
            });
        }

        const { serial_port } = req.params;
        const url = `${PYTHON_SERVICE_URL}/test_serial/${encodeURIComponent(serial_port)}`;
        
        const response = await axios.get(url, { timeout: 5000 });
        res.json(response.data);
    } catch (error) {
        log(`Error testing serial port: ${error.message}`, 'ERROR');
        res.status(error.response?.status || 500).json({
            error: error.message,
            details: error.response?.data || 'Backend service error'
        });
    }
});

// Service management endpoints
app.post('/api/service/start', (req, res) => {
    try {
        startPythonService();
        res.json({
            success: true,
            message: 'Python service start initiated'
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

app.post('/api/service/stop', (req, res) => {
    try {
        if (pythonProcess) {
            pythonProcess.kill('SIGTERM');
            res.json({
                success: true,
                message: 'Python service stop initiated'
            });
        } else {
            res.json({
                success: false,
                message: 'Python service not running'
            });
        }
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

app.get('/api/service/status', async (req, res) => {
    const isHealthy = await checkPythonService();
    res.json({
        python_process_running: pythonProcess !== null,
        python_service_healthy: isHealthy,
        python_service_ready: pythonServiceReady,
        service_url: PYTHON_SERVICE_URL
    });
});

// Test endpoint to verify environment variables
app.get('/debug/env', (req, res) => {
    const envVars = {
        API_HOSTNAME: process.env.API_HOSTNAME,
        KVM_UI_URL: process.env.KVM_UI_URL,
        portNames: {}
    };
    
    // Add all port name environment variables
    for (let i = 1; i <= 16; i++) {
        const envKey = `KVM_PORT_${i}_NAME`;
        envVars.portNames[i] = process.env[envKey];
    }
    
    res.json(envVars);
});

// Serve static files (frontend)
app.get('/', (req, res) => {
    try {
        const indexPath = path.join(__dirname, 'index.html');
        let html = fs.readFileSync(indexPath, 'utf8');
        
        // Inject environment variables
        const envConfig = {
            API_HOSTNAME: process.env.API_HOSTNAME || process.env.KVM_API_URL || `http://localhost:${PORT}/api`,
            KVM_WEB_UI_URL: process.env.KVM_WEB_UI_URL || process.env.KVM_UI_URL || '',
            // Include all KVM port names
            KVM_PORT_1_NAME: process.env.KVM_PORT_1_NAME,
            KVM_PORT_2_NAME: process.env.KVM_PORT_2_NAME,
            KVM_PORT_3_NAME: process.env.KVM_PORT_3_NAME,
            KVM_PORT_4_NAME: process.env.KVM_PORT_4_NAME,
            KVM_PORT_5_NAME: process.env.KVM_PORT_5_NAME,
            KVM_PORT_6_NAME: process.env.KVM_PORT_6_NAME,
            KVM_PORT_7_NAME: process.env.KVM_PORT_7_NAME,
            KVM_PORT_8_NAME: process.env.KVM_PORT_8_NAME,
            KVM_PORT_9_NAME: process.env.KVM_PORT_9_NAME,
            KVM_PORT_10_NAME: process.env.KVM_PORT_10_NAME,
            KVM_PORT_11_NAME: process.env.KVM_PORT_11_NAME,
            KVM_PORT_12_NAME: process.env.KVM_PORT_12_NAME,
            KVM_PORT_13_NAME: process.env.KVM_PORT_13_NAME,
            KVM_PORT_14_NAME: process.env.KVM_PORT_14_NAME,
            KVM_PORT_15_NAME: process.env.KVM_PORT_15_NAME,
            KVM_PORT_16_NAME: process.env.KVM_PORT_16_NAME
        };
        
        // Replace the environment configuration script
        const envScript = `
    <script>
        window.ENV = ${JSON.stringify(envConfig)};
    </script>`;
        
        html = html.replace(
            /<script>\s*window\.ENV\s*=\s*{[\s\S]*?};\s*<\/script>/,
            envScript
        );
        
        res.send(html);
    } catch (error) {
        log(`Error serving index.html: ${error.message}`, 'ERROR');
        res.status(500).send('Error loading application');
    }
});

// Error handling middleware
app.use((error, req, res, next) => {
    log(`Express Error: ${error.message}`, 'ERROR');
    res.status(500).json({
        error: 'Internal server error',
        message: error.message
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        error: 'Not found',
        path: req.path
    });
});

// Graceful shutdown
process.on('SIGINT', () => {
    log('Received SIGINT, shutting down gracefully...');
    
    if (pythonProcess) {
        log('Terminating Python service...');
        pythonProcess.kill('SIGTERM');
    }
    
    process.exit(0);
});

process.on('SIGTERM', () => {
    log('Received SIGTERM, shutting down gracefully...');
    
    if (pythonProcess) {
        log('Terminating Python service...');
        pythonProcess.kill('SIGTERM');
    }
    
    process.exit(0);
});

// Start server
app.listen(PORT, () => {
    log(`KVM Manager Express Server running on port ${PORT}`);
    log(`Frontend available at: http://localhost:${PORT}`);
    log(`API endpoints available at: http://localhost:${PORT}/api/*`);
    
    // Auto-start Python service only if enabled (disabled by default when running separately)
    const autoStartPython = process.env.AUTO_START_PYTHON_SERVICE === 'true';
    if (autoStartPython) {
        log('Auto-starting Python service (AUTO_START_PYTHON_SERVICE=true)');
        setTimeout(() => {
            startPythonService();
        }, 1000);
    } else {
        log('Python service auto-start disabled (set AUTO_START_PYTHON_SERVICE=true to enable)');
    }
});

module.exports = app;
