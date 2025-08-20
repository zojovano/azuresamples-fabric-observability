#!/bin/bash

# OTEL Test Data Generator
# Generates realistic OpenTelemetry data for testing EventHub to Fabric streaming

set -euo pipefail

# Configuration
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-azuresamples-platformobservabilty-fabric}"
EVENTHUB_NAMESPACE=""
EVENTHUB_NAME=""
DATA_COUNT="${DATA_COUNT:-50}"
DELAY_BETWEEN_BATCHES="${DELAY_BETWEEN_BATCHES:-2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to discover EventHub
discover_eventhub() {
    print_message $BLUE "🔍 Discovering EventHub resources..."
    
    EVENTHUB_NAMESPACE=$(az eventhubs namespace list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "[0].name" \
        --output tsv 2>/dev/null || echo "")
    
    if [[ -z "$EVENTHUB_NAMESPACE" || "$EVENTHUB_NAMESPACE" == "null" ]]; then
        print_message $RED "❌ No EventHub namespace found"
        exit 1
    fi
    
    EVENTHUB_NAME=$(az eventhubs eventhub list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --namespace-name "$EVENTHUB_NAMESPACE" \
        --query "[0].name" \
        --output tsv 2>/dev/null || echo "")
    
    if [[ -z "$EVENTHUB_NAME" || "$EVENTHUB_NAME" == "null" ]]; then
        print_message $RED "❌ No EventHub found"
        exit 1
    fi
    
    print_message $GREEN "✅ Found EventHub: $EVENTHUB_NAMESPACE/$EVENTHUB_NAME"
}

# Function to generate random service names
generate_service_name() {
    local services=("user-service" "order-service" "payment-service" "inventory-service" "notification-service" "analytics-service" "auth-service" "cart-service")
    echo "${services[$((RANDOM % ${#services[@]}))]}"
}

# Function to generate random operation names
generate_operation_name() {
    local operations=("create_user" "process_payment" "update_inventory" "send_notification" "authenticate" "add_to_cart" "place_order" "generate_report")
    echo "${operations[$((RANDOM % ${#operations[@]}))]}"
}

# Function to generate random log level
generate_log_level() {
    local levels=("INFO" "WARN" "ERROR" "DEBUG")
    local level_numbers=(1 3 4 2)
    local index=$((RANDOM % ${#levels[@]}))
    echo "${levels[$index]} ${level_numbers[$index]}"
}

# Function to generate random host
generate_host() {
    local hosts=("web-01" "web-02" "api-01" "api-02" "worker-01" "worker-02")
    echo "${hosts[$((RANDOM % ${#hosts[@]}))]}"
}

# Function to generate trace ID
generate_trace_id() {
    echo "$(openssl rand -hex 16)"
}

# Function to generate span ID
generate_span_id() {
    echo "$(openssl rand -hex 8)"
}

# Function to generate realistic log data
generate_log_data() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local service_name=$(generate_service_name)
    local operation=$(generate_operation_name)
    local trace_id=$(generate_trace_id)
    local span_id=$(generate_span_id)
    local log_info=$(generate_log_level)
    local severity_text=$(echo $log_info | cut -d' ' -f1)
    local severity_number=$(echo $log_info | cut -d' ' -f2)
    local user_id=$((RANDOM % 1000 + 1))
    
    local log_messages=(
        "User $user_id successfully executed $operation"
        "Processing $operation for user $user_id completed"
        "Started $operation workflow for user $user_id"
        "Completed $operation with response time 150ms"
        "Cache hit for $operation operation"
        "Database query for $operation took 45ms"
        "Rate limiting applied for user $user_id"
        "Authentication successful for user $user_id"
    )
    
    local message="${log_messages[$((RANDOM % ${#log_messages[@]}))]}"
    
    cat << EOF
{
    "Timestamp": "$timestamp",
    "ObservedTimestamp": "$timestamp",
    "TraceID": "$trace_id",
    "SpanID": "$span_id",
    "SeverityText": "$severity_text",
    "SeverityNumber": $severity_number,
    "Body": "$message",
    "ResourceAttributes": {
        "service.name": "$service_name",
        "service.version": "1.0.0",
        "service.environment": "production",
        "host.name": "$(generate_host)"
    },
    "LogsAttributes": {
        "user.id": "$user_id",
        "operation": "$operation",
        "source": "application-logs"
    }
}
EOF
}

# Function to generate realistic metric data
generate_metric_data() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local service_name=$(generate_service_name)
    local host=$(generate_host)
    
    local metrics=(
        "cpu.usage.percent:gauge:percent:CPU usage percentage"
        "memory.usage.bytes:gauge:bytes:Memory usage in bytes"
        "request.duration.ms:histogram:milliseconds:Request duration"
        "request.count:counter:count:Number of requests"
        "error.count:counter:count:Number of errors"
        "cache.hit.ratio:gauge:ratio:Cache hit ratio"
        "database.connections:gauge:count:Active database connections"
        "queue.size:gauge:count:Queue size"
    )
    
    local metric_info="${metrics[$((RANDOM % ${#metrics[@]}))]}"
    local metric_name=$(echo $metric_info | cut -d':' -f1)
    local metric_type=$(echo $metric_info | cut -d':' -f2)
    local metric_unit=$(echo $metric_info | cut -d':' -f3)
    local metric_description=$(echo $metric_info | cut -d':' -f4)
    
    # Generate realistic values based on metric type
    local metric_value
    case $metric_name in
        "cpu.usage.percent")
            metric_value=$(echo "scale=2; $RANDOM % 100 + $RANDOM / 32768" | bc)
            ;;
        "memory.usage.bytes")
            metric_value=$((RANDOM % 8000000000 + 1000000000))
            ;;
        "request.duration.ms")
            metric_value=$(echo "scale=2; $RANDOM % 500 + 10 + $RANDOM / 32768" | bc)
            ;;
        "cache.hit.ratio")
            metric_value=$(echo "scale=3; ($RANDOM % 1000) / 1000" | bc)
            ;;
        *)
            metric_value=$((RANDOM % 1000 + 1))
            ;;
    esac
    
    cat << EOF
{
    "Timestamp": "$timestamp",
    "MetricName": "$metric_name",
    "MetricType": "$metric_type",
    "MetricUnit": "$metric_unit",
    "MetricDescription": "$metric_description",
    "MetricValue": $metric_value,
    "Host": "$host",
    "ResourceAttributes": {
        "service.name": "$service_name",
        "service.version": "1.0.0",
        "host.name": "$host"
    },
    "MetricAttributes": {
        "environment": "production",
        "datacenter": "us-east-1"
    }
}
EOF
}

