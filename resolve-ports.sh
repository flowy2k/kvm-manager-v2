#!/bin/bash

# Port Conflict Resolution Script for KVM Manager

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 KVM Manager Port Conflict Resolver${NC}"
echo -e "${BLUE}====================================${NC}"

# Function to check if port is in use
check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
        return 0 # Port is in use
    else
        return 1 # Port is free
    fi
}

# Function to find what's using a port
find_port_user() {
    local port=$1
    echo -e "${YELLOW}Port $port is in use by:${NC}"
    
    # Try different methods to find the process
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :$port 2>/dev/null
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tlnp 2>/dev/null | grep ":$port "
    elif command -v ss >/dev/null 2>&1; then
        ss -tlnp | grep ":$port "
    fi
    
    # Check for Docker containers using the port
    echo -e "\n${YELLOW}Docker containers using port $port:${NC}"
    docker ps --format "table {{.Names}}\t{{.Ports}}" | grep ":$port"
    echo
}

# Function to suggest alternative ports
suggest_ports() {
    local base_port=$1
    local service_name=$2
    
    echo -e "${BLUE}Suggested alternative ports for $service_name:${NC}"
    
    for i in {1..10}; do
        local test_port=$((base_port + i))
        if ! check_port $test_port; then
            echo -e "${GREEN}✅ Port $test_port is available${NC}"
            return $test_port
        fi
    done
    
    echo -e "${YELLOW}⚠️  No nearby ports available, try custom ports${NC}"
    return 1
}

# Function to stop conflicting Docker containers
stop_docker_conflicts() {
    echo -e "${YELLOW}🛑 Stopping Docker containers that might conflict...${NC}"
    
    # Stop containers using our ports
    docker ps --format "{{.Names}}" | while read container; do
        if docker port "$container" 2>/dev/null | grep -E "(3000|8081|8081)" >/dev/null; then
            echo -e "Stopping container: $container"
            docker stop "$container" 2>/dev/null
        fi
    done
}

# Main resolution process
echo -e "\n${BLUE}📊 Checking Current Port Usage...${NC}"

# Check default ports
ports_to_check=(3000 8081 8081)
conflicts_found=false

for port in "${ports_to_check[@]}"; do
    if check_port $port; then
        echo -e "${RED}❌ Port $port is in use${NC}"
        find_port_user $port
        conflicts_found=true
    else
        echo -e "${GREEN}✅ Port $port is available${NC}"
    fi
done

if [ "$conflicts_found" = true ]; then
    echo -e "\n${YELLOW}🔧 Port Conflict Resolution Options:${NC}"
    echo
    echo "1. 🛑 Stop conflicting Docker containers"
    echo "2. 🔄 Use alternative ports"
    echo "3. ⚙️  Configure custom ports"
    echo "4. 📋 Show detailed conflict info"
    echo "5. 🚀 Deploy with auto port selection"
    echo
    
    read -p "Choose an option (1-5): " choice
    
    case $choice in
        1)
            stop_docker_conflicts
            echo -e "${GREEN}✅ Stopped conflicting containers. Try deploying again.${NC}"
            ;;
        2)
            echo -e "\n${BLUE}🔄 Alternative Port Configuration:${NC}"
            suggest_ports 3000 "Frontend"
            frontend_port=$?
            suggest_ports 8081 "Backend"
            backend_port=$?
            
            if [ $frontend_port -ne 1 ] && [ $backend_port -ne 1 ]; then
                echo -e "\n${GREEN}✅ Creating .env with alternative ports:${NC}"
                cat > .env << EOF
# KVM Manager Port Configuration (Auto-generated)
KVM_FRONTEND_PORT=$frontend_port
KVM_BACKEND_PORT=$backend_port

# Application Environment
NODE_ENV=production
PYTHONPATH=/app/backend
UV_CACHE_DIR=/app/.uv-cache

# Serial Device Configuration
SERIAL_DEVICE=/dev/ttyUSB0
ADDITIONAL_SERIAL_DEVICE=/dev/ttyUSB1

# KVM Port Friendly Names Configuration
KVM_PORT_1_NAME=Web-Server
KVM_PORT_2_NAME=Database-Server
KVM_PORT_3_NAME=Application-Server
KVM_PORT_4_NAME=Development-Machine
KVM_PORT_5_NAME=Testing-Server
KVM_PORT_6_NAME=Backup-Server
KVM_PORT_7_NAME=Monitoring-Server
KVM_PORT_8_NAME=File-Server
KVM_PORT_9_NAME=Mail-Server
KVM_PORT_10_NAME=DNS-Server
KVM_PORT_11_NAME=DHCP-Server
KVM_PORT_12_NAME=Firewall
KVM_PORT_13_NAME=Router
KVM_PORT_14_NAME=Switch
KVM_PORT_15_NAME=Workstation-1
KVM_PORT_16_NAME=Workstation-2

