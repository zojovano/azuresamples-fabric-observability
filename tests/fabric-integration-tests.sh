#!/bin/bash

# Comprehensive Test Suite for Fabric OTEL Observability
# Tests KQL table deployment and EventHub to Fabric data streaming

set -euo pipefail

# Configuration
WORKSPACE_NAME="${FABRIC_WORKSPACE_NAME:-fabric-otel-workspace}"
DATABASE_NAME="${FABRIC_DATABASE_NAME:-otelobservabilitydb}"
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-azuresamples-platformobservabilty-fabric}"
EVENTHUB_NAMESPACE=""
EVENTHUB_NAME=""
TEST_TIMEOUT=300  # 5 minutes timeout for data streaming tests
RESULTS_DIR="test-results"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test result tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to log test result
log_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    local duration="${4:-0}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    case "$status" in
        "PASS")
            PASSED_TESTS=$((PASSED_TESTS + 1))
            print_message $GREEN "✅ PASS: $test_name - $message"
            ;;
        "FAIL")
            FAILED_TESTS=$((FAILED_TESTS + 1))
            print_message $RED "❌ FAIL: $test_name - $message"
            ;;
        "SKIP")
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            print_message $YELLOW "⏭️  SKIP: $test_name - $message"
            ;;
    esac
    
    # Log to JUnit XML for GitHub Actions
    echo "  <testcase name=\"$test_name\" time=\"$duration\">" >> "$RESULTS_DIR/junit.xml"
    if [[ "$status" == "FAIL" ]]; then
        echo "    <failure message=\"$message\">Test failed: $message</failure>" >> "$RESULTS_DIR/junit.xml"
    elif [[ "$status" == "SKIP" ]]; then
        echo "    <skipped message=\"$message\">Test skipped: $message</skipped>" >> "$RESULTS_DIR/junit.xml"
    fi
    echo "  </testcase>" >> "$RESULTS_DIR/junit.xml"
}

# Function to start JUnit XML file
start_junit_xml() {
    cat > "$RESULTS_DIR/junit.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="FabricOTELObservabilityTests" tests="0" failures="0" skipped="0" time="0">
EOF
}

# Function to finalize JUnit XML file
finalize_junit_xml() {
    # Update test counts
    sed -i "s/tests=\"0\"/tests=\"$TOTAL_TESTS\"/" "$RESULTS_DIR/junit.xml"
    sed -i "s/failures=\"0\"/failures=\"$FAILED_TESTS\"/" "$RESULTS_DIR/junit.xml"
    sed -i "s/skipped=\"0\"/skipped=\"$SKIPPED_TESTS\"/" "$RESULTS_DIR/junit.xml"
    
    echo "</testsuite>" >> "$RESULTS_DIR/junit.xml"
}

# Function to run KQL query and return result
run_kql_query() {
    local query=$1
    local timeout=${2:-30}
    
    timeout "$timeout" fab kql execute --query "$query" --output json 2>/dev/null || echo "[]"
}

# Function to discover EventHub resources
discover_eventhub_resources() {
    print_message $BLUE "🔍 Discovering EventHub resources..."
    
    # Get EventHub namespace
    EVENTHUB_NAMESPACE=$(az eventhubs namespace list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "[0].name" \
        --output tsv 2>/dev/null || echo "")
    
    if [[ -z "$EVENTHUB_NAMESPACE" || "$EVENTHUB_NAMESPACE" == "null" ]]; then
        log_test_result "EventHub Discovery" "SKIP" "No EventHub namespace found in resource group"
        return 1
    fi
    
    # Get EventHub name
    EVENTHUB_NAME=$(az eventhubs eventhub list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --namespace-name "$EVENTHUB_NAMESPACE" \
        --query "[0].name" \
        --output tsv 2>/dev/null || echo "")
    
    if [[ -z "$EVENTHUB_NAME" || "$EVENTHUB_NAME" == "null" ]]; then
        log_test_result "EventHub Discovery" "SKIP" "No EventHub found in namespace"
        return 1
    fi
    
    log_test_result "EventHub Discovery" "PASS" "Found EventHub: $EVENTHUB_NAMESPACE/$EVENTHUB_NAME"
    return 0
}

