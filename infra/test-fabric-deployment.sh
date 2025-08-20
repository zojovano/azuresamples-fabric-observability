#!/bin/bash

# Test Fabric Artifacts Deployment
# This script validates that Fabric artifacts are deployed correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE_NAME="${FABRIC_WORKSPACE_NAME:-fabric-otel-workspace}"
DATABASE_NAME="${FABRIC_DATABASE_NAME:-otelobservabilitydb}"
EXPECTED_TABLES=("OTELLogs" "OTELMetrics" "OTELTraces")

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to run KQL query and return result
run_kql_query() {
    local query=$1
    fab kql execute --query "$query" --output json 2>/dev/null || echo "[]"
}

# Test prerequisites
test_prerequisites() {
    print_message $BLUE "🔍 Testing prerequisites..."
    
    # Check if fab CLI is available
    if ! command -v fab >/dev/null 2>&1; then
        print_message $RED "❌ Fabric CLI (fab) is not installed"
        return 1
    fi
    
    # Check authentication
    if ! fab auth whoami >/dev/null 2>&1; then
        print_message $RED "❌ Not authenticated with Fabric. Run: fab auth login"
        return 1
    fi
    
    print_message $GREEN "✅ Prerequisites met"
    return 0
}

# Test workspace exists
test_workspace() {
    print_message $BLUE "🏗️  Testing workspace: $WORKSPACE_NAME"
    
    local workspaces
    workspaces=$(fab workspace list --output json 2>/dev/null || echo "[]")
    
    if echo "$workspaces" | jq -e --arg name "$WORKSPACE_NAME" '.[] | select(.displayName == $name)' >/dev/null; then
        print_message $GREEN "✅ Workspace '$WORKSPACE_NAME' exists"
        return 0
    else
        print_message $RED "❌ Workspace '$WORKSPACE_NAME' not found"
        return 1
    fi
}

# Test database exists
test_database() {
    print_message $BLUE "🗄️  Testing database: $DATABASE_NAME"
    
    # Set workspace context
    fab workspace use --name "$WORKSPACE_NAME" >/dev/null 2>&1
    
    local databases
    databases=$(fab kqldatabase list --output json 2>/dev/null || echo "[]")
    
    if echo "$databases" | jq -e --arg name "$DATABASE_NAME" '.[] | select(.displayName == $name)' >/dev/null; then
        print_message $GREEN "✅ Database '$DATABASE_NAME' exists"
        return 0
    else
        print_message $RED "❌ Database '$DATABASE_NAME' not found"
        return 1
    fi
}

# Test tables exist
test_tables() {
    print_message $BLUE "📊 Testing OTEL tables..."
    
    # Set database context
    fab kqldatabase use --name "$DATABASE_NAME" >/dev/null 2>&1
    
    # Get list of tables
    local tables_result
    tables_result=$(run_kql_query ".show tables")
    
    local all_tables_exist=true
    
    for table in "${EXPECTED_TABLES[@]}"; do
        if echo "$tables_result" | jq -e --arg table "$table" '.[] | select(.TableName == $table)' >/dev/null 2>&1; then
            print_message $GREEN "✅ Table '$table' exists"
        else
            print_message $RED "❌ Table '$table' not found"
            all_tables_exist=false
        fi
    done
    
    if $all_tables_exist; then
        return 0
    else
        return 1
    fi
}

