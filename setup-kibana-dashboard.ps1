# Kibana Dashboard Setup Script for Windows

Write-Host "Setting up Kibana Dashboard for Vienna Weather Monitoring..." -ForegroundColor Green

# Wait for Kibana to be ready
do {
    try {
        $status = Invoke-RestMethod -Uri "http://localhost:5601/api/status" -Method GET
        if ($status.status.overall.level -eq "available") {
            Write-Host "Kibana is ready!" -ForegroundColor Green
            break
        }
    }
    catch {
        Write-Host "Waiting for Kibana to be ready..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
} while ($true)

Write-Host "Creating data view..." -ForegroundColor Cyan

# Create data view for vienna-weather-* indices
$dataViewBody = @{
    data_view = @{
        title = "vienna-weather-*"
        timeFieldName = "@timestamp"
        name = "Vienna Weather Data"
    }
} | ConvertTo-Json -Depth 3

try {
    $response = Invoke-RestMethod -Uri "http://localhost:5601/api/data_views/data_view" `
        -Method POST `
        -Headers @{"Content-Type"="application/json"; "kbn-xsrf"="true"} `
        -Body $dataViewBody
    Write-Host "✅ Data view created successfully!" -ForegroundColor Green
}
catch {
    Write-Host "ℹ️ Data view may already exist or will be created automatically" -ForegroundColor Yellow
}

Write-Host "Creating temperature visualization..." -ForegroundColor Cyan

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

try {
    $response = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/dashboard" `
        -Method POST `
        -Headers @{"Content-Type"="application/json"; "kbn-xsrf"="true"} `
        -Body $dashboardBody
    Write-Host "🎉 Vienna Weather Dashboard created successfully!" -ForegroundColor Green
}
catch {
    Write-Host "ℹ️ Dashboard may already exist" -ForegroundColor Yellow
}

Write-Host "`n🎯 Kibana Setup Complete!" -ForegroundColor Green
Write-Host "Dashboard URL: http://localhost:5601/app/dashboards" -ForegroundColor Cyan
Write-Host "Data Explorer URL: http://localhost:5601/app/discover" -ForegroundColor Cyan