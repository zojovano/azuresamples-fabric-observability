# OTEL Fabric Observability - Test Automation

This directory contains comprehensive test automation for the Microsoft Fabric OTEL observability solution using modern **Pester 5.x** testing framework. The tests validate both infrastructure deployment and end-to-end data streaming functionality.

## 🎯 **NEW: Unified Pester Test Suite**

**All tests have been consolidated into a single, comprehensive Pester file:**
```powershell
# Run complete test suite
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1"

# Run specific test categories
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1" -Tag "Environment","Authentication"
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1" -Tag "Azure","Fabric","OTEL"

# Quick validation (skip slow tests)
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1" -ExcludeTag "Slow"
```

## 📊 Test Coverage

The unified Pester suite validates:

### 🛠️ **Environment & Setup**
- DevContainer environment validation  
- PowerShell 7.0+ verification
- Git configuration and project structure
- Required tool availability (Azure CLI, Fabric CLI, .NET)

### 🔐 **Authentication & Connectivity**  
- Azure CLI authentication status
- Azure subscription access validation
- Fabric CLI installation and configuration
- Service principal authentication testing

### ☁️ **Azure Infrastructure**
- Resource group existence and accessibility
- Key Vault permissions (when configured)
- Bicep template syntax validation
- Infrastructure readiness assessment

### 🏗️ **Fabric Workspace & Database**
- Workspace listing and accessibility
- KQL database operations and validation  
- OTEL table schema verification
- Query execution capability testing

### 📡 **OTEL Data Pipeline**
- OTEL Collector configuration validation
- Docker containerization readiness
- Worker application structure verification
- Event Hub integration testing

### 🔗 **Git Integration for Deployment**
- Git artifacts folder structure validation
- KQL table definition file verification
- Schema definition accuracy testing
- Deployment script availability and guidance

## 🏷️ **Test Tags for Targeted Execution**

| Tag | Description | Example Usage |
|-----|-------------|---------------|
| `Environment` | DevContainer and tool validation | `-Tag "Environment"` |
| `Authentication` | Auth and connectivity tests | `-Tag "Authentication"` |
| `Azure` | Azure infrastructure validation | `-Tag "Azure"` |
| `Fabric` | Fabric workspace and database tests | `-Tag "Fabric"` |
| `OTEL` | OTEL pipeline and configuration | `-Tag "OTEL"` |
| `GitIntegration` | Git deployment automation | `-Tag "GitIntegration"` |
| `Performance` | Performance and timing tests | `-Tag "Performance"` |
| `Slow` | Tests taking >30 seconds | `-ExcludeTag "Slow"` for quick runs |

## 🚀 Quick Start

### Prerequisites

Before running tests, ensure you have:

1. **Pester 5.x** installed: `Install-Module -Name Pester -Force`
2. **Azure CLI** installed and configured
3. **Microsoft Fabric CLI** (auto-installed by tests if missing)
4. **PowerShell 7.0+** (required for cross-platform support)
5. **DevContainer Environment** (recommended for consistency)

### Basic Test Execution

```powershell
# Complete validation (recommended first run)
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1" -Output Detailed

# Quick environment check
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1" -Tag "Environment" -Output Normal

# Authentication and connectivity validation  
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1" -Tag "Authentication" -Output Detailed

# Infrastructure readiness check
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1" -Tag "Azure","Fabric" -Output Detailed
```

### Advanced Test Scenarios

```powershell
# Continuous Integration mode (fast, essential tests only)
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1" -ExcludeTag "Slow","Manual" -CI

# Development validation (skip manual intervention tests)
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1" -ExcludeTag "Manual" -Output Detailed

# Performance and integration testing (includes slower tests)
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1" -Tag "Performance","Integration" -Output Detailed

# Full test suite with JUnit output for CI/CD
Invoke-Pester -Path "./tests/Azure-Fabric-OTEL.Tests.ps1" -OutputFormat JUnitXml -OutputPath "TestResults.xml"
```

## 🔧 **Legacy Test Scripts** (Deprecated - Use Pester Instead)

⚠️ **These individual scripts are deprecated in favor of the unified Pester suite:**

### Individual PowerShell Scripts

- **Test-FabricIntegration-Git.ps1** - Git integration validation *(replaced by GitIntegration tags)*
- **Test-FabricAuth.ps1** - Authentication testing *(replaced by Authentication tags)*  
- **Test-FabricLocal.ps1** - Local development testing *(replaced by Environment tags)*
- **Verify-DevEnvironment.ps1** - Environment validation *(replaced by Environment tags)*

### .NET xUnit Integration Tests