# Function to generate realistic trace data
generate_trace_data() {
    local trace_id=$(generate_trace_id)
    local span_id=$(generate_span_id)
    local parent_id=""
    local start_time=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local end_time=$(date -u -d "+$((RANDOM % 500 + 10)) milliseconds" +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local service_name=$(generate_service_name)
    local operation=$(generate_operation_name)
    
    local span_kinds=("INTERNAL" "SERVER" "CLIENT" "PRODUCER" "CONSUMER")
    local span_kind="${span_kinds[$((RANDOM % ${#span_kinds[@]}))]}"
    
    local span_statuses=("OK" "ERROR" "TIMEOUT")
    local span_status="${span_statuses[$((RANDOM % ${#span_statuses[@]}))]}"
    
    # Sometimes add parent ID for child spans
    if (( RANDOM % 3 == 0 )); then
        parent_id=$(generate_span_id)
    fi
    
    cat << EOF
{
    "TraceID": "$trace_id",
    "SpanID": "$span_id",
    "ParentID": "$parent_id",
    "SpanName": "$operation",
    "SpanStatus": "$span_status",
    "SpanKind": "$span_kind",
    "StartTime": "$start_time",
    "EndTime": "$end_time",
    "ResourceAttributes": {
        "service.name": "$service_name",
        "service.version": "1.0.0",
        "telemetry.sdk.name": "opentelemetry",
        "telemetry.sdk.version": "1.0.0"
    },
    "TraceAttributes": {
        "http.method": "POST",
        "http.status_code": "$((RANDOM % 100 + 200))",
        "user.id": "$((RANDOM % 1000 + 1))"
    },
    "Events": [],
    "Links": []
}
EOF
}

# Function to send data to EventHub
send_to_eventhub() {
    local data="$1"
    local data_type="$2"
    
    echo "$data" | az eventhubs eventhub send \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --namespace-name "$EVENTHUB_NAMESPACE" \
        --name "$EVENTHUB_NAME" \
        --body @- >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        print_message $GREEN "✅ Sent $data_type data"
    else
        print_message $RED "❌ Failed to send $data_type data"
    fi
}

# Main function
main() {
    print_message $GREEN "🚀 Starting OTEL Test Data Generator"
    print_message $GREEN "===================================="
    
    # Check prerequisites
    if ! command -v az >/dev/null 2>&1; then
        print_message $RED "❌ Azure CLI not found"
        exit 1
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        print_message $RED "❌ bc calculator not found (install with: apt-get install bc)"
        exit 1
    fi
    
    # Discover EventHub
    discover_eventhub
    
    print_message $BLUE "📊 Generating and sending $DATA_COUNT records of each type..."
    
    # Generate and send test data
    for i in $(seq 1 $DATA_COUNT); do
        print_message $YELLOW "📦 Sending batch $i/$DATA_COUNT..."
        
        # Generate and send log data
        log_data=$(generate_log_data)
        send_to_eventhub "$log_data" "log"
        
        # Generate and send metric data
        metric_data=$(generate_metric_data)
        send_to_eventhub "$metric_data" "metric"
        
        # Generate and send trace data
        trace_data=$(generate_trace_data)
        send_to_eventhub "$trace_data" "trace"
        
        # Small delay between batches
        sleep $DELAY_BETWEEN_BATCHES
    done
    
    print_message $GREEN "🎉 Test data generation completed!"
    print_message $BLUE "📈 Summary:"
    print_message $BLUE "- Logs sent: $DATA_COUNT"
    print_message $BLUE "- Metrics sent: $DATA_COUNT"
    print_message $BLUE "- Traces sent: $DATA_COUNT"
    print_message $BLUE "- Total records: $((DATA_COUNT * 3))"
    
    print_message $YELLOW "💡 Data should appear in Fabric tables within 1-5 minutes"
    print_message $YELLOW "🔍 Check your Fabric workspace: fabric-otel-workspace"
    print_message $YELLOW "🗄️ Database: otelobservabilitydb"
}

# Execute main function
main "$@"
