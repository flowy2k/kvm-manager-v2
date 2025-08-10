# KVM Manager Complete Application

A comprehensive, production-ready web application for controlling MLEEDA KVM1001A hardware switches via RS232 serial communication. This is a multi-tier application with a Python backend, Express.js middleware, and modern web frontend.

## 🏗️ System Architecture

### Multi-Tier Architecture

1. **Frontend**: Modern JavaScript/HTML/CSS web interface
2. **Express.js Middleware**: Node.js API proxy and static file server (Port 3000)
3. **Python Backend**: FastAPI service for hardware control (Port 8081)
4. **Hardware Layer**: MLEEDA KVM1001A switch via RS232

### Technology Stack

- **Frontend**: Vanilla JavaScript, HTML5, CSS3 with modern responsive design
- **Middleware**: Express.js with CORS, Axios for API proxying
- **Backend**: Python FastAPI with PySerial for hardware communication
- **Package Management**: npm (Node.js), uv (Python)
- **Hardware Protocol**: ASCII commands over RS232 serial

## 🚀 Features

### 🖥️ Core Functionality

- **Port Selection**: Switch between KVM ports 1-10 with one-click
- **Real-time Status**: Live monitoring of current port, serial connection, and service health
- **Hardware Control**: Direct MLEEDA KVM1001A communication via RS232
- **KVM Display**: Embedded iframe for remote KVM interface viewing
- **Error Handling**: Comprehensive error recovery and user feedback

### ⚙️ Configuration Management

- **API Configuration**: Configurable backend service URLs
- **Serial Port Management**: Auto-detection and manual selection of serial devices
- **Custom Port Names**: User-friendly server names for each KVM port
- **Persistent Settings**: Browser localStorage for configuration persistence
- **Service Management**: Start/stop Python backend service from UI

### 🎨 Modern UI/UX

- **Professional Dark Theme**: Clean, modern interface with smooth animations
- **Responsive Design**: Works perfectly on desktop, tablet, and mobile
- **Real-time Feedback**: Loading indicators, status updates, and notifications
- **Accessibility**: Keyboard shortcuts and screen reader support

## 🔧 Hardware Specifications

### MLEEDA KVM1001A Protocol

- **Ports**: 10 computer inputs (1-10)
- **Commands**: ASCII format `X<port>,1$` (port 10 uses `XA,1$`)
- **Serial Config**: 115200 baud, 8N1, 1-second timeout
- **Timing**: 500ms delay after commands for hardware response
- **Connection**: RS232 via USB-to-Serial adapter

### Supported Serial Adapters

- FTDI USB-to-Serial converters
- CH340/CH341 USB-to-Serial adapters
- CP210x USB-to-UART bridges
- Standard `/dev/ttyUSB*` devices on Linux

## 📋 Installation & Setup

### Prerequisites

- **Node.js** 16+ with npm
- **Python** 3.11+
- **uv** package manager for Python
- **Serial adapter** connected to KVM switch

### Quick Start

1. **Clone and install dependencies**:

   ```bash
   cd kvm-mgr-ui
   npm install
   cd ../kvm-mgr-service
   uv sync
   ```

2. **Start the complete application**:

   ```bash
   cd kvm-mgr-ui
   npm start
   ```

   This starts the Express server on port 3000 and auto-launches the Python backend.

3. **Access the application**:
   Open `http://localhost:3000` in your browser

### Manual Service Management

**Start Python backend separately**:

```bash
cd kvm-mgr-service
uv run python main.py
```

**Start Express server only**:

```bash
cd kvm-mgr-ui
node server.js
```

## 🔌 API Endpoints

### Express Server (Port 3000)

```
GET  /                          - Frontend application
GET  /health                    - Service health check
GET  /api/service/status        - Backend service status
POST /api/service/start         - Start Python backend
POST /api/service/stop          - Stop Python backend

# Proxy endpoints to Python backend
GET  /api/serial_ports          - Available serial ports
GET  /api/ports                 - Available KVM ports
GET  /api/switch                - Switch KVM port
GET  /api/test_serial/:port     - Test serial connection

# Python environment management
GET  /api/python/check          - Check Python service
GET  /api/uv/check             - Check uv package manager
POST /api/uv/sync              - Sync Python dependencies
```

### Python Backend (Port 8081)

```
GET  /health                    - Service health
GET  /serial_ports             - List available serial ports
GET  /ports                    - Get KVM port configuration
GET  /switch?serial_port=<device>&port=<1-10>  - Switch port
GET  /test_serial/<device>     - Test serial connectivity
GET  /docs                     - FastAPI documentation
```

