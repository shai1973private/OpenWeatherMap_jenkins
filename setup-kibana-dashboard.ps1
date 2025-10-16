# Safer Kibana Dashboard Setup Script for Windows with Error Handling

Write-Host "Setting up Kibana Dashboard for Vienna Weather Monitoring..." -ForegroundColor Green

# Function to safely invoke REST API
function Invoke-SafeRestMethod {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [string]$Body = $null
    )
    
    try {
        $params = @{
            Uri = $Uri
            Method = $Method
            Headers = $Headers
            TimeoutSec = 30
        }
        
        if ($Body) {
            $params.Body = $Body
        }
        
        return Invoke-RestMethod @params
    }
    catch {
        Write-Host "API call failed: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

# Wait for Kibana to be ready with timeout
$maxAttempts = 12
$attempt = 0

do {
    $attempt++
    Write-Host "Checking Kibana status (attempt $attempt/$maxAttempts)..." -ForegroundColor Cyan
    
    $status = Invoke-SafeRestMethod -Uri "http://localhost:5601/api/status"
    
    if ($status -and $status.status.overall.level -eq "available") {
        Write-Host "Kibana is ready!" -ForegroundColor Green
        break
    }
    
    if ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 10
    }
} while ($attempt -lt $maxAttempts)

if ($attempt -eq $maxAttempts) {
    Write-Host "Kibana did not become ready in time. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Creating data view..." -ForegroundColor Cyan

# Create data view for vienna-weather-* indices
$dataViewBody = @{
    data_view = @{
        title = "vienna-weather-*"
        timeFieldName = "@timestamp"
        name = "Vienna Weather Data"
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-SafeRestMethod -Uri "http://localhost:5601/api/data_views/data_view" -Method POST -Headers @{"Content-Type"="application/json"; "kbn-xsrf"="true"} -Body $dataViewBody

if ($response) {
    Write-Host "✅ Data view created successfully!" -ForegroundColor Green
} else {
    Write-Host "ℹ️ Data view may already exist" -ForegroundColor Yellow
}

Write-Host "Creating dashboard..." -ForegroundColor Cyan

# Create dashboard
$dashboardBody = @{
    attributes = @{
        title = "Vienna Weather Monitoring Dashboard"
        description = "Real-time weather monitoring for Vienna, Austria - Auto-created by Jenkins CI/CD"
        panelsJSON = "[]"
        timeRestore = $true
        timeTo = "now"
        timeFrom = "now-24h"
        refreshInterval = @{
            pause = $false
            value = 300000
        }
    }
} | ConvertTo-Json -Depth 4

$response = Invoke-SafeRestMethod -Uri "http://localhost:5601/api/saved_objects/dashboard" -Method POST -Headers @{"Content-Type"="application/json"; "kbn-xsrf"="true"} -Body $dashboardBody

if ($response) {
    Write-Host "🎉 Vienna Weather Dashboard created successfully!" -ForegroundColor Green
} else {
    Write-Host "ℹ️ Dashboard may already exist" -ForegroundColor Yellow
}

Write-Host "`n🎯 Kibana Setup Complete!" -ForegroundColor Green
Write-Host "Dashboard URL: http://localhost:5601/app/dashboards" -ForegroundColor Cyan
Write-Host "Data Explorer URL: http://localhost:5601/app/discover" -ForegroundColor Cyan