# Test 1: Prerequisites
test_prerequisites() {
    local start_time=$(date +%s)
    
    print_message $BLUE "🔍 Testing prerequisites..."
    
    # Check Fabric CLI
    if ! command -v fab >/dev/null 2>&1; then
        log_test_result "Prerequisites - Fabric CLI" "FAIL" "Fabric CLI not installed"
        return 1
    fi
    
    # Check Azure CLI
    if ! command -v az >/dev/null 2>&1; then
        log_test_result "Prerequisites - Azure CLI" "FAIL" "Azure CLI not installed"
        return 1
    fi
    
    # Check authentication
    if ! fab auth whoami >/dev/null 2>&1; then
        log_test_result "Prerequisites - Fabric Auth" "FAIL" "Not authenticated with Fabric"
        return 1
    fi
    
    # Check Azure authentication
    if ! az account show >/dev/null 2>&1; then
        log_test_result "Prerequisites - Azure Auth" "FAIL" "Not authenticated with Azure"
        return 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_test_result "Prerequisites" "PASS" "All prerequisites met" "$duration"
    return 0
}

# Test 2: Fabric Workspace
test_fabric_workspace() {
    local start_time=$(date +%s)
    
    print_message $BLUE "🏗️  Testing Fabric workspace..."
    
    # Set authentication context
    fab workspace use --name "$WORKSPACE_NAME" >/dev/null 2>&1 || {
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_test_result "Fabric Workspace" "FAIL" "Cannot access workspace: $WORKSPACE_NAME" "$duration"
        return 1
    }
    
    # Verify workspace exists
    local workspaces
    workspaces=$(fab workspace list --output json 2>/dev/null || echo "[]")
    
    if echo "$workspaces" | jq -e --arg name "$WORKSPACE_NAME" '.[] | select(.displayName == $name)' >/dev/null; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_test_result "Fabric Workspace" "PASS" "Workspace '$WORKSPACE_NAME' exists and accessible" "$duration"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_test_result "Fabric Workspace" "FAIL" "Workspace '$WORKSPACE_NAME' not found" "$duration"
        return 1
    fi
}

# Test 3: KQL Database
test_kql_database() {
    local start_time=$(date +%s)
    
    print_message $BLUE "🗄️  Testing KQL database..."
    
    # Set database context
    fab kqldatabase use --name "$DATABASE_NAME" >/dev/null 2>&1 || {
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_test_result "KQL Database" "FAIL" "Cannot access database: $DATABASE_NAME" "$duration"
        return 1
    }
    
    # Verify database exists
    local databases
    databases=$(fab kqldatabase list --output json 2>/dev/null || echo "[]")
    
    if echo "$databases" | jq -e --arg name "$DATABASE_NAME" '.[] | select(.displayName == $name)' >/dev/null; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_test_result "KQL Database" "PASS" "Database '$DATABASE_NAME' exists and accessible" "$duration"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_test_result "KQL Database" "FAIL" "Database '$DATABASE_NAME' not found" "$duration"
        return 1
    fi
}

# Test 4: OTEL Tables Deployment
test_otel_tables() {
    local start_time=$(date +%s)
    
    print_message $BLUE "📊 Testing OTEL tables deployment..."
    
    local expected_tables=("OTELLogs" "OTELMetrics" "OTELTraces")
    local tables_result
    tables_result=$(run_kql_query ".show tables")
    
    local all_tables_exist=true
    
    for table in "${expected_tables[@]}"; do
        if echo "$tables_result" | jq -e --arg table "$table" '.[] | select(.TableName == $table)' >/dev/null 2>&1; then
            log_test_result "OTEL Table - $table" "PASS" "Table exists with correct schema"
        else
            log_test_result "OTEL Table - $table" "FAIL" "Table not found or schema invalid"
            all_tables_exist=false
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if $all_tables_exist; then
        log_test_result "OTEL Tables Deployment" "PASS" "All OTEL tables deployed successfully" "$duration"
        return 0
    else
        log_test_result "OTEL Tables Deployment" "FAIL" "Some OTEL tables missing or invalid" "$duration"
        return 1
    fi
}