## 🎯 Usage Guide

### First-Time Setup

1. **Connect Hardware**:

   - Connect USB-to-Serial adapter to KVM switch
   - Connect KVM switch to target servers
   - Power on all equipment

2. **Configure Application**:

   - Open settings (⚙️ gear icon)
   - Verify API URL: `http://localhost:3000/api`
   - Select correct serial port from dropdown
   - Customize server names for each port
   - Set KVM UI URL if using remote interface

3. **Test Connection**:
   - Check status panel for "Connected" API status
   - Try switching to different ports
   - Verify KVM display shows correct interface

### Daily Operation

1. **Switch Servers**: Click any port button (1-10) to switch KVM focus
2. **Monitor Status**: Check status panel for current port and connection health
3. **View KVM**: Use embedded display for remote server console access
4. **Troubleshoot**: Check notifications for any error messages

### Settings Management

**API Configuration**:

- **API URL**: Express server endpoint (usually `http://localhost:3000/api`)
- **KVM UI URL**: Remote interface URL for iframe display

**Serial Configuration**:

- **Port Selection**: Choose from auto-detected USB serial devices
- **Default Override**: Manual selection overrides API defaults

**Port Naming**:

- **Custom Names**: Assign friendly names like "Database Server", "Web Server"
- **Persistent Storage**: Names saved in browser localStorage

## 🔍 Troubleshooting

### Common Issues

**"Python backend service unavailable"**

- Check if Python service is running: `ps aux | grep python`
- Restart via UI: Settings → Service Management
- Manual start: `cd kvm-mgr-service && uv run python main.py`

**"No serial ports available"**

- Verify USB-to-Serial adapter is connected
- Check Linux permissions: `sudo usermod -a -G dialout $USER`
- List devices manually: `ls -la /dev/ttyUSB*`

**"Failed to switch port"**

- Test serial connection in Settings
- Verify KVM switch power and RS232 connection
- Check serial port permissions and baud rate

**Frontend not loading**

- Ensure Express server is running on port 3000
- Check browser console for JavaScript errors
- Verify all static files are accessible

### Debug Mode

1. **Enable detailed logging**:

   ```bash
   cd kvm-mgr-service
   uv run python main.py --log-level debug
   ```

2. **Check service status**:

   ```bash
   curl http://localhost:3000/api/service/status
   curl http://localhost:8081/health
   ```

3. **Test serial connectivity**:
   ```bash
   curl "http://localhost:8081/test_serial/%2Fdev%2FttyUSB0"
   ```

## 🔒 Security Considerations

### Production Deployment

- **CORS Configuration**: Restrict origins in Express server
- **Input Validation**: All user inputs are sanitized
- **Serial Access**: Requires appropriate system permissions
- **Network Security**: Use HTTPS in production environments

### Default Security

- No authentication required (internal network tool)
- Iframe sandbox restrictions for KVM display
- Input validation for port numbers and serial paths
- Error messages don't expose sensitive system information

## 🔧 Development

### Project Structure

```
kvm-mgr-ui/
├── index.html          # Frontend application
├── styles.css          # Responsive CSS styling
├── script.js           # Frontend JavaScript
├── server.js           # Express.js middleware
├── package.json        # Node.js dependencies
└── README.md           # This documentation

kvm-mgr-service/
├── main.py             # Python FastAPI backend
├── pyproject.toml      # Python dependencies
└── uv.lock            # Dependency lock file
```

### Development Workflow

1. **Frontend Changes**: Edit HTML/CSS/JS, refresh browser
2. **Express Changes**: Edit server.js, restart with `node server.js`
3. **Python Changes**: Edit main.py, restart with `uv run python main.py`

### Testing

```bash
# Test Python backend
cd kvm-mgr-service
uv run python -m pytest

# Test Express endpoints
cd kvm-mgr-ui
npm test

# Manual API testing
curl http://localhost:3000/health
curl http://localhost:8081/health
```

## 📊 Performance & Monitoring

### Expected Performance

- **Port Switch Time**: < 2 seconds end-to-end
- **Serial Communication**: < 500ms hardware response
- **API Response Time**: < 100ms for status endpoints
- **Frontend Load Time**: < 1 second initial load

### Monitoring Endpoints

- `GET /health` - Express server health
- `GET /api/service/status` - Complete system status
- `GET /api/python/check` - Python backend availability

## 🤝 Contributing

### Code Standards

- **Python**: Follow PEP 8, use type hints
- **JavaScript**: ES6+, functional programming preferred
- **CSS**: BEM methodology, CSS custom properties
- **Documentation**: Update README for any API changes

