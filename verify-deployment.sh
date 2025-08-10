#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 KVM Manager Deployment Verification${NC}"
echo -e "${BLUE}=====================================${NC}"

# Check Docker installation
echo -e "\n${BLUE}📋 Checking Prerequisites...${NC}"

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✅ Docker is installed: $(docker --version)${NC}"
else
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo -e "${YELLOW}💡 Install with: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh${NC}"
    exit 1
fi

if command -v docker compose &> /dev/null || command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✅ Docker Compose is available${NC}"
else
    echo -e "${RED}❌ Docker Compose is not available${NC}"
    echo -e "${YELLOW}💡 Install with: sudo apt install docker-compose-plugin${NC}"
    exit 1
fi

# Check Docker daemon
if docker info &> /dev/null; then
    echo -e "${GREEN}✅ Docker daemon is running${NC}"
else
    echo -e "${RED}❌ Docker daemon is not running${NC}"
    echo -e "${YELLOW}💡 Start with: sudo systemctl start docker${NC}"
    exit 1
fi

# Check serial device
echo -e "\n${BLUE}🔌 Checking Serial Device...${NC}"
if [ -e "/dev/ttyUSB0" ]; then
    echo -e "${GREEN}✅ Serial device /dev/ttyUSB0 exists${NC}"
    ls -la /dev/ttyUSB0
    
    if groups $USER | grep -q dialout; then
        echo -e "${GREEN}✅ User is in dialout group${NC}"
    else
        echo -e "${YELLOW}⚠️  User not in dialout group${NC}"
        echo -e "${YELLOW}💡 Add with: sudo usermod -aG dialout $USER && newgrp dialout${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Serial device /dev/ttyUSB0 not found${NC}"
    echo -e "${YELLOW}💡 Check available devices: ls -la /dev/ttyUSB*${NC}"
fi

# Check ports
echo -e "\n${BLUE}🌐 Checking Port Availability...${NC}"
for port in 3000 8081 80; do
    if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        echo -e "${YELLOW}⚠️  Port $port is already in use${NC}"
        netstat -tuln | grep ":${port} "
    else
        echo -e "${GREEN}✅ Port $port is available${NC}"
    fi
done

# Check required files
echo -e "\n${BLUE}📁 Checking Project Files...${NC}"
required_files=(
    "Dockerfile"
    "Dockerfile.simple"
    "docker-compose.yml"
    "docker-entrypoint.sh"
    "deploy.sh"
    "kvm-mgr-app/main.py"
    "kvm-mgr-app/pyproject.toml"
    "kvm-mgr-ui/package.json"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file exists${NC}"
    else
        echo -e "${RED}❌ $file missing${NC}"
    fi
done

# Check if Docker image exists
echo -e "\n${BLUE}🐳 Checking Docker Image...${NC}"
if docker image inspect kvm-manager:latest &> /dev/null; then
    echo -e "${GREEN}✅ Docker image kvm-manager:latest exists${NC}"
    docker image inspect kvm-manager:latest --format '{{.Created}}' | head -1
else
    echo -e "${YELLOW}⚠️  Docker image kvm-manager:latest not found${NC}"
    echo -e "${YELLOW}💡 Build with: ./deploy.sh or docker build -t kvm-manager .${NC}"
fi

# Check if containers are running
echo -e "\n${BLUE}🏃 Checking Running Containers...${NC}"
if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q kvm-manager; then
    echo -e "${GREEN}✅ KVM Manager containers are running:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep kvm-manager
    
    # Test endpoints
    echo -e "\n${BLUE}🧪 Testing Endpoints...${NC}"
    
    # Test backend health
    if curl -s http://localhost:8081/health &> /dev/null; then
        echo -e "${GREEN}✅ Backend health endpoint responding${NC}"
    else
        echo -e "${YELLOW}⚠️  Backend health endpoint not responding${NC}"
    fi
    
    # Test frontend
    if curl -s http://localhost:3000 &> /dev/null; then
        echo -e "${GREEN}✅ Frontend responding${NC}"
    else
        echo -e "${YELLOW}⚠️  Frontend not responding${NC}"
    fi
    
else
    echo -e "${YELLOW}⚠️  No KVM Manager containers running${NC}"
    echo -e "${YELLOW}💡 Start with: docker compose up -d${NC}"
fi

echo -e "\n${BLUE}📊 Summary${NC}"
echo -e "${BLUE}==========${NC}"
echo -e "Prerequisites: Docker and Docker Compose installed"
echo -e "Serial Device: Check /dev/ttyUSB0 and dialout group membership"
echo -e "Network Ports: Ensure 3000, 8081, and 80 are available"
echo -e "Project Files: All required files should be present"
echo -e "Deployment: Run ./deploy.sh to build and start services"
echo -e "Testing: Use curl to test endpoints after deployment"

echo -e "\n${GREEN}🚀 Ready to deploy! Run ./deploy.sh to start.${NC}"