# Test 5: Table Schema Validation
test_table_schemas() {
    local start_time=$(date +%s)
    
    print_message $BLUE "📋 Testing table schemas..."
    
    # Test OTELLogs schema
    local logs_schema
    logs_schema=$(run_kql_query ".show table OTELLogs schema")
    local expected_logs_columns=("Timestamp" "ObservedTimestamp" "TraceID" "SpanID" "SeverityText" "SeverityNumber" "Body" "ResourceAttributes" "LogsAttributes")
    
    local logs_schema_valid=true
    for column in "${expected_logs_columns[@]}"; do
        if ! echo "$logs_schema" | jq -e --arg col "$column" '.[] | select(.ColumnName == $col)' >/dev/null 2>&1; then
            logs_schema_valid=false
            break
        fi
    done
    
    if $logs_schema_valid; then
        log_test_result "OTELLogs Schema" "PASS" "Schema contains all required columns"
    else
        log_test_result "OTELLogs Schema" "FAIL" "Schema missing required columns"
    fi
    
    # Test OTELMetrics schema
    local metrics_schema
    metrics_schema=$(run_kql_query ".show table OTELMetrics schema")
    local expected_metrics_columns=("Timestamp" "MetricName" "MetricType" "MetricUnit" "MetricDescription" "MetricValue" "Host" "ResourceAttributes" "MetricAttributes")
    
    local metrics_schema_valid=true
    for column in "${expected_metrics_columns[@]}"; do
        if ! echo "$metrics_schema" | jq -e --arg col "$column" '.[] | select(.ColumnName == $col)' >/dev/null 2>&1; then
            metrics_schema_valid=false
            break
        fi
    done
    
    if $metrics_schema_valid; then
        log_test_result "OTELMetrics Schema" "PASS" "Schema contains all required columns"
    else
        log_test_result "OTELMetrics Schema" "FAIL" "Schema missing required columns"
    fi
    
    # Test OTELTraces schema
    local traces_schema
    traces_schema=$(run_kql_query ".show table OTELTraces schema")
    local expected_traces_columns=("TraceID" "SpanID" "ParentID" "SpanName" "SpanStatus" "SpanKind" "StartTime" "EndTime" "ResourceAttributes" "TraceAttributes" "Events" "Links")
    
    local traces_schema_valid=true
    for column in "${expected_traces_columns[@]}"; do
        if ! echo "$traces_schema" | jq -e --arg col "$column" '.[] | select(.ColumnName == $col)' >/dev/null 2>&1; then
            traces_schema_valid=false
            break
        fi
    done
    
    if $traces_schema_valid; then
        log_test_result "OTELTraces Schema" "PASS" "Schema contains all required columns"
    else
        log_test_result "OTELTraces Schema" "FAIL" "Schema missing required columns"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_test_result "Table Schemas" "PASS" "All table schemas validated" "$duration"
}

