# OTEL Fabric Observability - Test Automation

This directory contains comprehensive test automation for the Microsoft Fabric OTEL observability solution. The tests validate both infrastructure deployment and end-to-end data streaming functionality.

## 📊 Test Overview

The test suite validates:
- **Infrastructure Deployment**: Fabric workspace, database, and table creation
- **OTEL Table Schema**: Correct structure and configuration
- **EventHub Integration**: Message transmission and reception
- **Data Streaming**: End-to-end data flow from EventHub to Fabric
- **Query Performance**: Basic performance validation

## 🚀 Quick Start

### Prerequisites

Before running tests, ensure you have:

1. **Azure CLI** installed and configured
2. **Microsoft Fabric CLI** installed
3. **Required utilities**: `jq`, `bc` (for Bash version)
4. **Azure Authentication**: Service principal or user login
5. **Resource Group**: Infrastructure deployed via main workflow

### Environment Variables

Set these environment variables for customization:

```bash
export RESOURCE_GROUP_NAME="your-resource-group"
export DATA_COUNT="100"                    # Number of test records per type
export DELAY_BETWEEN_BATCHES="1"          # Delay in seconds between batches
export PERFORMANCE_THRESHOLD_MS="5000"    # Query performance threshold
```

## 🔧 Test Scripts

### 1. Integration Tests

**PowerShell Version** (Cross-platform):
```powershell
.\tests\Test-FabricIntegration.ps1
```

Both scripts provide:
- ✅ Comprehensive validation of Fabric deployment
- 📊 JUnit XML output for GitHub Actions
- 🎯 GitHub step summary generation
- 🔍 Detailed error reporting

### 2. Test Data Generator

**PowerShell Version**:
```powershell
.\tests\Generate-TestData.ps1
```

Generates realistic OTEL data:
- 📝 **Logs**: Application logs with traces, spans, and attributes
- 📈 **Metrics**: System and application metrics (CPU, memory, etc.)
- 🔗 **Traces**: Distributed tracing data with span relationships

## 📋 Test Categories

### 1. Prerequisites Validation
- Azure CLI availability and authentication
- Fabric CLI installation and login
- Required utilities (jq, bc)
- Resource group existence

### 2. Fabric Workspace Access
- Workspace existence verification
- Access permissions validation
- Service principal authentication

### 3. KQL Database Verification
- Database creation validation
- Connection testing
- Permission verification

### 4. OTEL Tables Deployment
- Table existence verification
- Schema validation
- Data ingestion testing

### 5. Table Schema Validation
- Column structure verification
- Data type validation
- Index and partition validation

### 6. EventHub Data Transmission
- EventHub discovery
- Test data generation
- Message transmission validation

### 7. End-to-End Data Streaming
- Data flow verification
- Ingestion latency testing
- Data integrity validation

### 8. Query Performance Testing
- Basic query execution
- Performance threshold validation
- Resource utilization monitoring

## 🤖 GitHub Actions Integration

Tests are automatically executed in GitHub Actions workflows with:

### Test Reporting
- **JUnit XML**: Standard test result format
- **GitHub Test Reporter**: Visual test results in PR/commit view
- **Step Summary**: Detailed markdown summary with test breakdown
- **Artifacts**: Test results and logs uploaded for analysis

### Workflow Integration
```yaml
- name: Run Fabric Integration Tests
  shell: pwsh
  run: .\tests\Test-FabricIntegration.ps1

- name: Upload Test Results
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: fabric-test-results
    path: |
      fabric-test-results.xml
      fabric-test-summary.md

- name: Publish Test Report
  uses: dorny/test-reporter@v1
  if: always()
  with:
    name: Fabric Integration Tests
    path: fabric-test-results.xml
    reporter: java-junit
```

## 📊 Test Results

### JUnit XML Output
Tests generate standard JUnit XML format for integration with:
- GitHub Actions Test Reporter
- Azure DevOps Test Results
- Jenkins Test Results
- Any CI/CD system supporting JUnit format

### GitHub Features
- **Checks Tab**: Detailed test results with pass/fail status
- **Pull Request Comments**: Automatic test result summaries
- **Commit Status**: Green/red status indicators
- **Test Trends**: Historical test result tracking

## 🔍 Troubleshooting

### Common Issues

1. **Authentication Failures**
   ```bash
   # Re-authenticate with Azure
   az login
   fabric login
   ```

2. **Resource Group Not Found**
   ```bash
   # Verify resource group exists
   az group show --name your-resource-group
   ```

3. **EventHub Discovery Issues**
   ```bash
   # Check EventHub namespace
   az eventhubs namespace list --resource-group your-resource-group
   ```

4. **Fabric CLI Issues**
   ```bash
   # Update Fabric CLI
   fabric --version
   fabric login --help
   ```

### Test Debugging

Enable verbose output:
```powershell
$env:TEST_DEBUG = "true"
.\tests\Test-FabricIntegration.ps1
```

Check test logs:
```bash
# View detailed test output
cat fabric-test-summary.md

# Check JUnit XML
cat fabric-test-results.xml
```

## 📈 Performance Benchmarks

### Expected Performance
- **Table Creation**: < 30 seconds
- **Data Ingestion**: 1-5 minutes for small datasets
- **Query Execution**: < 5 seconds for basic queries
- **End-to-End Latency**: < 10 minutes for test data

### Monitoring
Tests include performance monitoring for:
- Infrastructure deployment time
- Data ingestion latency
- Query execution performance
- Resource utilization

## 🔒 Security Considerations

### Authentication
- Use service principals for automated testing
- Rotate credentials regularly
- Use least-privilege access principles

### Data Protection
- Test data is synthetic and non-sensitive
- Automatic cleanup of test resources
- No production data used in tests

## 🛠️ Customization

### Adding New Tests
1. Add test functions to integration scripts
2. Update test categories in JUnit output
3. Document new test requirements
4. Update CI/CD workflows as needed

### Custom Metrics
Extend metric generation in test data generators:
1. Add new metric types to `generate_metric_data()`
2. Include custom resource attributes
3. Update expected schemas in validation

### Environment-Specific Configuration
Create environment-specific parameter files:
```bash
# test-config-dev.env
RESOURCE_GROUP_NAME="dev-fabric-rg"
DATA_COUNT="50"
PERFORMANCE_THRESHOLD_MS="10000"

# test-config-prod.env
RESOURCE_GROUP_NAME="prod-fabric-rg"
DATA_COUNT="1000"
PERFORMANCE_THRESHOLD_MS="3000"
```

## 📚 Additional Resources

- [Microsoft Fabric Documentation](https://docs.microsoft.com/fabric/)
- [Azure EventHub Documentation](https://docs.microsoft.com/azure/event-hubs/)
- [OpenTelemetry Specification](https://opentelemetry.io/docs/)
- [GitHub Actions Documentation](https://docs.github.com/actions)
- [JUnit XML Format](https://github.com/windyroad/JUnit-Schema)

## 🤝 Contributing

When adding new tests:
1. Follow existing naming conventions
2. Include comprehensive error handling
3. Add JUnit XML reporting
4. Update documentation
5. Test on multiple platforms (Linux, macOS, Windows)

## 📞 Support

For issues with test automation:
1. Check the troubleshooting section
2. Review GitHub Actions logs
3. Verify Azure and Fabric CLI authentication
4. Ensure all prerequisites are installed
