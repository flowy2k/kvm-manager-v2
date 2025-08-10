# KVM Manager Docker Deployment Guide

## Prerequisites

1. **Docker & Docker Compose**:

   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER

   # Install Docker Compose
   sudo apt update
   sudo apt install docker-compose-plugin

   # Verify installation
   docker --version
   docker compose version
   ```

2. **Serial Device Access**:

   ```bash
   # Add user to dialout group for serial access
   sudo usermod -aG dialout $USER

   # Check if device exists
   ls -la /dev/ttyUSB*
   ```

## Quick Start

1. **Automated Deployment**:

   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

2. **Manual Deployment**:

   ```bash
   # Build the image
   docker build -t kvm-manager .

   # Start services
   docker compose up -d

   # Check status
   docker compose ps
   ```

## Build Options

### Primary Build (Multi-stage with UV)

```bash
# Uses main Dockerfile with multi-stage build
docker build -t kvm-manager .
```

### Simplified Build (Single-stage)

```bash
# Uses simplified approach if primary build fails
DOCKERFILE=Dockerfile.simple docker build -f Dockerfile.simple -t kvm-manager .
```

### Development Build with Debug

```bash
# Debug the build process
./debug-build.sh
```

## Troubleshooting

### Build Issues

1. **UV Package Manager Error**:

   ```
   ERROR: Could not find root package 'kvm-mgr-service'
   ```

   **Solution**: The build script will automatically try the simplified Dockerfile

2. **Permission Issues**:

   ```
   ERROR: failed to solve: executor failed running [/bin/sh -c uv sync]
   ```

   **Solution**: Check file permissions and ensure Docker daemon is running

3. **Serial Device Access**:

   ```bash
   # Check device permissions
   ls -la /dev/ttyUSB0

   # Test inside container
   docker exec -it kvm-manager ls -la /dev/ttyUSB0
   ```

### Runtime Issues

1. **Service Health Checks**:

   ```bash
   # Check service status
   docker compose ps

   # View logs
   docker compose logs kvm-manager
   docker compose logs -f kvm-manager  # Follow logs
   ```

2. **Port Conflicts**:

   ```bash
   # Check if ports are in use
   sudo netstat -tlnp | grep -E ':(3000|8081)'

   # Stop conflicting services
   sudo systemctl stop nginx  # If using system nginx
   ```

3. **Serial Device Not Found**:

   ```bash
   # Check USB devices
   lsusb

   # Check serial devices
   dmesg | grep tty

   # Restart udev
   sudo systemctl restart udev
   ```

## Configuration

### Environment Variables

Edit `.env` file or modify `docker-compose.yml`:

```env
# Python Backend
BACKEND_PORT=8081
SERIAL_DEVICE=/dev/ttyUSB0

# Node.js Frontend
FRONTEND_PORT=3000
NODE_ENV=production

# Nginx (if enabled)
NGINX_PORT=80
```

### Serial Device Configuration

```yaml
# In docker-compose.yml
devices:
  - "/dev/ttyUSB0:/dev/ttyUSB0"

# Or for multiple devices
devices:
  - "/dev/ttyUSB0:/dev/ttyUSB0"
  - "/dev/ttyUSB1:/dev/ttyUSB1"
```

## Testing

### 1. Build Test

```bash
./test-build.sh
```

### 2. Service Test

```bash
# Start services
docker compose up -d

# Test backend health
curl http://localhost:8081/health

# Test frontend
curl http://localhost:3000

# Test through nginx (if enabled)
curl http://localhost/api/health
```

### 3. Full Integration Test

```bash
# Start with logs
docker compose up

# In another terminal, test endpoints
curl -X POST http://localhost:8081/kvm/switch -H "Content-Type: application/json" -d '{"port": 1}'
```

## Production Deployment

### 1. With Nginx Reverse Proxy

```bash
# Enable nginx in docker-compose.yml
# Uncomment nginx service section
docker compose up -d
```

### 2. With SSL/TLS

```bash
# Add SSL certificates to nginx/ssl/
# Update nginx.conf for HTTPS
# Restart services
docker compose restart nginx
```

### 3. Resource Limits

```bash
# Monitor resource usage
docker stats kvm-manager

# View container info
docker inspect kvm-manager
```

## Backup & Recovery

### 1. Export Configuration

```bash
# Backup volumes
docker volume ls
docker run --rm -v kvm_data:/data -v $(pwd):/backup alpine tar czf /backup/kvm-backup.tar.gz -C /data .
```

### 2. Update Deployment

```bash
# Pull latest code
git pull

# Rebuild and restart
./deploy.sh
```

## Monitoring

### 1. Health Checks

```bash
# Check container health
docker inspect kvm-manager | grep -A 5 Health

# Service health endpoint
curl http://localhost:8081/health
```

### 2. Logs

```bash
# View all logs
docker compose logs

# View specific service
docker compose logs kvm-manager

# Follow logs in real-time
docker compose logs -f kvm-manager
```

### 3. Resource Usage

```bash
# Container stats
docker stats kvm-manager

# System resources
htop
iotop
```

## Common Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# Restart services
docker compose restart

# View logs
docker compose logs -f

# Enter container
docker exec -it kvm-manager bash

# Update and restart
git pull && ./deploy.sh

# Clean up old images
docker image prune -f

# Complete cleanup
docker compose down --volumes --rmi all
```

## Support

If you encounter issues:

1. Check the logs: `docker compose logs -f kvm-manager`
2. Verify device permissions: `ls -la /dev/ttyUSB0`
3. Test serial connection: `sudo minicom -D /dev/ttyUSB0`
4. Check port availability: `sudo netstat -tlnp | grep -E ':(3000|8081)'`
5. Verify Docker installation: `docker --version && docker compose version`

## File Structure

```
kvm-manager/
├── Dockerfile              # Multi-stage production build
├── Dockerfile.simple       # Simplified single-stage build
├── docker-compose.yml      # Service orchestration
├── docker-entrypoint.sh    # Smart startup script
├── deploy.sh              # Automated deployment
├── debug-build.sh         # Build debugging
├── test-build.sh          # Build testing
├── .dockerignore          # Build optimization
├── nginx.conf             # Reverse proxy config
└── kvm-mgr-app/           # Python backend
    ├── main.py
    ├── pyproject.toml
    └── uv.lock
└── kvm-mgr-ui/            # Node.js frontend
    └── package.json
```
