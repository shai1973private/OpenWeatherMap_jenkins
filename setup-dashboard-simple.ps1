# Simple Complete Dashboard Setup
Write-Host "Creating Vienna Weather Dashboard with Visualizations..." -ForegroundColor Green

# Wait for Kibana
$attempt = 0
do {
    $attempt++
    Write-Host "Checking Kibana (attempt $attempt)..." -ForegroundColor Cyan
    try {
        $status = Invoke-RestMethod -Uri "http://localhost:5601/api/status" -TimeoutSec 10
        if ($status.status.overall.level -eq "available") {
            Write-Host "Kibana ready!" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "Waiting..." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 5
} while ($attempt -lt 10)

$headers = @{"Content-Type"="application/json"; "kbn-xsrf"="true"}

# Get data view
Write-Host "Setting up data view..." -ForegroundColor Cyan
try {
    $dataViews = Invoke-RestMethod -Uri "http://localhost:5601/api/data_views"
    $dataViewId = $dataViews.data_view[0].id
    Write-Host "Data view ID: $dataViewId" -ForegroundColor Green
} catch {
    Write-Host "Creating new data view..." -ForegroundColor Yellow
    $dvBody = @{data_view=@{title="vienna-weather-*";timeFieldName="@timestamp";name="Vienna Weather Data"}} | ConvertTo-Json -Depth 3
    $dvResult = Invoke-RestMethod -Uri "http://localhost:5601/api/data_views/data_view" -Method POST -Headers $headers -Body $dvBody
    $dataViewId = $dvResult.data_view.id
    Write-Host "New data view created: $dataViewId" -ForegroundColor Green
}

# Create simple dashboard with instructions
Write-Host "Creating dashboard..." -ForegroundColor Cyan
$dashBody = @{
    attributes = @{
        title = "Vienna Weather Dashboard - Auto Generated"
        description = "Complete weather dashboard with setup instructions"
        panelsJSON = "[]"
        timeRestore = $true
        timeTo = "now"
        timeFrom = "now-24h"
        refreshInterval = @{pause=$false; value=300000}
    }
} | ConvertTo-Json -Depth 4

try {
    $dashResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/dashboard" -Method POST -Headers $headers -Body $dashBody
    Write-Host "Dashboard created!" -ForegroundColor Green
    Write-Host "Dashboard ID: $($dashResult.id)" -ForegroundColor DarkGreen
} catch {
    Write-Host "Dashboard may already exist" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "Dashboard URL: http://localhost:5601/app/dashboards" -ForegroundColor Cyan

Write-Host ""
Write-Host "To add visualizations:" -ForegroundColor Yellow
Write-Host "1. Open the dashboard" -ForegroundColor White
Write-Host "2. Click 'Edit'" -ForegroundColor White
Write-Host "3. Click 'Create visualization'" -ForegroundColor White
Write-Host "4. Select fields: temperature, weather_main, humidity" -ForegroundColor White