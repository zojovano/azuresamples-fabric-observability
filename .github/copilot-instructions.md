# Copilot Instructions for Azure Fabric OTEL Observability

## Architecture Overview

This is an **OTEL Gateway deployment pattern** connecting Azure services → Azure Event Hub → OTEL Collector (Azure Container Instance) → Microsoft Fabric Real-Time Intelligence. The data flow is:

```
Azure Resources → Azure Event Hub → OTEL Collector Container → Microsoft Fabric (KQL Database) → Three OTEL tables
```

**Critical Components:**
- **Microsoft Fabric**: KQL database with three tables: `OTELLogs`, `OTELMetrics`, `OTELTraces`
- **OTEL Collector**: Containerized `otel/opentelemetry-collector-contrib` with Azure Event Hub receiver
- **Bicep Infrastructure**: Azure Verified Modules deployment for capacity, Event Hub, container instances
- **Fabric CLI**: PowerShell-based deployment automation using `fab` commands

## Development Workflows

### PowerShell-Only Architecture
This project **exclusively uses PowerShell scripts** - all Bash equivalents were removed. Key commands:

```powershell
# Full infrastructure deployment
cd infra/Bicep && .\deploy.ps1

# Fabric artifacts deployment (requires Fabric CLI)
.\infra\Deploy-FabricArtifacts.ps1

# Comprehensive testing
.\tests\Test-FabricIntegration.ps1
```

### Fabric CLI Authentication Pattern
```powershell
# Service principal (CI/CD)
fab auth login --service-principal --client-id $clientId --client-secret $clientSecret --tenant-id $tenantId

# Interactive (local dev)
fab auth login
fab auth whoami  # Always verify
```

### KQL Table Deployment Pattern
Tables use `.create-merge` commands for idempotency. Schema example from `infra/kql-definitions/tables/otel-logs.kql`:
```kql
.create-merge table OTELLogs (
    Timestamp:datetime, 
    ObservedTimestamp:datetime, 
    TraceID:string, 
    SpanID:string, 
    SeverityText:string, 
    SeverityNumber:int, 
    Body:string, 
    ResourceAttributes:dynamic, 
    LogsAttributes:dynamic
)
```

## Project-Specific Conventions

### Default Environment Variables
```powershell
$env:FABRIC_WORKSPACE_NAME = "fabric-otel-workspace"
$env:FABRIC_DATABASE_NAME = "otelobservabilitydb" 
$env:RESOURCE_GROUP_NAME = "azuresamples-platformobservabilty-fabric"
$env:LOCATION = "swedencentral"
```

### Error Handling Pattern
PowerShell scripts use color-coded output functions:
```powershell
Write-ColorOutput "Success message" $ColorSuccess "✅"
Write-ColorOutput "Warning message" $ColorWarning "⚠️"
Write-ColorOutput "Error message" $ColorError "❌"
```

### Test Data Generation
The project includes sophisticated OTEL data generators in `tests/FabricObservability.IntegrationTests/Models/OtelModels.cs` with realistic service names, operations, and telemetry patterns.

## Development Environment

### DevContainer Requirements
This project **exclusively runs within a DevContainer environment** on Linux. All commands, scripts, and tools are designed for Linux execution within the containerized development environment.

**Critical Environment Checks:**
- ✅ **Always verify DevContainer connection** before executing any commands
- ✅ **All terminal commands are Linux-based** (bash, not Windows CMD/PowerShell)
- ✅ **File paths use Linux conventions** (`/workspaces/azuresamples-fabric-observability/`)
- ✅ **PowerShell scripts run via `pwsh` (PowerShell Core)** not Windows PowerShell

**Environment Validation Commands:**
```bash
# Verify DevContainer connection
echo $PWD  # Should show /workspaces/azuresamples-fabric-observability
uname -a   # Should show Linux kernel information

# Verify required tools are available
az version      # Azure CLI
pwsh --version  # PowerShell Core
dotnet --version # .NET SDK
```

**Important Notes:**
- All file operations use Linux file system conventions
- PowerShell scripts are executed via `pwsh` command, not native Windows PowerShell
- Git operations use Linux git client within the container
- Azure CLI commands run in Linux environment with proper authentication context

## Integration Points

