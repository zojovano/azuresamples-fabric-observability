# OTEL Test Data Generator (PowerShell)
# Generates realistic OpenTelemetry data for testing EventHub to Fabric streaming

param(
    [string]$ResourceGroupName = $env:RESOURCE_GROUP_NAME ?? "azuresamples-platformobservabilty-fabric",
    [int]$DataCount = [int]($env:DATA_COUNT ?? 50),
    [int]$DelayBetweenBatches = [int]($env:DELAY_BETWEEN_BATCHES ?? 2)
)

# Configuration
$Script:EventHubNamespace = ""
$Script:EventHubName = ""

# Function to write colored output
function Write-ColoredMessage {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to discover EventHub
function Get-EventHub {
    Write-ColoredMessage "🔍 Discovering EventHub resources..." -Color Cyan
    
    try {
        $namespaces = az eventhubs namespace list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        if ($namespaces.Count -eq 0) {
            Write-ColoredMessage "❌ No EventHub namespace found" -Color Red
            exit 1
        }
        
        $Script:EventHubNamespace = $namespaces[0].name
        
        $eventhubs = az eventhubs eventhub list --resource-group $ResourceGroupName --namespace-name $Script:EventHubNamespace --output json | ConvertFrom-Json
        if ($eventhubs.Count -eq 0) {
            Write-ColoredMessage "❌ No EventHub found" -Color Red
            exit 1
        }
        
        $Script:EventHubName = $eventhubs[0].name
        Write-ColoredMessage "✅ Found EventHub: $Script:EventHubNamespace/$Script:EventHubName" -Color Green
    }
    catch {
        Write-ColoredMessage "❌ Error discovering EventHub: $($_.Exception.Message)" -Color Red
        exit 1
    }
}

# Function to generate random service names
function Get-RandomServiceName {
    $services = @("user-service", "order-service", "payment-service", "inventory-service", "notification-service", "analytics-service", "auth-service", "cart-service")
    return $services | Get-Random
}

# Function to generate random operation names
function Get-RandomOperationName {
    $operations = @("create_user", "process_payment", "update_inventory", "send_notification", "authenticate", "add_to_cart", "place_order", "generate_report")
    return $operations | Get-Random
}

# Function to generate random log level
function Get-RandomLogLevel {
    $levels = @(
        @{Text="INFO"; Number=1},
        @{Text="WARN"; Number=3},
        @{Text="ERROR"; Number=4},
        @{Text="DEBUG"; Number=2}
    )
    return $levels | Get-Random
}

# Function to generate random host
function Get-RandomHost {
    $hosts = @("web-01", "web-02", "api-01", "api-02", "worker-01", "worker-02")
    return $hosts | Get-Random
}

# Function to generate trace ID
function New-TraceId {
    $bytes = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return [BitConverter]::ToString($bytes).Replace("-", "").ToLower()
}

# Function to generate span ID
function New-SpanId {
    $bytes = New-Object byte[] 8
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return [BitConverter]::ToString($bytes).Replace("-", "").ToLower()
}

# Function to generate realistic log data
function New-LogData {
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $serviceName = Get-RandomServiceName
    $operation = Get-RandomOperationName
    $traceId = New-TraceId
    $spanId = New-SpanId
    $logLevel = Get-RandomLogLevel
    $userId = Get-Random -Minimum 1 -Maximum 1001
    $hostName = Get-RandomHost
    
    $logMessages = @(
        "User $userId successfully executed $operation",
        "Processing $operation for user $userId completed",
        "Started $operation workflow for user $userId",
        "Completed $operation with response time 150ms",
        "Cache hit for $operation operation",
        "Database query for $operation took 45ms",
        "Rate limiting applied for user $userId",
        "Authentication successful for user $userId"
    )
    
    $message = $logMessages | Get-Random
    
    $logData = @{
        Timestamp = $timestamp
        ObservedTimestamp = $timestamp
        TraceID = $traceId
        SpanID = $spanId
        SeverityText = $logLevel.Text
        SeverityNumber = $logLevel.Number
        Body = $message
        ResourceAttributes = @{
            "service.name" = $serviceName
            "service.version" = "1.0.0"
            "service.environment" = "production"
            "host.name" = $hostName
        }
        LogsAttributes = @{
            "user.id" = $userId
            "operation" = $operation
            "source" = "application-logs"
        }
    }
    
    return $logData | ConvertTo-Json -Depth 10 -Compress
}

# Function to generate realistic metric data
function New-MetricData {
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $serviceName = Get-RandomServiceName
    $hostName = Get-RandomHost
    
    $metrics = @(
        @{Name="cpu.usage.percent"; Type="gauge"; Unit="percent"; Description="CPU usage percentage"},
        @{Name="memory.usage.bytes"; Type="gauge"; Unit="bytes"; Description="Memory usage in bytes"},
        @{Name="request.duration.ms"; Type="histogram"; Unit="milliseconds"; Description="Request duration"},
        @{Name="request.count"; Type="counter"; Unit="count"; Description="Number of requests"},
        @{Name="error.count"; Type="counter"; Unit="count"; Description="Number of errors"},
        @{Name="cache.hit.ratio"; Type="gauge"; Unit="ratio"; Description="Cache hit ratio"},
        @{Name="database.connections"; Type="gauge"; Unit="count"; Description="Active database connections"},
        @{Name="queue.size"; Type="gauge"; Unit="count"; Description="Queue size"}
    )
    
    $metric = $metrics | Get-Random
    
    # Generate realistic values based on metric type
    $metricValue = switch ($metric.Name) {
        "cpu.usage.percent" { [math]::Round((Get-Random -Minimum 0 -Maximum 100) + (Get-Random) / [int]::MaxValue, 2) }
        "memory.usage.bytes" { Get-Random -Minimum 1000000000 -Maximum 8000000000 }
        "request.duration.ms" { [math]::Round((Get-Random -Minimum 10 -Maximum 500) + (Get-Random) / [int]::MaxValue, 2) }
        "cache.hit.ratio" { [math]::Round((Get-Random -Minimum 0 -Maximum 1000) / 1000, 3) }
        default { Get-Random -Minimum 1 -Maximum 1001 }
    }
    
    $metricData = @{
        Timestamp = $timestamp
        MetricName = $metric.Name
        MetricType = $metric.Type
        MetricUnit = $metric.Unit
        MetricDescription = $metric.Description
        MetricValue = $metricValue
        Host = $hostName
        ResourceAttributes = @{
            "service.name" = $serviceName
            "service.version" = "1.0.0"
            "host.name" = $hostName
        }
        MetricAttributes = @{
            "environment" = "production"
            "datacenter" = "us-east-1"
        }
    }
    
    return $metricData | ConvertTo-Json -Depth 10 -Compress
}

# Function to generate realistic trace data
function New-TraceData {
    $traceId = New-TraceId
    $spanId = New-SpanId
    $parentId = if ((Get-Random -Minimum 0 -Maximum 3) -eq 0) { New-SpanId } else { "" }
    $startTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $endTime = (Get-Date).AddMilliseconds((Get-Random -Minimum 10 -Maximum 500)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $serviceName = Get-RandomServiceName
    $operation = Get-RandomOperationName
    
    $spanKinds = @("INTERNAL", "SERVER", "CLIENT", "PRODUCER", "CONSUMER")
    $spanKind = $spanKinds | Get-Random
    
    $spanStatuses = @("OK", "ERROR", "TIMEOUT")
    $spanStatus = $spanStatuses | Get-Random
    
    $userId = Get-Random -Minimum 1 -Maximum 1001
    $statusCode = Get-Random -Minimum 200 -Maximum 300
    
    $traceData = @{
        TraceID = $traceId
        SpanID = $spanId
        ParentID = $parentId
        SpanName = $operation
        SpanStatus = $spanStatus
        SpanKind = $spanKind
        StartTime = $startTime
        EndTime = $endTime
        ResourceAttributes = @{
            "service.name" = $serviceName
            "service.version" = "1.0.0"
            "telemetry.sdk.name" = "opentelemetry"
            "telemetry.sdk.version" = "1.0.0"
        }
        TraceAttributes = @{
            "http.method" = "POST"
            "http.status_code" = $statusCode
            "user.id" = $userId
        }
        Events = @()
        Links = @()
    }
    
    return $traceData | ConvertTo-Json -Depth 10 -Compress
}

# Function to send data to EventHub
function Send-ToEventHub {
    param(
        [string]$Data,
        [string]$DataType
    )
    
    try {
        $tempFile = [System.IO.Path]::GetTempFileName()
        $Data | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline
        az eventhubs eventhub send --resource-group $ResourceGroupName --namespace-name $Script:EventHubNamespace --name $Script:EventHubName --body "@$tempFile" 2>$null
        Remove-Item $tempFile -Force
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColoredMessage "✅ Sent $DataType data" -Color Green
        } else {
            Write-ColoredMessage "❌ Failed to send $DataType data" -Color Red
        }
    }
    catch {
        Write-ColoredMessage "❌ Failed to send $DataType data: $($_.Exception.Message)" -Color Red
    }
}

# Main function
function Main {
    Write-ColoredMessage "🚀 Starting OTEL Test Data Generator" -Color Green
    Write-ColoredMessage "====================================" -Color Green
    
    # Check prerequisites
    try {
        az --version | Out-Null
    }
    catch {
        Write-ColoredMessage "❌ Azure CLI not found" -Color Red
        exit 1
    }
    
    # Discover EventHub
    Get-EventHub
    
    Write-ColoredMessage "📊 Generating and sending $DataCount records of each type..." -Color Cyan
    
    # Generate and send test data
    for ($i = 1; $i -le $DataCount; $i++) {
        Write-ColoredMessage "📦 Sending batch $i/$DataCount..." -Color Yellow
        
        # Generate and send log data
        $logData = New-LogData
        Send-ToEventHub -Data $logData -DataType "log"
        
        # Generate and send metric data
        $metricData = New-MetricData
        Send-ToEventHub -Data $metricData -DataType "metric"
        
        # Generate and send trace data
        $traceData = New-TraceData
        Send-ToEventHub -Data $traceData -DataType "trace"
        
        # Small delay between batches
        Start-Sleep -Seconds $DelayBetweenBatches
    }
    
    Write-ColoredMessage "🎉 Test data generation completed!" -Color Green
    Write-ColoredMessage "📈 Summary:" -Color Cyan
    Write-ColoredMessage "- Logs sent: $DataCount" -Color Cyan
    Write-ColoredMessage "- Metrics sent: $DataCount" -Color Cyan
    Write-ColoredMessage "- Traces sent: $DataCount" -Color Cyan
    Write-ColoredMessage "- Total records: $($DataCount * 3)" -Color Cyan
    
    Write-ColoredMessage "💡 Data should appear in Fabric tables within 1-5 minutes" -Color Yellow
    Write-ColoredMessage "🔍 Check your Fabric workspace: fabric-otel-workspace" -Color Yellow
    Write-ColoredMessage "🗄️ Database: otelobservabilitydb" -Color Yellow
}

# Execute main function
Main
