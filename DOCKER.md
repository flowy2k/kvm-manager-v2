# KVM Manager Docker Deployment Guide

This guide covers deploying the KVM Manager application using Docker containers for production environments.

## 🏗️ Architecture Overview

The Docker deployment includes:

- **Multi-stage Docker build** for optimized production images
- **Node.js Express frontend** (Port 3000)
- **Python FastAPI backend** (Port 8081)
- **Serial device access** for KVM hardware communication
- **Optional Nginx reverse proxy** for production
- **Health checks** and automatic restart capabilities

## 📋 Prerequisites

### System Requirements

- **Docker** 20.10+ and **Docker Compose** 2.0+
- **Linux host** with USB-to-Serial device support
- **Minimum 1GB RAM** and **2GB disk space**
- **USB-to-Serial adapter** connected to KVM switch

### Hardware Setup

1. Connect USB-to-Serial adapter to host system
2. Verify device appears as `/dev/ttyUSB0` (or similar)
3. Ensure user has access to serial devices:
   ```bash
   sudo usermod -a -G dialout $USER
   # Log out and back in for changes to take effect
   ```

## 🚀 Quick Start

### 1. Automated Deployment

Use the provided deployment script for the easiest setup:

```bash
# Clone and navigate to project
cd /workspaces/kvm-manager

# Make script executable (if not already)
chmod +x deploy.sh

# Deploy with latest version
./deploy.sh

# Or deploy with specific version
./deploy.sh v1.0.0
```

### 2. Manual Docker Commands

#### Build the Image

```bash
# Build the Docker image
docker build -t kvm-manager:latest .

# View built image
docker images kvm-manager
```

#### Run the Container

```bash
# Run with basic configuration
docker run -d \
  --name kvm-manager \
  -p 3000:3000 \
  -p 8081:8081 \
  --device /dev/ttyUSB0:/dev/ttyUSB0 \
  --privileged \
  -v /dev:/dev \
  --restart unless-stopped \
  kvm-manager:latest
```

### 3. Docker Compose (Recommended)

```bash
# Start all services
docker-compose up -d

# View running services
docker-compose ps

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

## 🔧 Configuration Options

### Environment Variables

| Variable       | Default          | Description         |
| -------------- | ---------------- | ------------------- |
| `NODE_ENV`     | `production`     | Node.js environment |
| `PYTHONPATH`   | `/app/backend`   | Python module path  |
| `UV_CACHE_DIR` | `/app/.uv-cache` | UV package cache    |

### Port Mapping

| Container Port | Host Port | Service                |
| -------------- | --------- | ---------------------- |
| 3000           | 3000      | Express Frontend       |
| 8081           | 8081      | Python Backend API     |
| 80             | 80        | Nginx (optional)       |
| 443            | 443       | Nginx HTTPS (optional) |

### Device Access

The container requires access to serial devices:

```yaml
# In docker-compose.yml
devices:
  - "/dev/ttyUSB0:/dev/ttyUSB0"
  - "/dev/ttyUSB1:/dev/ttyUSB1" # Additional ports if needed

# Alternative: Mount entire /dev directory
volumes:
  - /dev:/dev
```

## 🔒 Production Configuration

### With Nginx Reverse Proxy

1. **Enable the Nginx service:**

   ```bash
   docker-compose --profile production up -d
   ```

2. **Configure SSL certificates** (optional):

   ```bash
   # Create SSL directory
   mkdir -p ssl

   # Copy your certificates
   cp your-cert.pem ssl/cert.pem
   cp your-key.pem ssl/key.pem

   # Update nginx.conf to enable HTTPS
   ```

3. **Access via Nginx:**
   - HTTP: `http://your-host`
   - HTTPS: `https://your-host` (if configured)

### Resource Limits

Add resource constraints for production:

```yaml
# In docker-compose.yml
services:
  kvm-manager:
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 1G
        reservations:
          cpus: "0.5"
          memory: 512M
```

## 📊 Monitoring and Health Checks

### Health Check Endpoints

- **Frontend Health:** `http://localhost:3000/health`
- **Backend Health:** `http://localhost:8081/health`
- **Nginx Health:** `http://localhost/nginx-health`

### Built-in Monitoring

The container includes automatic health checks:

```bash
# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}"

# View health check logs
docker inspect kvm-manager | grep -A 10 Health
```