# Test table schemas
test_table_schemas() {
    print_message $BLUE "📋 Testing table schemas..."
    
    local schema_tests_passed=true
    
    # Test OTELLogs schema
    local logs_schema
    logs_schema=$(run_kql_query ".show table OTELLogs schema")
    
    local expected_logs_columns=("Timestamp" "ObservedTimestamp" "TraceID" "SpanID" "SeverityText" "SeverityNumber" "Body" "ResourceAttributes" "LogsAttributes")
    
    for column in "${expected_logs_columns[@]}"; do
        if echo "$logs_schema" | jq -e --arg col "$column" '.[] | select(.ColumnName == $col)' >/dev/null 2>&1; then
            print_message $GREEN "✅ OTELLogs column '$column' exists"
        else
            print_message $RED "❌ OTELLogs column '$column' missing"
            schema_tests_passed=false
        fi
    done
    
    # Test OTELMetrics schema
    local metrics_schema
    metrics_schema=$(run_kql_query ".show table OTELMetrics schema")
    
    local expected_metrics_columns=("Timestamp" "MetricName" "MetricType" "MetricUnit" "MetricDescription" "MetricValue" "Host" "ResourceAttributes" "MetricAttributes")
    
    for column in "${expected_metrics_columns[@]}"; do
        if echo "$metrics_schema" | jq -e --arg col "$column" '.[] | select(.ColumnName == $col)' >/dev/null 2>&1; then
            print_message $GREEN "✅ OTELMetrics column '$column' exists"
        else
            print_message $RED "❌ OTELMetrics column '$column' missing"
            schema_tests_passed=false
        fi
    done
    
    # Test OTELTraces schema
    local traces_schema
    traces_schema=$(run_kql_query ".show table OTELTraces schema")
    
    local expected_traces_columns=("TraceID" "SpanID" "ParentID" "SpanName" "SpanStatus" "SpanKind" "StartTime" "EndTime" "ResourceAttributes" "TraceAttributes" "Events" "Links")
    
    for column in "${expected_traces_columns[@]}"; do
        if echo "$traces_schema" | jq -e --arg col "$column" '.[] | select(.ColumnName == $col)' >/dev/null 2>&1; then
            print_message $GREEN "✅ OTELTraces column '$column' exists"
        else
            print_message $RED "❌ OTELTraces column '$column' missing"
            schema_tests_passed=false
        fi
    done
    
    if $schema_tests_passed; then
        return 0
    else
        return 1
    fi
}

# Test data ingestion readiness
test_data_readiness() {
    print_message $BLUE "🔄 Testing data ingestion readiness..."
    
    # Test simple queries on each table
    local readiness_passed=true
    
    for table in "${EXPECTED_TABLES[@]}"; do
        local count_result
        count_result=$(run_kql_query "$table | count")
        
        if echo "$count_result" | jq -e '.[0].Count' >/dev/null 2>&1; then
            local count
            count=$(echo "$count_result" | jq -r '.[0].Count')
            print_message $GREEN "✅ Table '$table' ready for data (current records: $count)"
        else
            print_message $RED "❌ Table '$table' not ready for queries"
            readiness_passed=false
        fi
    done
    
    if $readiness_passed; then
        return 0
    else
        return 1
    fi
}

# Show deployment summary
show_summary() {
    print_message $BLUE "📋 Deployment Summary"
    print_message $BLUE "===================="
    
    # Show current user
    local current_user
    current_user=$(fab auth whoami 2>/dev/null || echo "Unknown")
    echo "Current User: $current_user"
    
    # Show workspace info
    echo "Workspace: $WORKSPACE_NAME"
    echo "Database: $DATABASE_NAME"
    
    # Show table count
    echo "Expected Tables: ${#EXPECTED_TABLES[@]}"
    
    # Show connection URL
    print_message $YELLOW "🔗 Access your data at: https://fabric.microsoft.com"
    print_message $YELLOW "💡 Navigate to workspace '$WORKSPACE_NAME' → database '$DATABASE_NAME'"
}

# Main test execution
main() {
    print_message $GREEN "🧪 Starting Fabric Artifacts Validation"
    print_message $GREEN "========================================"
    
    local all_tests_passed=true
    
    # Run all tests
    if ! test_prerequisites; then
        all_tests_passed=false
    fi
    
    if ! test_workspace; then
        all_tests_passed=false
    fi
    
    if ! test_database; then
        all_tests_passed=false
    fi
    
    if ! test_tables; then
        all_tests_passed=false
    fi
    
    if ! test_table_schemas; then
        all_tests_passed=false
    fi
    
    if ! test_data_readiness; then
        all_tests_passed=false
    fi
    
    # Show summary
    show_summary
    
    # Final result
    if $all_tests_passed; then
        print_message $GREEN "🎉 All tests passed! Fabric artifacts are deployed correctly."
        exit 0
    else
        print_message $RED "❌ Some tests failed. Please review the output above."
        exit 1
    fi
}

# Handle script errors
trap 'print_message $RED "❌ Test script failed at line $LINENO"' ERR

# Execute main function
main "$@"
