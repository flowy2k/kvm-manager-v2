FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install dependencies as root
USER root
RUN apt-get update && apt-get install -y \
    curl git build-essential python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Switch to vscode user for installs
USER vscode
WORKDIR /home/vscode

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Node.js via nvm
ENV NVM_DIR=/home/vscode/.nvm
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install 20 && \
    nvm alias default 20 && \
    npm install -g npm@latest

# Add nvm and uv to PATH
ENV PATH="$NVM_DIR/versions/node/v20.0.0/bin:/home/vscode/.local/bin:$PATH"

WORKDIR /workspace