# Simple Automatic Kibana Dashboard Setup for Vienna Weather
Write-Host "Setting up Kibana Dashboard..." -ForegroundColor Green

# Wait for Kibana
$attempt = 0
do {
    $attempt++
    Write-Host "Checking Kibana (attempt $attempt)..." -ForegroundColor Cyan
    try {
        $status = Invoke-RestMethod -Uri "http://localhost:5601/api/status" -TimeoutSec 10
        if ($status.status.overall.level -eq "available") {
            Write-Host "Kibana is ready!" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "Waiting..." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 5
} while ($attempt -lt 10)

# Create data view
Write-Host "Creating data view..." -ForegroundColor Cyan
$dataViewBody = @{
    data_view = @{
        title = "vienna-weather-*"
        timeFieldName = "@timestamp"
        name = "Vienna Weather Data"
    }
} | ConvertTo-Json -Depth 3

$headers = @{
    "Content-Type" = "application/json"
    "kbn-xsrf" = "true"
}

try {
    $dataViewResult = Invoke-RestMethod -Uri "http://localhost:5601/api/data_views/data_view" -Method POST -Headers $headers -Body $dataViewBody
    Write-Host "Data view created!" -ForegroundColor Green
} catch {
    Write-Host "Data view may already exist" -ForegroundColor Yellow
}

# Create dashboard
Write-Host "Creating dashboard..." -ForegroundColor Cyan
$dashboardBody = @{
    attributes = @{
        title = "Vienna Weather Monitoring Dashboard"
        description = "Auto-created Vienna Weather Dashboard"
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

try {
    $dashboardResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/dashboard" -Method POST -Headers $headers -Body $dashboardBody
    Write-Host "Dashboard created successfully!" -ForegroundColor Green
    Write-Host "Dashboard ID: $($dashboardResult.id)" -ForegroundColor DarkGreen
} catch {
    Write-Host "Dashboard may already exist" -ForegroundColor Yellow
}

# Show results
Write-Host ""
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "Dashboard: http://localhost:5601/app/dashboards" -ForegroundColor Cyan
Write-Host "Data Explorer: http://localhost:5601/app/discover" -ForegroundColor Cyan