# Additional KVM Configuration
KVM_MAX_PORTS=16
KVM_AUTO_SWITCH_ENABLED=false
KVM_AUTO_SWITCH_TIMEOUT=30
EOF
                echo -e "Frontend will use port: ${GREEN}$frontend_port${NC}"
                echo -e "Backend will use port: ${GREEN}$backend_port${NC}"
                echo -e "\n${GREEN}🚀 Ready to deploy! Run: ./deploy.sh${NC}"
            fi
            ;;
        3)
            echo -e "\n${BLUE}⚙️  Custom Port Configuration:${NC}"
            read -p "Enter frontend port (default 3000): " custom_frontend
            read -p "Enter backend port (default 8081): " custom_backend
            
            custom_frontend=${custom_frontend:-3000}
            custom_backend=${custom_backend:-8081}
            
            cat > .env << EOF
# KVM Manager Port Configuration (Custom)
KVM_FRONTEND_PORT=$custom_frontend
KVM_BACKEND_PORT=$custom_backend

# Application Environment
NODE_ENV=production
PYTHONPATH=/app/backend
UV_CACHE_DIR=/app/.uv-cache

# Serial Device Configuration
SERIAL_DEVICE=/dev/ttyUSB0
ADDITIONAL_SERIAL_DEVICE=/dev/ttyUSB1

# KVM Port Friendly Names Configuration
KVM_PORT_1_NAME=Web-Server
KVM_PORT_2_NAME=Database-Server
KVM_PORT_3_NAME=Application-Server
KVM_PORT_4_NAME=Development-Machine
KVM_PORT_5_NAME=Testing-Server
KVM_PORT_6_NAME=Backup-Server
KVM_PORT_7_NAME=Monitoring-Server
KVM_PORT_8_NAME=File-Server
KVM_PORT_9_NAME=Mail-Server
KVM_PORT_10_NAME=DNS-Server
KVM_PORT_11_NAME=DHCP-Server
KVM_PORT_12_NAME=Firewall
KVM_PORT_13_NAME=Router
KVM_PORT_14_NAME=Switch
KVM_PORT_15_NAME=Workstation-1
KVM_PORT_16_NAME=Workstation-2

# Additional KVM Configuration
KVM_MAX_PORTS=16
KVM_AUTO_SWITCH_ENABLED=false
KVM_AUTO_SWITCH_TIMEOUT=30
EOF
            echo -e "${GREEN}✅ Custom configuration saved to .env${NC}"
            echo -e "Frontend will use port: ${GREEN}$custom_frontend${NC}"
            echo -e "Backend will use port: ${GREEN}$custom_backend${NC}"
            ;;
        4)
            echo -e "\n${BLUE}📋 Detailed Port Conflict Information:${NC}"
            for port in "${ports_to_check[@]}"; do
                if check_port $port; then
                    find_port_user $port
                fi
            done
            ;;
        5)
            echo -e "\n${BLUE}🚀 Auto Port Selection Deployment:${NC}"
            
            # Find available ports automatically
            auto_frontend=3000
            auto_backend=8081
            
            while check_port $auto_frontend; do
                auto_frontend=$((auto_frontend + 1))
            done
            
            while check_port $auto_backend; do
                auto_backend=$((auto_backend + 1))
            done
            
            echo -e "Auto-selected ports:"
            echo -e "Frontend: ${GREEN}$auto_frontend${NC}"
            echo -e "Backend: ${GREEN}$auto_backend${NC}"
            
            export KVM_FRONTEND_PORT=$auto_frontend
            export KVM_BACKEND_PORT=$auto_backend
            
            echo -e "\n${GREEN}🚀 Starting deployment with auto-selected ports...${NC}"
            ./deploy.sh
            ;;
        *)
            echo -e "${YELLOW}Invalid option. Please run the script again.${NC}"
            ;;
    esac
else
    echo -e "\n${GREEN}🎉 No port conflicts detected! Ready to deploy.${NC}"
    echo -e "${GREEN}🚀 Run: ./deploy.sh${NC}"
fi
