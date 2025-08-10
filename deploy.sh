#!/bin/bash
# Build and deployment script for KVM Manager Application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="kvm-manager"
CONTAINER_NAME="kvm-manager"
VERSION=${1:-latest}
DOCKERFILE=${DOCKERFILE:-Dockerfile}

echo -e "${BLUE}🏗️  KVM Manager Docker Deployment Script${NC}"
echo -e "${BLUE}=======================================${NC}"

# Function to print colored messages
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if Docker is installed and running
check_docker() {
    print_info "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    print_status "Docker is ready"
}

# Check if Docker Compose is available
check_docker_compose() {
    print_info "Checking Docker Compose..."
    
    # Check for new docker compose command first
    if docker compose version &> /dev/null; then
        print_status "Docker Compose (v2) is available"
        USE_COMPOSE=true
        COMPOSE_CMD="docker compose"
    # Check for legacy docker-compose command
    elif command -v docker-compose &> /dev/null; then
        print_status "Docker Compose (legacy) is available"
        USE_COMPOSE=true
        COMPOSE_CMD="docker-compose"
    else
        print_warning "Docker Compose not found. Will use Docker only."
        USE_COMPOSE=false
        COMPOSE_CMD=""
    fi
}

# Build the Docker image
build_image() {
    echo -e "${BLUE}🏗️  Building Docker image...${NC}"
    echo "Using Dockerfile: $DOCKERFILE"
    
    if ! docker build -f "$DOCKERFILE" -t "$IMAGE_NAME:$VERSION" .; then
        echo -e "${RED}❌ Docker build failed!${NC}"
        
        if [[ "$DOCKERFILE" == "Dockerfile" ]]; then
            echo -e "${YELLOW}💡 Trying simplified build approach...${NC}"
            if docker build -f "Dockerfile.simple" -t "$IMAGE_NAME:$VERSION" .; then
                echo -e "${GREEN}✅ Build successful with simplified Dockerfile!${NC}"
                return 0
            else
                echo -e "${RED}❌ Both Dockerfiles failed. Check the error messages above.${NC}"
                exit 1
            fi
        else
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✅ Docker image built successfully!${NC}"
}

# Stop and remove existing container
cleanup_container() {
    print_info "Cleaning up existing container..."
    
    if docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
        print_info "Stopping running container..."
        docker stop ${CONTAINER_NAME}
    fi
    
    if docker ps -aq -f name=${CONTAINER_NAME} | grep -q .; then
        print_info "Removing existing container..."
        docker rm ${CONTAINER_NAME}
    fi
    
    print_status "Cleanup completed"
}

# Run with Docker Compose
run_with_compose() {
    print_info "Starting application with Docker Compose..."
    
    # Stop existing services
    $COMPOSE_CMD down 2>/dev/null || true
    
    # Start services
    $COMPOSE_CMD up -d
    
    print_status "Application started with Docker Compose"
    print_info "Services:"
    $COMPOSE_CMD ps
}

# Run with Docker only
run_with_docker() {
    print_info "Starting application with Docker..."
    
    cleanup_container
    
    # Get port configuration from environment or use defaults
    FRONTEND_PORT=${KVM_FRONTEND_PORT:-3000}
    BACKEND_PORT=${KVM_BACKEND_PORT:-8081}
    API_HOSTNAME=${API_HOSTNAME:-"http://localhost:${BACKEND_PORT}/api"}
    KVM_UI_URL=${KVM_UI_URL:-}
    
    # Run the container
    docker run -d \
        --name ${CONTAINER_NAME} \
        -p ${FRONTEND_PORT}:3000 \
        -p ${BACKEND_PORT}:8080 \
        -e "API_HOSTNAME=${API_HOSTNAME}" \
        -e "KVM_UI_URL=${KVM_UI_URL}" \
        -e "KVM_API_URL=${API_HOSTNAME}" \
        -e "KVM_WEB_UI_URL=${KVM_UI_URL}" \
        --device /dev/ttyUSB0:/dev/ttyUSB0 \
        --privileged \
        -v /dev:/dev \
        --restart unless-stopped \
        ${IMAGE_NAME}:${VERSION}
    
    print_status "Application started with Docker"
    print_info "Frontend: http://localhost:${FRONTEND_PORT}"
    print_info "Backend API: http://localhost:${BACKEND_PORT}"
}