### Pull Request Process

1. Fork repository and create feature branch
2. Implement changes with appropriate tests
3. Update documentation for new features
4. Submit PR with clear description

## 📞 Support

For technical support:

1. **Check Logs**: Express and Python service logs
2. **API Documentation**: Visit `/docs` endpoint on Python service
3. **Hardware Issues**: Verify RS232 connections and power
4. **Software Issues**: Check browser console and service status

## 📄 License

ISC License - Internal system administration tool

---

**Version**: 1.0.0  
**Last Updated**: August 2025  
**Compatible Hardware**: MLEEDA KVM1001A  
**Supported Platforms**: Linux, macOS, Windows

- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Professional Theme**: Clean, modern interface with smooth animations
- **Real-time Feedback**: Loading indicators and status notifications
- **Keyboard Shortcuts**: ESC to close settings modal

## API Integration

The application integrates with the KVM Manager API with the following endpoints:

### Endpoints Used

- `GET /ports` - Retrieve available KVM ports
- `GET /serial_ports` - Get available serial ports and default configuration
- `GET /switch?serial_port=<port>&port=<number>` - Switch to specified KVM port

### Default Configuration

- **API Hostname**: `https://rack-kvm-manager.flowy2k.com`
- **KVM UI URL**: `https://rack-kvm.flowy2k.com/`
- **Serial Port**: Auto-detected from API (typically `/dev/ttyUSB0`)

## Getting Started

### Prerequisites

- Modern web browser with JavaScript enabled
- Python 3 (for local development server)

### Running the Application

1. **Start the development server**:

   ```bash
   cd kvm-mgr-ui
   npm start
   # or
   python3 -m http.server 8081
   ```

2. **Open in browser**:
   Navigate to `http://localhost:8081`

3. **Configure settings** (if needed):
   - Click the Settings button in the top-right corner
   - Update API hostname, KVM UI URL, or serial port as needed
   - Customize server names for each port
   - Save settings

### First Time Setup

1. The application will automatically connect to the default KVM Manager API
2. Available ports and serial devices will be loaded automatically
3. Configure port names in Settings to match your server setup
4. Select a port to begin KVM switching

## Usage

### Switching Ports

1. Click any port button in the Server Ports section
2. The application will send a switch command to the KVM Manager API
3. Status will update to show the current active port
4. The KVM display will be available in the main viewing area

### Settings Configuration

1. Click the Settings (⚙️) button
2. **API Configuration**:
   - Update the KVM Manager API hostname if different from default
   - Change the KVM UI URL if using a custom interface
3. **Serial Port Configuration**:
   - Select from available serial devices
   - The default is automatically detected from the API
4. **Port Names**:
   - Assign friendly names to each port (e.g., "Database Server", "Web Server")
   - Names are displayed on the port selection buttons
5. Click "Save Settings" to persist changes

## Technical Details

### Architecture

- **Frontend**: Vanilla JavaScript, HTML5, CSS3
- **Storage**: Browser localStorage for configuration persistence
- **Communication**: RESTful API calls to KVM Manager backend
- **Display**: Embedded iframe for KVM interface

### Browser Compatibility

- Chrome/Chromium 80+
- Firefox 75+
- Safari 13+
- Edge 80+

### Storage

All settings are stored locally in the browser's localStorage:

- API configuration
- Serial port preferences
- Custom port names
- Override settings for default API values

## Troubleshooting

### Common Issues

**"Failed to connect to KVM Manager API"**

- Check that the API hostname is correct in Settings
- Verify the KVM Manager API is running and accessible
- Check browser console for specific error messages

**"No serial ports available"**

- Ensure the KVM Manager API is properly configured
- Check that serial devices are connected and recognized by the system
- Verify API endpoint `/serial_ports` is responding correctly

**KVM display not loading**

- Verify the KVM UI URL is correct in Settings
- Check that the KVM interface is accessible from your network
- Ensure the iframe is not blocked by browser security settings

### Development

For development and debugging:

1. Open browser developer tools (F12)
2. Check the Console tab for JavaScript errors
3. Monitor the Network tab for API request/response details
4. Use the Application tab to inspect localStorage settings

## Security Notes

- All API communications should use HTTPS in production
- The application stores configuration in browser localStorage (client-side only)
- No sensitive credentials are stored by the application
- Cross-origin requests may require proper CORS configuration on the API server

## Support

For issues related to:

- **KVM Manager API**: Check the backend service configuration
- **Network connectivity**: Verify firewall and network settings
- **Browser compatibility**: Ensure you're using a supported browser version
