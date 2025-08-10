#!/bin/bash

# KVM Manager Application Startup Script
# This script starts the complete KVM management system

set -e

echo "🚀 Starting KVM Manager Application"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Check prerequisites
print_header "Checking Prerequisites..."

# Check Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 16+ first."
    exit 1
fi
print_status "Node.js version: $(node --version)"

# Check npm
if ! command -v npm &> /dev/null; then
    print_error "npm is not installed. Please install npm first."
    exit 1
fi
print_status "npm version: $(npm --version)"

# Check Python
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install Python 3.11+ first."
    exit 1
fi
print_status "Python version: $(python3 --version)"

# Check uv
if ! command -v uv &> /dev/null; then
    print_warning "uv package manager not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.cargo/env
fi
print_status "uv version: $(uv --version)"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_header "Project Structure:"
print_status "Script location: $SCRIPT_DIR"
print_status "Project root: $PROJECT_ROOT"

# Install Node.js dependencies
print_header "Installing Node.js Dependencies..."
cd "$SCRIPT_DIR"
if [ ! -d "node_modules" ]; then
    print_status "Installing npm packages..."
    npm install
else
    print_status "Node.js dependencies already installed"
fi

# Install Python dependencies
print_header "Installing Python Dependencies..."
cd "$PROJECT_ROOT/kvm-mgr-service"
print_status "Syncing Python packages with uv..."
uv sync

# Check for serial ports
print_header "Checking Serial Ports..."
if ls /dev/ttyUSB* &> /dev/null; then
    print_status "Serial ports found:"
    ls -la /dev/ttyUSB* | while read line; do
        print_status "  $line"
    done
else
    print_warning "No /dev/ttyUSB* devices found"
    print_warning "Make sure your USB-to-Serial adapter is connected"
fi

# Start the application
print_header "Starting KVM Manager Application..."
cd "$SCRIPT_DIR"

print_status "Starting Express server (will auto-launch Python backend)..."
print_status "Frontend will be available at: http://localhost:3000"
print_status "API documentation at: http://localhost:8081/docs"
print_status ""
print_status "Press Ctrl+C to stop all services"
print_status ""

# Start the Express server (which will start Python backend automatically)
exec npm start
