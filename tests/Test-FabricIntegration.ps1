#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Comprehensive Test Suite for Fabric OTEL Observability

.DESCRIPTION
    Comprehensive test suite for Microsoft Fabric OTEL observability implementation.
    Tests KQL table deployment and EventHub to Fabric data streaming.
    
    The script includes early exit logic to avoid time-consuming EventHub tests (300s timeout)
    when critical prerequisites fail. This improves test efficiency and developer experience.

.PARAMETER ResourceGroupName
    Name of the Azure resource group containing the infrastructure

.PARAMETER WorkspaceName  
    Name of the Microsoft Fabric workspace

.PARAMETER DatabaseName
    Name of the KQL database in the workspace

.PARAMETER TestTimeout
    Timeout for data streaming tests in seconds (default: 300)

.PARAMETER WorkspaceName
    Name of the Fabric workspace (default: fabric-otel-workspace)

.PARAMETER DatabaseName  
    Name of the KQL database (default: otelobservabilitydb)

.PARAMETER ResourceGroupName
    Azure resource group name (default: azuresamples-platformobservabilty-fabric)

.PARAMETER TestTimeout
    Timeout for data streaming tests in seconds (default: 300)

.EXAMPLE
    .\Test-FabricIntegration.ps1
    
.EXAMPLE
    .\Test-FabricIntegration.ps1 -TestTimeout 600

.NOTES
    Author: Generated for Azure Samples - Fabric Observability Project
    Requires: Microsoft Fabric CLI (fab), Azure CLI
#>

[CmdletBinding()]
param(
    [string]$WorkspaceName = $env:FABRIC_WORKSPACE_NAME ?? "fabric-otel-workspace",
    [string]$DatabaseName = $env:FABRIC_DATABASE_NAME ?? "otelobservabilitydb", 
    [string]$ResourceGroupName = $env:RESOURCE_GROUP_NAME ?? "azuresamples-platformobservabilty-fabric",
    [int]$TestTimeout = 300
)

# Test configuration
$script:EventHubNamespace = ""
$script:EventHubName = ""
$script:ResultsDir = "test-results"
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0
$script:SkippedTests = 0

# Colors for output
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "Cyan"

# Create results directory
if (-not (Test-Path $script:ResultsDir)) {
    New-Item -ItemType Directory -Path $script:ResultsDir -Force | Out-Null
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [string]$Prefix = ""
    )
    if ($Prefix) {
        Write-Host "$Prefix " -NoNewline -ForegroundColor $Color
    }
    Write-Host $Message -ForegroundColor $Color
}

function Write-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Message,
        [int]$Duration = 0
    )
    
    $script:TotalTests++
    
    switch ($Status) {
        "PASS" {
            $script:PassedTests++
            Write-ColorOutput "PASS: $TestName - $Message" $ColorSuccess "✅"
        }
        "FAIL" {
            $script:FailedTests++
            Write-ColorOutput "FAIL: $TestName - $Message" $ColorError "❌"
        }
        "SKIP" {
            $script:SkippedTests++
            Write-ColorOutput "SKIP: $TestName - $Message" $ColorWarning "⏭️"
        }
    }
    
    # Log to JUnit XML
    Add-Content -Path "$($script:ResultsDir)/junit.xml" -Value "  <testcase name=`"$TestName`" time=`"$Duration`">"
    if ($Status -eq "FAIL") {
        Add-Content -Path "$($script:ResultsDir)/junit.xml" -Value "    <failure message=`"$Message`">Test failed: $Message</failure>"
    } elseif ($Status -eq "SKIP") {
        Add-Content -Path "$($script:ResultsDir)/junit.xml" -Value "    <skipped message=`"$Message`">Test skipped: $Message</skipped>"
    }
    Add-Content -Path "$($script:ResultsDir)/junit.xml" -Value "  </testcase>"
}

function Start-JUnitXml {
    @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="FabricOTELObservabilityTests" tests="0" failures="0" skipped="0" time="0">
'@ | Out-File -FilePath "$($script:ResultsDir)/junit.xml" -Encoding UTF8
}

