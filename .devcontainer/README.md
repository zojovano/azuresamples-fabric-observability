# Azure Fabric Observability DevContainer

This DevContainer provides a complete development environment for the Azure Fabric Observability project with all necessary tools pre-installed.

## 🚀 What's Included

### Core Tools
- **Python 3.12** with comprehensive package ecosystem
- **Azure CLI** with Bicep extension
- **Microsoft Fabric CLI** for Fabric management
- **.NET 8.0** for C# development
- **PowerShell** for scripting
- **Node.js LTS** with npm and npx for VS Code MCP Azure
- **Docker** and **Docker Compose**
- **kubectl** and **Helm** for Kubernetes

### Development Environment
- **VS Code Extensions** for Azure, Python, .NET, Docker
- **Git** configuration
- **Jupyter Lab** for notebooks
- **Black** and **Flake8** for Python formatting
- **OpenTelemetry** libraries and tools

## 🏃‍♂️ Getting Started

### Prerequisites
- [VS Code](https://code.visualstudio.com/)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

### Setup
1. **Open in DevContainer**
   ```bash
   # Clone the repository
   git clone https://github.com/zojovano/azuresamples-fabric-observability.git
   cd azuresamples-fabric-observability
   
   # Open in VS Code
   code .
   
   # When prompted, click "Reopen in Container"
   # Or use Command Palette: "Dev Containers: Reopen in Container"
   ```

2. **Initial Configuration**
   ```bash
   # Run the welcome script to see available tools
   ~/workspace/welcome.sh
   
   # Login to Azure
   az login
   
   # Login to Fabric
   fab auth login
   ```

3. **Set up Environment Variables**
   ```bash
   # Copy sample configurations
   cp ~/workspace/.azure-config-sample ~/.azure-config
   cp ~/workspace/.fabric-config-sample ~/.fabric-config
   
   # Edit with your values
   nano ~/.azure-config
   nano ~/.fabric-config
   
   # Source the configurations
   source ~/.azure-config
   source ~/.fabric-config
   ```

## 🛠️ Development Workflow

### Infrastructure Deployment
```bash
# Navigate to Bicep templates
cd infra/Bicep

# Validate templates
az bicep build --file main.bicep

# Deploy infrastructure
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters.json
```

### Local Development
```bash
# The DevContainer provides a complete development environment
# All telemetry will be sent directly to Azure services

# Run Jupyter Lab for analysis
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root

# Access Jupyter at: http://localhost:8888
```

### Python Development
```bash
# Run Jupyter Lab
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root

# Run Python scripts
python app/python-scripts/your-script.py

# Format code
black app/
flake8 app/
```

### .NET Development
```bash
# Build .NET projects
dotnet build OTEL.Observability.sln

# Run worker service
cd app/dotnet-client/OTELWorker
dotnet run
```

## 📁 Directory Structure

```
~/workspace/
├── notebooks/          # Jupyter notebooks for analysis
├── scripts/            # Custom development scripts
├── data/              # Local data files
├── .azure-config      # Azure environment variables
└── .fabric-config     # Fabric environment variables
```

## 🔧 Customization

### Adding Python Packages
```bash
# Install additional packages
pip install your-package

# Or add to requirements.txt and rebuild container
echo "your-package>=1.0.0" >> .devcontainer/requirements.txt
```

### Adding VS Code Extensions
Edit `.devcontainer/devcontainer.json`:
```json
"customizations": {
  "vscode": {
    "extensions": [
      "your.extension.id"
    ]
  }
}
```

### Environment Variables
Add to `.devcontainer/devcontainer.json`:
```json
"containerEnv": {
  "YOUR_VAR": "your-value"
}
```

## 🐛 Troubleshooting

### Container Issues
```bash
# Rebuild container
# Command Palette: "Dev Containers: Rebuild Container"

# Check container logs
docker logs devcontainer

# Access container shell
docker exec -it devcontainer bash
```

### Tool Issues
```bash
# Verify installations
~/workspace/welcome.sh

# Update Azure CLI
az upgrade

# Update Fabric CLI
pip install --upgrade ms-fabric-cli
```

## 📚 Resources

- [Dev Containers Documentation](https://containers.dev/)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Microsoft Fabric CLI Documentation](https://learn.microsoft.com/en-us/rest/api/fabric/articles/fabric-command-line-interface)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