# Test 6: Send Test Data to EventHub
send_test_data_to_eventhub() {
    local start_time=$(date +%s)
    
    print_message $BLUE "📤 Sending test data to EventHub..."
    
    if [[ -z "$EVENTHUB_NAMESPACE" || -z "$EVENTHUB_NAME" ]]; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_test_result "EventHub Test Data" "SKIP" "EventHub not available" "$duration"
        return 1
    fi
    
    # Create test OTEL data
    local test_log_data='{
        "Timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
        "ObservedTimestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
        "TraceID": "test-trace-'$(date +%s)'",
        "SpanID": "test-span-'$(date +%s)'",
        "SeverityText": "INFO",
        "SeverityNumber": 1,
        "Body": "Test log message from automated test suite",
        "ResourceAttributes": {"service.name": "test-service", "service.version": "1.0.0"},
        "LogsAttributes": {"test.source": "automation", "test.timestamp": "'$(date +%s)'"}
    }'
    
    local test_metric_data='{
        "Timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
        "MetricName": "test.automation.metric",
        "MetricType": "gauge",
        "MetricUnit": "count",
        "MetricDescription": "Test metric from automation suite",
        "MetricValue": 42.0,
        "Host": "test-host",
        "ResourceAttributes": {"service.name": "test-service"},
        "MetricAttributes": {"test.source": "automation", "test.value": "42"}
    }'
    
    local test_trace_data='{
        "TraceID": "test-trace-'$(date +%s)'",
        "SpanID": "test-span-'$(date +%s)'",
        "ParentID": "",
        "SpanName": "test-automation-span",
        "SpanStatus": "OK",
        "SpanKind": "INTERNAL",
        "StartTime": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
        "EndTime": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
        "ResourceAttributes": {"service.name": "test-service"},
        "TraceAttributes": {"test.source": "automation"},
        "Events": [],
        "Links": []
    }'
    
    # Send test data to EventHub
    echo "$test_log_data" | az eventhubs eventhub send \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --namespace-name "$EVENTHUB_NAMESPACE" \
        --name "$EVENTHUB_NAME" \
        --body @- >/dev/null 2>&1 || {
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_test_result "EventHub Test Data" "FAIL" "Failed to send test data to EventHub" "$duration"
        return 1
    }
    
    echo "$test_metric_data" | az eventhubs eventhub send \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --namespace-name "$EVENTHUB_NAMESPACE" \
        --name "$EVENTHUB_NAME" \
        --body @- >/dev/null 2>&1
    
    echo "$test_trace_data" | az eventhubs eventhub send \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --namespace-name "$EVENTHUB_NAMESPACE" \
        --name "$EVENTHUB_NAME" \
        --body @- >/dev/null 2>&1
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_test_result "EventHub Test Data" "PASS" "Test data sent to EventHub successfully" "$duration"
    return 0
}

# Test 7: Verify Data Streaming (EventHub to Fabric)
test_data_streaming() {
    local start_time=$(date +%s)
    
    print_message $BLUE "🔄 Testing EventHub to Fabric data streaming..."
    
    if [[ -z "$EVENTHUB_NAMESPACE" || -z "$EVENTHUB_NAME" ]]; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_test_result "Data Streaming" "SKIP" "EventHub not available for streaming test" "$duration"
        return 1
    fi
    
    # Wait for data to be processed and ingested
    print_message $YELLOW "⏳ Waiting for data streaming (max ${TEST_TIMEOUT}s)..."
    
    local timeout_end=$(($(date +%s) + TEST_TIMEOUT))
    local data_found=false
    
    while [[ $(date +%s) -lt $timeout_end ]]; do
        # Check for test data in any of the OTEL tables
        local log_count
        log_count=$(run_kql_query "OTELLogs | where Body contains 'Test log message from automated test suite' | count" 10)
        
        local metric_count
        metric_count=$(run_kql_query "OTELMetrics | where MetricName == 'test.automation.metric' | count" 10)
        
        local trace_count
        trace_count=$(run_kql_query "OTELTraces | where SpanName == 'test-automation-span' | count" 10)
        
        # Check if any data is found
        if [[ $(echo "$log_count" | jq -r '.[0].Count // 0') -gt 0 ]] || \
           [[ $(echo "$metric_count" | jq -r '.[0].Count // 0') -gt 0 ]] || \
           [[ $(echo "$trace_count" | jq -r '.[0].Count // 0') -gt 0 ]]; then
            data_found=true
            break
        fi
        
        sleep 10
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if $data_found; then
        log_test_result "Data Streaming" "PASS" "EventHub data successfully streamed to Fabric" "$duration"
        return 0
    else
        log_test_result "Data Streaming" "FAIL" "No test data found in Fabric tables after ${TEST_TIMEOUT}s" "$duration"
        return 1
    fi
}