### OTEL Collector Configuration
`app/otel-eh-receiver/config.yaml` defines the gateway pipeline:
- **Receivers**: `otlp` (gRPC 4317) + `azureeventhub`
- **Processors**: `batch`
- **Exporters**: `debug` + `azuredataexplorer`

### GitHub Actions Integration
`ci-cd-pipeline.yml` orchestrates:
1. Unit tests (.NET xUnit)
2. Infrastructure deployment (Bicep)
3. Fabric artifacts deployment (PowerShell + Fabric CLI)
4. Integration testing (PowerShell + JUnit XML)

Key workflow pattern: Uses `shell: pwsh` for all PowerShell execution.

### Bicep Module Structure
Infrastructure uses Azure Verified Modules pattern:
- `main.bicep` - Subscription-scoped orchestration
- `modules/fabriccapacity.bicep` - F2 SKU Fabric capacity
- `modules/eventhub.bicep` - Standard tier Event Hub
- `modules/containerinstance.bicep` - OTEL Collector container
- `modules/kqldatabase.bicep` - Fabric workspace and database parameters

## Critical File Locations

**Deployment Scripts**: `infra/Deploy-FabricArtifacts.ps1` (main), `infra/Install-FabricCLI.ps1`
**KQL Definitions**: `infra/kql-definitions/tables/*.kql` (three files for logs/metrics/traces)
**Test Suite**: `tests/Test-FabricIntegration.ps1` (PowerShell), `tests/FabricObservability.IntegrationTests/` (.NET)
**OTEL Config**: `app/otel-eh-receiver/config.yaml` (collector pipeline)
**Sample App**: `app/dotnet-client/OTELWorker/` (.NET worker with OTEL instrumentation)

## Debugging Commands

```powershell
# Fabric connectivity
fab auth whoami
fab workspace list --output table
fab kqldatabase list --output table

# Azure resources
az resource list --resource-group $resourceGroupName --resource-type "Microsoft.Fabric/capacities"

# OTEL data verification in Fabric portal
# Navigate to: fabric.microsoft.com → workspace → database → run KQL:
# OTELLogs | count
# OTELMetrics | count  
# OTELTraces | count
```

## Git Workflow Requirements

**IMPORTANT**: After making any code changes, always automatically commit and push but ask the user to confirm:

```bash
# Stage all changes
git add -A

# Commit with descriptive message explaining what was changed
git commit -m "Brief description of changes made"

# Push to remote repository
git push origin main
```

This ensures all changes are immediately saved and available to the team. Write meaningful commit messages that describe the specific changes made (e.g., "Update OTEL collector config for improved error handling" or "Add validation for Fabric workspace creation").

## Development Best Practices & Context Management

### **DevContainer-First Approach**
- **All required libraries and tools** must be configured in DevContainer setup, not installed via separate scripts
- **Never create install scripts** - if tools are missing, update `.devcontainer/devcontainer.json` or `.devcontainer/post-create.sh` instead
- **Fabric CLI, Azure CLI, PowerShell, .NET, Git** are pre-installed via DevContainer configuration
- **Installation scripts are anti-pattern** - they violate the DevContainer-only approach

### **Git Repository Status Validation**
- **Always check current git status** before making assumptions about file structure
- **Deleted files may persist in IDE cache** - verify actual file existence with `ls` or `file_search` tools
- **Repository state changes frequently** - don't assume files exist based on previous conversations
- **Use `list_dir` and `grep_search`** to validate current project structure before making changes

### **Context Preservation**
- **Document significant architectural decisions** in this copilot-instructions.md file
- **Include change history** when patterns are established or modified
- **Reference previous decisions** explicitly when building on existing work
- **Maintain decision trail** for future context (what was changed and why)

### **Common Anti-Patterns to Avoid**
❌ Creating installation scripts for tools (use DevContainer instead)  
❌ Assuming file structure without verification  
❌ Ignoring established patterns from previous work  
❌ Making changes without checking git status first  
❌ Forgetting to document significant architectural decisions  

### **Validation Commands Before Major Changes**
```bash
# Check current directory structure
ls -la /workspaces/azuresamples-fabric-observability/

# Verify git status and recent changes
git status
git log --oneline -5

# Validate DevContainer tools
az --version && pwsh --version && dotnet --version && fab --version
```