# Wait for application to be ready
wait_for_app() {
    print_info "Waiting for application to be ready..."
    
    local max_attempts=30
    local attempt=0
    local frontend_port=${KVM_FRONTEND_PORT:-3000}
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:${frontend_port}/health > /dev/null 2>&1 || curl -s http://localhost:${frontend_port} > /dev/null 2>&1; then
            print_status "Application is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "Application failed to start within $((max_attempts * 2)) seconds"
    return 1
}

# Show application information
show_info() {
    echo
    print_status "🎉 KVM Manager Application Deployed Successfully!"
    echo
    
    # Get port configuration
    FRONTEND_PORT=${KVM_FRONTEND_PORT:-3000}
    BACKEND_PORT=${KVM_BACKEND_PORT:-8081}
    
    print_info "Access Information:"
    echo -e "  🌐 Web Interface:  ${GREEN}http://localhost:${FRONTEND_PORT}${NC}"
    echo -e "  🔧 API Backend:    ${GREEN}http://localhost:${BACKEND_PORT}${NC}"
    echo -e "  📚 API Docs:       ${GREEN}http://localhost:${BACKEND_PORT}/docs${NC}"
    echo
    print_info "Container Information:"
    
    if [ "$USE_COMPOSE" = true ]; then
        echo -e "  📦 Docker Compose services:"
        $COMPOSE_CMD ps
    else
        echo -e "  📦 Container: ${GREEN}${CONTAINER_NAME}${NC}"
        docker ps --filter name=${CONTAINER_NAME} --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
    
    echo
    print_info "Management Commands:"
    echo "  📊 View logs:     docker logs ${CONTAINER_NAME} -f"
    echo "  🔄 Restart:       docker restart ${CONTAINER_NAME}"
    echo "  🛑 Stop:          docker stop ${CONTAINER_NAME}"
    
    if [ "$USE_COMPOSE" = true ]; then
        echo "  🐙 Compose logs:  $COMPOSE_CMD logs -f"
        echo "  🔄 Compose restart: $COMPOSE_CMD restart"
        echo "  🛑 Compose stop:  $COMPOSE_CMD down"
    fi
    
    echo
    print_info "Serial Device Access:"
    echo "  Make sure your USB-to-Serial adapter is connected to /dev/ttyUSB0"
    echo "  The container runs with privileged access for device communication"
    echo
}

# Main deployment function
main() {
    echo "Starting deployment process..."
    
    # Check prerequisites
    check_docker
    check_docker_compose
    
    # Build the image
    build_image
    
    # Deploy the application
    if [ "$USE_COMPOSE" = true ]; then
        run_with_compose
    else
        run_with_docker
    fi
    
    # Wait for application to be ready
    wait_for_app
    
    # Show information
    show_info
}

# Help function
show_help() {
    echo "KVM Manager Docker Deployment Script"
    echo
    echo "Usage: $0 [VERSION]"
    echo
    echo "Options:"
    echo "  VERSION    Docker image version tag (default: latest)"
    echo
    echo "Examples:"
    echo "  $0           # Deploy with 'latest' tag"
    echo "  $0 v1.0.0    # Deploy with 'v1.0.0' tag"
    echo
    echo "Environment Variables:"
    echo "  KVM_PORT_3000    Host port for web interface (default: 3000)"
    echo "  KVM_PORT_8081    Host port for API backend (default: 8081)"
    echo
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main
        ;;
esac