### Log Monitoring

```bash
# View real-time logs
docker logs kvm-manager -f

# With Docker Compose
docker-compose logs -f

# View specific service logs
docker-compose logs kvm-manager -f
```

## 🛠️ Management Commands

### Container Management

```bash
# View running containers
docker ps

# Start/stop container
docker start kvm-manager
docker stop kvm-manager
docker restart kvm-manager

# Remove container
docker rm kvm-manager

# Update to new version
docker pull kvm-manager:latest
docker stop kvm-manager
docker rm kvm-manager
./deploy.sh
```

### Docker Compose Management

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart specific service
docker-compose restart kvm-manager

# View service status
docker-compose ps

# Scale services (if needed)
docker-compose up -d --scale kvm-manager=2
```

### Data Management

```bash
# Backup persistent data
docker run --rm -v kvm-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/kvm-backup-$(date +%Y%m%d).tar.gz -C /data .

# Restore data
docker run --rm -v kvm-data:/data -v $(pwd):/backup alpine \
  tar xzf /backup/kvm-backup-YYYYMMDD.tar.gz -C /data

# View data volume
docker volume inspect kvm-data
```

## 🔍 Troubleshooting

### Common Issues

#### Serial Device Not Found

```bash
# Check if device exists
ls -la /dev/ttyUSB*

# Check container has access
docker exec kvm-manager ls -la /dev/ttyUSB*

# Fix permissions
sudo chmod 666 /dev/ttyUSB0
```

#### Container Won't Start

```bash
# Check Docker logs
docker logs kvm-manager

# Check for port conflicts
sudo netstat -tlnp | grep :3000
sudo netstat -tlnp | grep :8081

# Check if image built correctly
docker images kvm-manager
```

#### Service Health Check Failing

```bash
# Test endpoints manually
curl http://localhost:3000/health
curl http://localhost:8081/health

# Check internal networking
docker exec kvm-manager curl http://localhost:3000/health
docker exec kvm-manager curl http://localhost:8081/health
```

### Debug Mode

Run container with debug output:

```bash
docker run -it --rm \
  --device /dev/ttyUSB0:/dev/ttyUSB0 \
  --privileged \
  -v /dev:/dev \
  -p 3000:3000 \
  -p 8081:8081 \
  kvm-manager:latest
```

### Performance Issues

```bash
# Check resource usage
docker stats kvm-manager

# Check system resources
docker system df
docker system prune  # Clean up unused resources
```

## 🔄 Updates and Maintenance

### Updating the Application

1. **Pull latest code:**

   ```bash
   git pull origin main
   ```

2. **Rebuild and deploy:**

   ```bash
   ./deploy.sh
   ```

3. **Zero-downtime updates with compose:**
   ```bash
   docker-compose up -d --no-deps --build kvm-manager
   ```

### Regular Maintenance

```bash
# Clean up old images
docker image prune -f

# Clean up stopped containers
docker container prune -f

# Clean up unused volumes
docker volume prune -f

# Complete system cleanup
docker system prune -a -f
```

### Backup Strategy

1. **Application data:**

   ```bash
   docker run --rm -v kvm-data:/data alpine tar czf - -C /data . > backup.tar.gz
   ```

2. **Configuration files:**

   ```bash
   tar czf config-backup.tar.gz docker-compose.yml nginx.conf
   ```

3. **Container images:**
   ```bash
   docker save kvm-manager:latest | gzip > kvm-manager-image.tar.gz
   ```

## 🚦 Production Checklist

- [ ] SSL certificates configured (if using HTTPS)
- [ ] Firewall rules configured for ports 80/443
- [ ] Regular backup strategy implemented
- [ ] Log rotation configured
- [ ] Resource limits set appropriately
- [ ] Health check monitoring implemented
- [ ] Update strategy documented
- [ ] Disaster recovery plan in place

## 📞 Support

For deployment issues:

1. **Check logs:** `docker logs kvm-manager -f`
2. **Verify health:** `curl http://localhost:3000/health`
3. **Test hardware:** Check `/dev/ttyUSB*` access
4. **Review configuration:** Ensure ports and devices are mapped correctly

---

**Docker Deployment Version:** 1.0.0  
**Last Updated:** August 2025  
**Compatibility:** Docker 20.10+, Docker Compose 2.0+
