#!/bin/bash
set -e

echo "Starting KVM Manager Application..."

# Activate Python virtual environment
source /app/.venv/bin/activate

# Function to check if a service is running
check_service() {
    local port=$1
    local service_name=$2
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:$port/health > /dev/null 2>&1; then
            echo "$service_name is ready on port $port"
            return 0
        fi
        echo "Waiting for $service_name to start... (attempt $((attempt + 1))/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "ERROR: $service_name failed to start within $((max_attempts * 2)) seconds"
    return 1
}

# Start Python backend in background
echo "Starting Python FastAPI backend..."
cd /app
python kvm-mgr-service/main.py &
PYTHON_PID=$!

# Wait for Python backend to be ready
sleep 5
if ! check_service 8081 "Python Backend"; then
    echo "Failed to start Python backend"
    exit 1
fi

# Start Node.js Express frontend
echo "Starting Node.js Express frontend..."
cd /app/frontend
node server.js &
NODE_PID=$!

# Wait for Express frontend to be ready
sleep 3
if ! check_service 3000 "Express Frontend"; then
    echo "Failed to start Express frontend"
    exit 1
fi

echo "✅ KVM Manager Application is ready!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔧 Backend API: http://localhost:8081"
echo "📚 API Docs: http://localhost:8081/docs"

# Function to handle shutdown
shutdown() {
    echo "Shutting down services..."
    kill $NODE_PID $PYTHON_PID 2>/dev/null || true
    wait $NODE_PID $PYTHON_PID 2>/dev/null || true
    echo "Services stopped"
    exit 0
}

# Set up signal handlers
trap shutdown SIGTERM SIGINT

# Keep the script running and monitor services
while true; do
    if ! kill -0 $PYTHON_PID 2>/dev/null; then
        echo "Python backend died, restarting..."
        cd /app
        python kvm-mgr-service/main.py &
        PYTHON_PID=$!
    fi
    
    if ! kill -0 $NODE_PID 2>/dev/null; then
        echo "Node.js frontend died, restarting..."
        cd /app/frontend
        node server.js &
        NODE_PID=$!
    fi
    
    sleep 10
done