- **FabricObservability.IntegrationTests/** - C# test project *(replaced by Fabric tags)*
  - FabricWorkspaceTests.cs *(covered by Fabric context)*
  - KqlDatabaseTests.cs *(covered by Fabric context)*
  - OtelTablesTests.cs *(covered by OTEL context)*

### Migration Guide from Legacy Tests

| Legacy Script | New Pester Command |
|---------------|-------------------|
| `./Test-FabricIntegration-Git.ps1` | `Invoke-Pester -Tag "GitIntegration"` |
| `./Test-FabricAuth.ps1` | `Invoke-Pester -Tag "Authentication"` |
| `./Test-FabricLocal.ps1` | `Invoke-Pester -Tag "Environment","Authentication"` |
| `./Verify-DevEnvironment.ps1` | `Invoke-Pester -Tag "Environment"` |
| `dotnet test FabricObservability.IntegrationTests` | `Invoke-Pester -Tag "Fabric","OTEL"` |

## 🧪 **Test Data Generation**

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
  run: .\tests\Test-FabricIntegration-Git.ps1

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
.\tests\Test-FabricIntegration-Git.ps1
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
- **Early Exit Optimization**: Test failures detected in < 30 seconds (vs 300s without optimization)

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

---

## 🎯 Professional Test Automation with .NET xUnit Framework

### Why Use Established Testing Frameworks?

Using established testing frameworks like **xUnit**, **NUnit**, or **MSTest** is much more professional and maintainable than standalone PowerShell scripts. Here's why this approach is superior:

#### ✅ **Professional Advantages**

##### **1. Industry Standard Practices**
- **xUnit** is the most widely adopted testing framework for .NET Core/.NET 5+
- **Mature ecosystem** with extensive tooling and community support
- **Best practices** built into the framework (setup/teardown, dependency injection, etc.)

##### **2. Better Integration**
- **Native .NET testing** integrates seamlessly with the existing codebase
- **IDE support** with IntelliSense, debugging, and test discovery
- **CI/CD integration** works out-of-the-box with GitHub Actions, Azure DevOps, etc.

##### **3. Superior Reporting**
- **Multiple output formats**: JUnit XML, TRX, Visual Studio Test results
- **Code coverage** integration with Coverlet
- **Rich test metadata** and categorization
- **Parallel test execution** for better performance

##### **4. Maintainability**
- **Type safety** and compile-time error checking
- **Refactoring support** with IDE tools
- **Dependency management** through NuGet packages
- **Structured test organization** with classes and attributes

### 🏗️ .NET Test Architecture

#### **Test Project Structure**
```
tests/FabricObservability.IntegrationTests/
├── Infrastructure/
│   └── TestConfiguration.cs       # Configuration and utilities
├── Models/
│   └── OtelModels.cs              # OTEL data models and generators
├── Tests/
│   ├── PrerequisitesTests.cs      # Prerequisites validation
│   ├── FabricWorkspaceTests.cs    # Fabric workspace tests
│   ├── KqlDatabaseTests.cs        # KQL database tests
│   ├── OtelTablesTests.cs         # Table deployment tests
│   └── EventHubStreamingTests.cs  # End-to-end streaming tests
├── appsettings.json               # Test configuration
└── FabricObservability.IntegrationTests.csproj
```

#### **Modern .NET Testing Stack**
```xml
<PackageReference Include="xunit" Version="2.9.0" />
<PackageReference Include="xunit.runner.visualstudio" Version="2.8.2" />
<PackageReference Include="FluentAssertions" Version="6.12.1" />
<PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.11.1" />
<PackageReference Include="coverlet.collector" Version="6.0.2" />
```

#### **Professional Test Features**

##### **1. Fluent Assertions**
```csharp
// Instead of basic asserts, use expressive fluent syntax
result.Success.Should().BeTrue("Azure CLI should be authenticated");
output.Should().Contain(tableName, "Query result should contain table name");
recordCount.Should().BeGreaterOrEqualTo(expectedMinimumRecords);
```

##### **2. Parameterized Tests**
```csharp
[Theory]
[InlineData("OtelLogs")]
[InlineData("OtelMetrics")]
[InlineData("OtelTraces")]
public async Task OtelTable_Should_Exist(string tableName)
```

##### **3. Async/Await Pattern**
```csharp
[Fact]
public async Task EventHub_Data_Should_AppearInFabricTables()
{
    var eventHubInfo = await DiscoverEventHubAsync();
    await SendOtelLogData(eventHubInfo!, testDataCount);
    await VerifyDataInTable("OtelLogs", testDataCount);
}
```

##### **4. Comprehensive Configuration**
```json
{
  "TestConfiguration": {
    "ResourceGroupName": "azuresamples-platformobservabilty-fabric",
    "DataCount": 50,
    "PerformanceThresholdMs": 5000,
    "TestTimeoutMinutes": 10
  },
  "FabricConfiguration": {
    "WorkspaceName": "fabric-otel-workspace",
    "DatabaseName": "otelobservabilitydb"
  }
}
```

### 🔧 .NET Test Execution

#### **Run All Tests**
```bash
dotnet test tests/FabricObservability.IntegrationTests/
```

#### **Run Specific Test Category**
```bash
# Run only table tests
dotnet test --filter "FullyQualifiedName~OtelTablesTests"

# Run only streaming tests  
dotnet test --filter "FullyQualifiedName~EventHubStreamingTests"
```

#### **Generate Coverage Report**
```bash
dotnet test --collect:"XPlat Code Coverage" --results-directory ./coverage
```

#### **Run Tests with Custom Configuration**
```bash
export RESOURCE_GROUP_NAME="my-custom-rg"
export DATA_COUNT="100"
dotnet test tests/FabricObservability.IntegrationTests/
```

### 📊 **Testing Approach Comparison**

| Feature | PowerShell Scripts | .NET xUnit Framework |
|---------|-------------------|---------------------|
| **Type Safety** | ❌ Runtime errors | ✅ Compile-time validation |
| **IDE Support** | ❌ Limited | ✅ Full IntelliSense, debugging |
| **Refactoring** | ❌ Manual, error-prone | ✅ Automated with IDE tools |
| **Parallel Execution** | ❌ Sequential only | ✅ Built-in parallel support |
| **Code Coverage** | ❌ Not available | ✅ Integrated with Coverlet |
| **Test Discovery** | ❌ Manual registration | ✅ Automatic discovery |
| **Assertions** | ❌ Basic comparisons | ✅ Fluent, expressive assertions |
| **Reporting** | ❌ Custom XML generation | ✅ Multiple standard formats |
| **Maintenance** | ❌ High effort | ✅ Low effort with tooling |
| **Debugging** | ❌ Echo statements | ✅ Full debugger support |

### 🎯 .NET Test Categories Implementation

The .NET test project implements comprehensive test coverage:

#### **1. Prerequisites Tests** (`PrerequisitesTests.cs`)
- ✅ Azure CLI installation and authentication
- ✅ Fabric CLI installation and authentication  
- ✅ Required utilities (jq, bc) availability
- ✅ Resource group existence validation

#### **2. Fabric Workspace Tests** (`FabricWorkspaceTests.cs`)
- ✅ Workspace existence and accessibility
- ✅ Authentication and permissions
- ✅ Service principal integration

#### **3. KQL Database Tests** (`KqlDatabaseTests.cs`)
- ✅ Database existence and connectivity
- ✅ Basic query execution capability
- ✅ Access permissions validation

#### **4. OTEL Tables Tests** (`OtelTablesTests.cs`)
- ✅ Table existence verification (OtelLogs, OtelMetrics, OtelTraces)
- ✅ Schema validation and column structure
- ✅ Data ingestion capability testing
- ✅ Query performance validation

#### **5. EventHub Streaming Tests** (`EventHubStreamingTests.cs`)
- ✅ EventHub discovery and connectivity
- ✅ Test data generation and transmission
- ✅ End-to-end data flow validation
- ✅ Data integrity and latency monitoring

### 🤖 Enhanced GitHub Actions Integration

#### **Professional CI/CD Pipeline**
```yaml
- name: Setup .NET
  uses: actions/setup-dotnet@v4
  with:
    dotnet-version: '9.0'

- name: Run .NET Integration Tests
  run: |
    dotnet test tests/FabricObservability.IntegrationTests/ \
      --logger "junit;LogFileName=fabric-test-results.xml" \
      --results-directory ./test-results \
      --collect:"XPlat Code Coverage"

- name: Publish Test Results
  uses: dorny/test-reporter@v1
  with:
    name: Fabric Integration Tests (.NET xUnit)
    path: test-results/fabric-test-results.xml
    reporter: java-junit
```

#### **Enhanced Reporting Features**
- **JUnit XML**: Industry standard test result format
- **TRX Files**: Visual Studio Test Results format
- **Code Coverage**: Integrated coverage reporting with Coverlet
- **Parallel Execution**: Faster test runs with xUnit parallel execution
- **Rich Metadata**: Test categories, traits, and detailed failure information

### ✅ **Professional Testing Benefits**

1. **Professional Standards**: Industry-standard testing practices with xUnit
2. **Type Safety**: Compile-time validation and IntelliSense support
3. **Rich Reporting**: Multiple output formats and code coverage
4. **Maintainability**: Structured, refactorable test code
5. **CI/CD Integration**: Seamless GitHub Actions integration
6. **Debugging Support**: Full IDE debugging capabilities
7. **Parallel Execution**: Faster test execution
8. **Extensibility**: Easy to add new test cases and scenarios

The professional testing approach using .NET xUnit provides a much more maintainable, reliable, and feature-rich testing solution compared to standalone scripts! 🎉

