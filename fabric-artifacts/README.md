# Fabric OTEL Observability - Git Integration

This folder contains Microsoft Fabric artifacts that are synchronized with the workspace via Git integration.

## Structure

- `tables/` - KQL table definitions for OTEL data (Logs, Metrics, Traces)

## Deployment Process

1. KQL tables are defined in `.kql` files
2. Workspace is connected to this Git repository folder
3. Changes are committed from Fabric workspace to Git
4. Updates flow from Git to workspace automatically

## Tables

- **OTELLogs** - OpenTelemetry log data
- **OTELMetrics** - OpenTelemetry metrics data  
- **OTELTraces** - OpenTelemetry trace data

## Git Integration Setup

### Prerequisites
- Fabric workspace must be created with Admin permissions
- GitHub repository access
- Fabric CLI authenticated

### Setup Steps

1. **Open Fabric Portal**: Navigate to https://app.fabric.microsoft.com
2. **Access Workspace**: Go to `fabric-otel-workspace`
3. **Open Settings**: Click Workspace Settings > Git Integration
4. **Connect to GitHub**: 
   - Select GitHub as provider
   - Choose this repository: `azuresamples-fabric-observability`
   - Set folder to: `fabric-artifacts`
   - Select branch: `main`
5. **Initial Sync**: Choose sync direction (workspace to Git or Git to workspace)
6. **Commit/Update**: Use Source Control panel to sync changes

### Benefits of Git Integration

- ✅ Automatic versioning and backup
- ✅ Reliable deployment process  
- ✅ No complex API calls needed
- ✅ Visual Git status in Fabric portal
- ✅ Branch-based development workflows
- ✅ Collaborative development support

## Usage

### Making Changes
1. Edit KQL database items in Fabric portal
2. Use Source Control panel to commit changes to Git
3. Changes appear in this repository automatically

### Deploying Changes
1. Make changes to `.kql` files in this folder
2. Commit changes to Git repository
3. Use Source Control panel in workspace to update from Git

## Table Definitions

Each table has a corresponding `.kql` file with the complete schema:

- `otel-logs.kql` - Log data structure with timestamp, trace info, severity
- `otel-metrics.kql` - Metrics data with measurements and metadata  
- `otel-traces.kql` - Distributed tracing data with spans and relationships