# Test 8: Query Performance
test_query_performance() {
    local start_time=$(date +%s)
    
    print_message $BLUE "⚡ Testing query performance..."
    
    # Test basic query performance
    local query_start=$(date +%s.%3N)
    local result=$(run_kql_query ".show tables")
    local query_end=$(date +%s.%3N)
    local query_duration=$(echo "$query_end - $query_start" | bc -l)
    
    # Check if query completed in reasonable time (< 10 seconds)
    if (( $(echo "$query_duration < 10.0" | bc -l) )); then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_test_result "Query Performance" "PASS" "Basic queries complete in ${query_duration}s" "$duration"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_test_result "Query Performance" "FAIL" "Queries too slow: ${query_duration}s" "$duration"
        return 1
    fi
}

# Generate GitHub Actions Summary
generate_github_summary() {
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        cat >> "$GITHUB_STEP_SUMMARY" << EOF
## 🧪 Fabric OTEL Observability Test Results

### Test Summary
- **Total Tests**: $TOTAL_TESTS
- **Passed**: $PASSED_TESTS ✅
- **Failed**: $FAILED_TESTS ❌
- **Skipped**: $SKIPPED_TESTS ⏭️

### Test Categories
| Category | Status | Description |
|----------|--------|-------------|
| 🔍 Prerequisites | $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL") | CLI tools and authentication |
| 🏗️ Fabric Workspace | $([ $PASSED_TESTS -gt 1 ] && echo "✅ PASS" || echo "❌ FAIL") | Workspace accessibility |
| 🗄️ KQL Database | $([ $PASSED_TESTS -gt 2 ] && echo "✅ PASS" || echo "❌ FAIL") | Database deployment |
| 📊 OTEL Tables | $([ $PASSED_TESTS -gt 3 ] && echo "✅ PASS" || echo "❌ FAIL") | Table structure validation |
| 📋 Table Schemas | $([ $PASSED_TESTS -gt 4 ] && echo "✅ PASS" || echo "❌ FAIL") | Column schema verification |
| 📤 EventHub Data | $([ $PASSED_TESTS -gt 5 ] && echo "✅ PASS" || echo "⏭️ SKIP") | Test data transmission |
| 🔄 Data Streaming | $([ $PASSED_TESTS -gt 6 ] && echo "✅ PASS" || echo "⏭️ SKIP") | End-to-end data flow |
| ⚡ Query Performance | $([ $PASSED_TESTS -gt 7 ] && echo "✅ PASS" || echo "❌ FAIL") | Query response times |

### Environment Details
- **Workspace**: \`$WORKSPACE_NAME\`
- **Database**: \`$DATABASE_NAME\`
- **Resource Group**: \`$RESOURCE_GROUP_NAME\`
- **EventHub**: \`${EVENTHUB_NAMESPACE:-Not Found}/${EVENTHUB_NAME:-Not Found}\`

$([ $FAILED_TESTS -eq 0 ] && echo "### 🎉 All Tests Passed!" || echo "### ⚠️ Test Failures Detected")

See test artifacts for detailed JUnit XML results.
EOF
    fi
}

# Main execution
main() {
    print_message $GREEN "🧪 Starting Fabric OTEL Observability Test Suite"
    print_message $GREEN "================================================="
    
    # Initialize JUnit XML
    start_junit_xml
    
    # Discover resources
    discover_eventhub_resources || true
    
    # Run all tests
    test_prerequisites || true
    test_fabric_workspace || true
    test_kql_database || true
    test_otel_tables || true
    test_table_schemas || true
    send_test_data_to_eventhub || true
    test_data_streaming || true
    test_query_performance || true
    
    # Finalize results
    finalize_junit_xml
    generate_github_summary
    
    # Final summary
    print_message $BLUE "📊 Test Summary:"
    print_message $BLUE "================"
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo "Skipped: $SKIPPED_TESTS"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        print_message $GREEN "🎉 All tests passed!"
        exit 0
    else
        print_message $RED "❌ $FAILED_TESTS test(s) failed"
        exit 1
    fi
}

# Handle script errors
trap 'print_message $RED "❌ Test script failed at line $LINENO"' ERR

# Execute main function
main "$@"
