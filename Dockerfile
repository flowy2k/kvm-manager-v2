# Multi-stage Docker build for KVM Manager Application
# This creates a production-ready container with both Python backend and Node.js frontend

FROM node:18-alpine as frontend-builder

# Set working directory for frontend build
WORKDIR /app/frontend

# Copy frontend package files
COPY kvm-mgr-ui/package*.json ./

# Install Node.js dependencies
RUN npm ci --only=production

# Copy frontend source code
COPY kvm-mgr-ui/ ./

# Build production assets (if needed)
RUN npm run build || true

# Python backend stage
FROM python:3.11-slim as backend-builder

# Install system dependencies for serial communication
RUN apt-get update && apt-get install -y \
    gcc \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory for the entire project
WORKDIR /app

# Install uv for Python package management
RUN pip install uv

# Copy Python project files to root
COPY pyproject.toml uv.lock ./

# Create virtual environment and install dependencies
RUN uv venv .venv && \
    uv sync --frozen

# Copy the Python source code
COPY kvm-mgr-service/ ./kvm-mgr-service/

# Final production image
FROM python:3.11-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    udev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js for the Express server
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Create app user for security
RUN useradd -m -s /bin/bash appuser && \
    usermod -a -G dialout appuser

# Set working directory
WORKDIR /app

# Copy Python project and dependencies from builder
COPY --from=backend-builder /app /app

# Copy frontend from builder
COPY --from=frontend-builder /app/frontend /app/frontend

# Install uv for the runtime user
RUN pip install uv

# Set ownership
RUN chown -R appuser:appuser /app

# Switch to app user
USER appuser

# Add local bins to PATH
ENV PATH="/home/appuser/.local/bin:$PATH"

# Expose ports
EXPOSE 3000 8081

# Create startup script
COPY --chown=appuser:appuser docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Set entrypoint
ENTRYPOINT ["/app/docker-entrypoint.sh"]
