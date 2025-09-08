# Fabric OTEL Observability - Git Integration

This folder contains Microsoft Fabric artifacts that are synchronized with the workspace via Git integration.

## Structure

- 	ables/ - KQL table definitions for OTEL data (Logs, Metrics, Traces)

## Deployment Process

1. KQL tables are defined in .kql files
2. Workspace is connected to this Git repository folder
3. Changes are committed from Fabric workspace to Git
4. Updates flow from Git to workspace automatically

## Tables

- **OTELLogs** - OpenTelemetry log data
- **OTELMetrics** - OpenTelemetry metrics data  
- **OTELTraces** - OpenTelemetry trace data

## Usage

Use Fabric portal to:
1. Edit KQL database items
2. Commit changes to Git
3. Update workspace from Git when changes are made externally