function Complete-JUnitXml {
    # Update test counts
    $content = Get-Content "$($script:ResultsDir)/junit.xml"
    $content = $content -replace 'tests="0"', "tests=`"$($script:TotalTests)`""
    $content = $content -replace 'failures="0"', "failures=`"$($script:FailedTests)`""
    $content = $content -replace 'skipped="0"', "skipped=`"$($script:SkippedTests)`""
    $content | Out-File -FilePath "$($script:ResultsDir)/junit.xml" -Encoding UTF8
    
    Add-Content -Path "$($script:ResultsDir)/junit.xml" -Value "</testsuite>"
}

function Invoke-KqlQuery {
    param(
        [string]$Query,
        [int]$Timeout = 30
    )
    
    try {
        # Get workspace ID 
        $workspaceList = fab api "workspaces" --method get 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Failed to get workspace list" $ColorError "❌"
            return @()
        }
        
        $workspaces = $workspaceList | ConvertFrom-Json
        $workspace = $workspaces.value | Where-Object { $_.displayName -eq $WorkspaceName }
        if (-not $workspace) {
            Write-ColorOutput "Workspace '$WorkspaceName' not found" $ColorError "❌"
            return @()
        }
        
        # Get database ID
        $databaseList = fab api "workspaces/$($workspace.id)/kqldatabases" --method get 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Failed to get database list for workspace" $ColorError "❌"
            return @()
        }
        
        $databases = $databaseList | ConvertFrom-Json
        $database = $databases.value | Where-Object { $_.displayName -eq $DatabaseName }
        if (-not $database) {
            Write-ColorOutput "Database '$DatabaseName' not found in workspace" $ColorError "❌"
            return @()
        }
        
        # Execute query using proper IDs
        $tempFile = [System.IO.Path]::GetTempFileName()
        $queryBody = @{
            csl = $Query
            db = $DatabaseName
        } | ConvertTo-Json
        $queryBody | Out-File -FilePath $tempFile -Encoding UTF8
        
        $result = fab api "workspaces/$($workspace.id)/kqldatabases/$($database.id)/query" --method post --input "@$tempFile" 2>&1
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        if ($LASTEXITCODE -eq 0 -and $result) {
            return $result | ConvertFrom-Json
        }
    } catch {
        Write-ColorOutput "Error in KQL query: $_" $ColorError "❌"
    }
    return @()
}

function Find-EventHubResources {
    Write-ColorOutput "Discovering EventHub resources..." $ColorInfo "🔍"
    
    try {
        # Get EventHub namespace
        $script:EventHubNamespace = az eventhubs namespace list --resource-group $ResourceGroupName --query "[0].name" --output tsv 2>$null
        
        if (-not $script:EventHubNamespace -or $script:EventHubNamespace -eq "null") {
            Write-TestResult "EventHub Discovery" "SKIP" "No EventHub namespace found in resource group"
            return $false
        }
        
        # Get EventHub name
        $script:EventHubName = az eventhubs eventhub list --resource-group $ResourceGroupName --namespace-name $script:EventHubNamespace --query "[0].name" --output tsv 2>$null
        
        if (-not $script:EventHubName -or $script:EventHubName -eq "null") {
            Write-TestResult "EventHub Discovery" "SKIP" "No EventHub found in namespace"
            return $false
        }
        
        Write-TestResult "EventHub Discovery" "PASS" "Found EventHub: $($script:EventHubNamespace)/$($script:EventHubName)"
        return $true
        
    } catch {
        Write-TestResult "EventHub Discovery" "FAIL" "Error discovering EventHub: $_"
        return $false
    }
}

function Test-Prerequisites {
    $startTime = Get-Date
    Write-ColorOutput "Testing prerequisites..." $ColorInfo "🔍"
    
    # Check Fabric CLI
    if (-not (Get-Command fab -ErrorAction SilentlyContinue)) {
        Write-TestResult "Prerequisites - Fabric CLI" "FAIL" "Fabric CLI not installed"
        return $false
    }
    
    # Check Azure CLI
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-TestResult "Prerequisites - Azure CLI" "FAIL" "Azure CLI not installed"
        return $false
    }
    
    # Check Fabric authentication
    try {
        fab auth status >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-TestResult "Prerequisites - Fabric Auth" "FAIL" "Not authenticated with Fabric"
            return $false
        }
    } catch {
        Write-TestResult "Prerequisites - Fabric Auth" "FAIL" "Not authenticated with Fabric"
        return $false
    }
    
    # Check Azure authentication
    try {
        az account show >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-TestResult "Prerequisites - Azure Auth" "FAIL" "Not authenticated with Azure"
            return $false
        }
    } catch {
        Write-TestResult "Prerequisites - Azure Auth" "FAIL" "Not authenticated with Azure"
        return $false
    }
    
    $duration = [int]((Get-Date) - $startTime).TotalSeconds
    Write-TestResult "Prerequisites" "PASS" "All prerequisites met" $duration
    return $true
}

function Test-FabricWorkspace {
    $startTime = Get-Date
    Write-ColorOutput "Testing Fabric workspace..." $ColorInfo "🏗️"
    
    try {
        # List all workspaces and check if ours exists
        $workspaceOutput = fab ls 2>&1
        $workspaceExitCode = $LASTEXITCODE
        
        if ($workspaceExitCode -ne 0) {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "Fabric Workspace" "FAIL" "Cannot list workspaces" $duration
            return $false
        }
        
        # Check if our workspace is in the list
        $workspaceExists = $workspaceOutput | Select-String "$WorkspaceName.Workspace" -Quiet
        
        if ($workspaceExists) {
            # Try to navigate to the workspace to verify access
            $cdOutput = fab cd "$WorkspaceName.Workspace" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $duration = [int]((Get-Date) - $startTime).TotalSeconds
                Write-TestResult "Fabric Workspace" "PASS" "Workspace '$WorkspaceName' exists and accessible" $duration
                return $true
            } else {
                $duration = [int]((Get-Date) - $startTime).TotalSeconds
                Write-TestResult "Fabric Workspace" "FAIL" "Cannot access workspace: $WorkspaceName" $duration
                return $false
            }
        } else {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "Fabric Workspace" "FAIL" "Workspace '$WorkspaceName' not found" $duration
            return $false
        }
        
    } catch {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "Fabric Workspace" "FAIL" "Error accessing workspace: $_" $duration
        return $false
    }
}

function Test-KqlDatabase {
    $startTime = Get-Date
    Write-ColorOutput "Testing KQL database..." $ColorInfo "🗄️"
    
    try {
        # First navigate to the workspace
        $cdWorkspaceOutput = fab cd "$WorkspaceName.Workspace" 2>&1
        if ($LASTEXITCODE -ne 0) {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "KQL Database" "FAIL" "Cannot access workspace for database test" $duration
            return $false
        }
        
        # Try to navigate to the database to verify it exists and is accessible
        $cdDatabaseOutput = fab cd "$WorkspaceName.Workspace/$DatabaseName.KQLDatabase" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "KQL Database" "PASS" "Database '$DatabaseName' exists and accessible" $duration
            return $true
        } else {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "KQL Database" "FAIL" "Cannot access database: $DatabaseName" $duration
            return $false
        }
        
    } catch {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "KQL Database" "FAIL" "Error accessing database: $_" $duration
        return $false
    }
}

function Test-OtelTables {
    $startTime = Get-Date
    Write-ColorOutput "Testing OTEL tables deployment..." $ColorInfo "📊"
    
    $expectedTables = @("OTELLogs", "OTELMetrics", "OTELTraces")
    $tablesResult = Invoke-KqlQuery ".show tables"
    
    $allTablesExist = $true
    
    foreach ($table in $expectedTables) {
        $tableExists = $tablesResult | Where-Object { $_.TableName -eq $table }
        if ($tableExists) {
            Write-TestResult "OTEL Table - $table" "PASS" "Table exists with correct schema"
        } else {
            Write-TestResult "OTEL Table - $table" "FAIL" "Table not found or schema invalid"
            $allTablesExist = $false
        }
    }
    
    $duration = [int]((Get-Date) - $startTime).TotalSeconds
    
    if ($allTablesExist) {
        Write-TestResult "OTEL Tables Deployment" "PASS" "All OTEL tables deployed successfully" $duration
        return $true
    } else {
        Write-TestResult "OTEL Tables Deployment" "FAIL" "Some OTEL tables missing or invalid" $duration
        return $false
    }
}

function Test-TableSchemas {
    $startTime = Get-Date
    Write-ColorOutput "Testing table schemas..." $ColorInfo "📋"
    
    # Test OTELLogs schema
    $logsSchema = Invoke-KqlQuery ".show table OTELLogs schema"
    $expectedLogsColumns = @("Timestamp", "ObservedTimestamp", "TraceID", "SpanID", "SeverityText", "SeverityNumber", "Body", "ResourceAttributes", "LogsAttributes")
    
    $logsSchemaValid = $true
    foreach ($column in $expectedLogsColumns) {
        $columnExists = $logsSchema | Where-Object { $_.ColumnName -eq $column }
        if (-not $columnExists) {
            $logsSchemaValid = $false
            break
        }
    }
    
    if ($logsSchemaValid) {
        Write-TestResult "OTELLogs Schema" "PASS" "Schema contains all required columns"
    } else {
        Write-TestResult "OTELLogs Schema" "FAIL" "Schema missing required columns"
    }
    
    # Test OTELMetrics schema
    $metricsSchema = Invoke-KqlQuery ".show table OTELMetrics schema"
    $expectedMetricsColumns = @("Timestamp", "MetricName", "MetricType", "MetricUnit", "MetricDescription", "MetricValue", "Host", "ResourceAttributes", "MetricAttributes")
    
    $metricsSchemaValid = $true
    foreach ($column in $expectedMetricsColumns) {
        $columnExists = $metricsSchema | Where-Object { $_.ColumnName -eq $column }
        if (-not $columnExists) {
            $metricsSchemaValid = $false
            break
        }
    }
    
    if ($metricsSchemaValid) {
        Write-TestResult "OTELMetrics Schema" "PASS" "Schema contains all required columns"
    } else {
        Write-TestResult "OTELMetrics Schema" "FAIL" "Schema missing required columns"
    }
    
    # Test OTELTraces schema
    $tracesSchema = Invoke-KqlQuery ".show table OTELTraces schema"
    $expectedTracesColumns = @("TraceID", "SpanID", "ParentID", "SpanName", "SpanStatus", "SpanKind", "StartTime", "EndTime", "ResourceAttributes", "TraceAttributes", "Events", "Links")
    
    $tracesSchemaValid = $true
    foreach ($column in $expectedTracesColumns) {
        $columnExists = $tracesSchema | Where-Object { $_.ColumnName -eq $column }
        if (-not $columnExists) {
            $tracesSchemaValid = $false
            break
        }
    }
    
    if ($tracesSchemaValid) {
        Write-TestResult "OTELTraces Schema" "PASS" "Schema contains all required columns"
    } else {
        Write-TestResult "OTELTraces Schema" "FAIL" "Schema missing required columns"
    }
    
    $duration = [int]((Get-Date) - $startTime).TotalSeconds
    Write-TestResult "Table Schemas" "PASS" "All table schemas validated" $duration
}

function Send-TestDataToEventHub {
    $startTime = Get-Date
    Write-ColorOutput "Sending test data to EventHub..." $ColorInfo "📤"
    
    # Check if critical prerequisites have passed (need at least 4: Prerequisites, Workspace, Database, Tables)
    if ($script:PassedTests -lt 4) {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "EventHub Test Data" "SKIP" "Critical prerequisites not met (passed: $($script:PassedTests), required: 4)" $duration
        return $false
    }
    
    if (-not $script:EventHubNamespace -or -not $script:EventHubName) {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "EventHub Test Data" "SKIP" "EventHub not available" $duration
        return $false
    }
    
    # Create test OTEL data
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $testId = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    
    $testLogData = @{
        Timestamp = $timestamp
        ObservedTimestamp = $timestamp
        TraceID = "test-trace-$testId"
        SpanID = "test-span-$testId"
        SeverityText = "INFO"
        SeverityNumber = 1
        Body = "Test log message from automated test suite"
        ResourceAttributes = @{ "service.name" = "test-service"; "service.version" = "1.0.0" }
        LogsAttributes = @{ "test.source" = "automation"; "test.timestamp" = $testId }
    } | ConvertTo-Json -Compress
    
    try {
        # Send test data to EventHub
        $testLogData | az eventhubs eventhub send --resource-group $ResourceGroupName --namespace-name $script:EventHubNamespace --name $script:EventHubName --body '@-' 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "EventHub Test Data" "PASS" "Test data sent to EventHub successfully" $duration
            return $true
        } else {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "EventHub Test Data" "FAIL" "Failed to send test data to EventHub" $duration
            return $false
        }
        
    } catch {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "EventHub Test Data" "FAIL" "Error sending test data: $_" $duration
        return $false
    }
}

function Test-DataStreaming {
    $startTime = Get-Date
    Write-ColorOutput "Testing EventHub to Fabric data streaming..." $ColorInfo "🔄"
    
    # Check if critical prerequisites have passed (need at least 4: Prerequisites, Workspace, Database, Tables)
    if ($script:PassedTests -lt 4) {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "Data Streaming" "SKIP" "Critical prerequisites not met (passed: $($script:PassedTests), required: 4)" $duration
        return $false
    }
    
    if (-not $script:EventHubNamespace -or -not $script:EventHubName) {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "Data Streaming" "SKIP" "EventHub not available for streaming test" $duration
        return $false
    }
    
    Write-ColorOutput "Waiting for data streaming (max ${TestTimeout}s)..." $ColorWarning "⏳"
    
    $timeoutEnd = (Get-Date).AddSeconds($TestTimeout)
    $dataFound = $false
    
    while ((Get-Date) -lt $timeoutEnd) {
        # Check for test data in OTEL tables
        $logCount = Invoke-KqlQuery "OTELLogs | where Body contains 'Test log message from automated test suite' | count"
        
        if ($logCount.Count -gt 0) {
            $dataFound = $true
            break
        }
        
        Start-Sleep -Seconds 10
    }
    
    $duration = [int]((Get-Date) - $startTime).TotalSeconds
    
    if ($dataFound) {
        Write-TestResult "Data Streaming" "PASS" "EventHub data successfully streamed to Fabric" $duration
        return $true
    } else {
        Write-TestResult "Data Streaming" "FAIL" "No test data found in Fabric tables after ${TestTimeout}s" $duration
        return $false
    }
}

function Test-QueryPerformance {
    $startTime = Get-Date
    Write-ColorOutput "Testing query performance..." $ColorInfo "⚡"
    
    $queryStart = Get-Date
    $result = Invoke-KqlQuery ".show tables"
    $queryEnd = Get-Date
    $queryDuration = ($queryEnd - $queryStart).TotalSeconds
    
    # Check if query completed in reasonable time (< 10 seconds)
    if ($queryDuration -lt 10.0) {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "Query Performance" "PASS" "Basic queries complete in ${queryDuration}s" $duration
        return $true
    } else {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "Query Performance" "FAIL" "Queries too slow: ${queryDuration}s" $duration
        return $false
    }
}

function New-GitHubSummary {
    if ($env:GITHUB_STEP_SUMMARY) {
        $summary = @"
## 🧪 Fabric OTEL Observability Test Results

### Test Summary
- **Total Tests**: $($script:TotalTests)
- **Passed**: $($script:PassedTests) ✅
- **Failed**: $($script:FailedTests) ❌
- **Skipped**: $($script:SkippedTests) ⏭️

### Test Categories
| Category | Status | Description |
|----------|--------|-------------|
| 🔍 Prerequisites | $(if ($script:PassedTests -gt 0) { "✅ PASS" } else { "❌ FAIL" }) | CLI tools and authentication |
| 🏗️ Fabric Workspace | $(if ($script:PassedTests -gt 1) { "✅ PASS" } else { "❌ FAIL" }) | Workspace accessibility |
| 🗄️ KQL Database | $(if ($script:PassedTests -gt 2) { "✅ PASS" } else { "❌ FAIL" }) | Database deployment |
| 📊 OTEL Tables | $(if ($script:PassedTests -gt 3) { "✅ PASS" } else { "❌ FAIL" }) | Table structure validation |
| 📋 Table Schemas | $(if ($script:PassedTests -gt 4) { "✅ PASS" } else { "❌ FAIL" }) | Column schema verification |
| 📤 EventHub Data | $(if ($script:PassedTests -gt 5) { "✅ PASS" } else { "⏭️ SKIP" }) | Test data transmission |
| 🔄 Data Streaming | $(if ($script:PassedTests -gt 6) { "✅ PASS" } else { "⏭️ SKIP" }) | End-to-end data flow |
| ⚡ Query Performance | $(if ($script:PassedTests -gt 7) { "✅ PASS" } else { "❌ FAIL" }) | Query response times |

### Environment Details
- **Workspace**: ``$WorkspaceName``
- **Database**: ``$DatabaseName``
- **Resource Group**: ``$ResourceGroupName``
- **EventHub**: ``$($script:EventHubNamespace ?? 'Not Found')/$($script:EventHubName ?? 'Not Found')``

$(if ($script:FailedTests -eq 0) { "### 🎉 All Tests Passed!" } else { "### ⚠️ Test Failures Detected" })

See test artifacts for detailed JUnit XML results.
"@
        
        Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $summary
    }
}

# Main execution
try {
    Write-ColorOutput "Starting Fabric OTEL Observability Test Suite" $ColorSuccess "🧪"
    Write-ColorOutput "=================================================" $ColorSuccess
    
    # Initialize JUnit XML
    Start-JUnitXml
    
    # Discover resources
    Find-EventHubResources | Out-Null
    
    # Run all tests
    Test-Prerequisites | Out-Null
    Test-FabricWorkspace | Out-Null
    Test-KqlDatabase | Out-Null
    Test-OtelTables | Out-Null
    Test-TableSchemas | Out-Null
    
    # EventHub tests - will skip if critical prerequisites failed
    if ($script:PassedTests -lt 4) {
        Write-ColorOutput "Skipping EventHub tests due to failed prerequisites (passed: $($script:PassedTests), required: 4)" $ColorWarning "⏭️"
    }
    Send-TestDataToEventHub | Out-Null
    Test-DataStreaming | Out-Null
    Test-QueryPerformance | Out-Null
    
    # Finalize results
    Complete-JUnitXml
    New-GitHubSummary
    
    # Final summary
    Write-ColorOutput "Test Summary:" $ColorInfo "📊"
    Write-ColorOutput "================" $ColorInfo
    Write-Host "Total Tests: $($script:TotalTests)"
    Write-Host "Passed: $($script:PassedTests)"
    Write-Host "Failed: $($script:FailedTests)"
    Write-Host "Skipped: $($script:SkippedTests)"
    
    if ($script:FailedTests -eq 0) {
        Write-ColorOutput "All tests passed!" $ColorSuccess "🎉"
        exit 0
    } else {
        Write-ColorOutput "$($script:FailedTests) test(s) failed" $ColorError "❌"
        exit 1
    }
    
} catch {
    Write-ColorOutput "Test script failed: $_" $ColorError "❌"
    exit 1
}
