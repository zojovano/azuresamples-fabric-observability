# KQL Definitions for OTEL Tables

This directory contains the KQL table definitions for the OpenTelemetry tables used in Microsoft Fabric:

## Table Definitions

1. **OTELLogs** - Stores log data from various sources
   - File: [otel-logs.kql](./tables/otel-logs.kql)
   - Used for: Application logs, system logs, and diagnostic information

2. **OTELMetrics** - Stores metrics data
   - File: [otel-metrics.kql](./tables/otel-metrics.kql)
   - Used for: Performance metrics, custom metrics, and resource utilization

3. **OTELTraces** - Stores distributed tracing data
   - File: [otel-traces.kql](./tables/otel-traces.kql)
   - Used for: Distributed tracing, request flows, and service dependencies

## Usage

These KQL table definitions are used in two ways:

1. **Manual Execution**: You can run these KQL commands directly in the Fabric portal to create the tables manually
2. **Automated Deployment**: These definitions are used by the GitHub Actions workflow to automatically create the tables

### Automated Table Creation

The GitHub Actions workflow includes a job that:
1. Reads these KQL definitions
2. Combines them into a single script
3. Converts the script to base64 for the Fabric API
4. Uses the Fabric API to create the KQL database with these table definitions

## Modifying Table Definitions

If you need to modify the table schemas:

1. Update the corresponding `.kql` file
2. Commit and push your changes
3. The GitHub Actions workflow will automatically update the tables in your Fabric workspace

## Additional Tables

To add new tables:

1. Create a new `.kql` file in the `tables` directory
2. Define the table schema using KQL syntax
3. Update the GitHub Actions workflow to include the new table
