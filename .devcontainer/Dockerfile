FROM mcr.microsoft.com/devcontainers/python:3.12-bullseye

# Install additional system dependencies
RUN apt-get update && apt-get install -y \
    # Build tools
    build-essential \
    cmake \
    pkg-config \
    # Network tools
    curl \
    wget \
    netcat \
    # Text processing
    jq \
    yq \
    # Archive tools
    unzip \
    zip \
    # Development tools
    git \
    vim \
    nano \
    htop \
    tree \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (useful for some Azure tools)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs

# Set up Python environment
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Create workspace directories
RUN mkdir -p /workspace/notebooks /workspace/scripts /workspace/data

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
