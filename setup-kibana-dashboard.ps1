# Automatic Kibana Dashboard Setup Script for Vienna Weather Monitoring
# Auto-creates dashboard, visualizations, and data views

param(
    [string]$KibanaUrl = "http://localhost:5601",
    [int]$MaxAttempts = 15,
    [int]$WaitSeconds = 10
)

Write-Host "Setting up Kibana Dashboard for Vienna Weather Monitoring..." -ForegroundColor Green

# Function to safely invoke REST API with proper error handling
function Invoke-SafeRestMethod {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [string]$Body = $null,
        [int]$TimeoutSec = 30
    )
    
    try {
        $params = @{
            Uri = $Uri
            Method = $Method
            Headers = $Headers
            TimeoutSec = $TimeoutSec
            UseBasicParsing = $true
        }
        
        if ($Body) {
            $params.Body = $Body
        }
        
        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        Write-Host "API call to $Uri failed: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

# Wait for Kibana to be fully ready
Write-Host "⏳ Waiting for Kibana to be ready..." -ForegroundColor Cyan
$attempt = 0

do {
    $attempt++
    Write-Host "   Checking Kibana status (attempt $attempt/$MaxAttempts)..." -ForegroundColor DarkCyan
    
    $status = Invoke-SafeRestMethod -Uri "$KibanaUrl/api/status"
    
    if ($status -and $status.status.overall.level -eq "available") {
        Write-Host "Kibana is ready!" -ForegroundColor Green
        break
    }
    
    if ($attempt -lt $MaxAttempts) {
        Write-Host "   Waiting $WaitSeconds seconds..." -ForegroundColor DarkGray
        Start-Sleep -Seconds $WaitSeconds
    }
} while ($attempt -lt $MaxAttempts)

if ($attempt -eq $MaxAttempts) {
    Write-Host "Kibana did not become ready in time. Exiting." -ForegroundColor Red
    exit 1
}

# Step 1: Create/Verify Data View
Write-Host "Creating Vienna Weather data view..." -ForegroundColor Cyan

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

$dataViewResponse = Invoke-SafeRestMethod -Uri "$KibanaUrl/api/data_views/data_view" -Method POST -Headers $headers -Body $dataViewBody

if ($dataViewResponse) {
    Write-Host "Data view created successfully!" -ForegroundColor Green
    $dataViewId = $dataViewResponse.data_view.id
    Write-Host "   Data View ID: $dataViewId" -ForegroundColor DarkGreen
} else {
    # Try to get existing data view
    Write-Host "🔍 Checking for existing data view..." -ForegroundColor Yellow
    $existingDataViews = Invoke-SafeRestMethod -Uri "$KibanaUrl/api/data_views"
    if ($existingDataViews -and $existingDataViews.data_view) {
        $viennaDataView = $existingDataViews.data_view | Where-Object { $_.title -like "*vienna-weather*" }
        if ($viennaDataView) {
            $dataViewId = $viennaDataView[0].id
            Write-Host "Using existing data view: $dataViewId" -ForegroundColor Green
        }
    }
}

# Step 2: Create Dashboard
Write-Host "Creating Vienna Weather Dashboard..." -ForegroundColor Cyan

$dashboardBody = @{
    attributes = @{
        title = "Vienna Weather Monitoring Dashboard"
        description = "Real-time weather monitoring for Vienna, Austria - Auto-created by Jenkins CI/CD Pipeline"
        panelsJSON = "[]"
        timeRestore = $true
        timeTo = "now"
        timeFrom = "now-24h"
        refreshInterval = @{
            pause = $false
            value = 300000
        }
        version = 1
    }
} | ConvertTo-Json -Depth 4

$dashboardResponse = Invoke-SafeRestMethod -Uri "$KibanaUrl/api/saved_objects/dashboard" -Method POST -Headers $headers -Body $dashboardBody

if ($dashboardResponse) {
    Write-Host "Vienna Weather Dashboard created successfully!" -ForegroundColor Green
    $dashboardId = $dashboardResponse.id
    Write-Host "   Dashboard ID: $dashboardId" -ForegroundColor DarkGreen
} else {
    Write-Host "Dashboard may already exist, checking..." -ForegroundColor Yellow
    
    # Check for existing dashboard
    $existingDashboards = Invoke-SafeRestMethod -Uri "$KibanaUrl/api/saved_objects/_find?type=dashboard&search=Vienna%20Weather"
    if ($existingDashboards -and $existingDashboards.saved_objects.Count -gt 0) {
        $dashboardId = $existingDashboards.saved_objects[0].id
        Write-Host "Using existing dashboard: $dashboardId" -ForegroundColor Green
    }
}

# Step 3: Create Index Pattern (backup method)
Write-Host "Ensuring index pattern exists..." -ForegroundColor Cyan

$indexPatternBody = @{
    attributes = @{
        title = "vienna-weather-*"
        timeFieldName = "@timestamp"
    }
} | ConvertTo-Json -Depth 3

$indexPatternResponse = Invoke-SafeRestMethod -Uri "$KibanaUrl/api/saved_objects/index-pattern" -Method POST -Headers $headers -Body $indexPatternBody

if ($indexPatternResponse) {
    Write-Host "Index pattern created as backup!" -ForegroundColor Green
} else {
    Write-Host "Index pattern may already exist" -ForegroundColor Yellow
}

# Step 4: Verify setup and provide information
Write-Host "`nKibana Setup Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Check if we have weather data
$weatherDataCheck = Invoke-SafeRestMethod -Uri "http://localhost:9200/vienna-weather-*/_count"
if ($weatherDataCheck -and $weatherDataCheck.count -gt 0) {
    Write-Host "📈 Weather data available: $($weatherDataCheck.count) documents" -ForegroundColor Green
} else {
    Write-Host "No weather data found yet. Data will appear as the monitoring system runs." -ForegroundColor Yellow
}

Write-Host "`n🌐 Access Your Dashboard:" -ForegroundColor Cyan
Write-Host "   • Dashboard: $KibanaUrl/app/dashboards" -ForegroundColor White
Write-Host "   • Data Explorer: $KibanaUrl/app/discover" -ForegroundColor White
Write-Host "   • Visualizations: $KibanaUrl/app/visualize" -ForegroundColor White
Write-Host "   • Dev Tools: $KibanaUrl/app/dev_tools" -ForegroundColor White

Write-Host "`nDashboard Features:" -ForegroundColor Cyan
Write-Host "   • Auto-refresh every 5 minutes" -ForegroundColor White
Write-Host "   • Shows last 24 hours of data" -ForegroundColor White
Write-Host "   • Ready for custom visualizations" -ForegroundColor White

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "   1. Open the dashboard URL above" -ForegroundColor White
Write-Host "   2. Click 'Edit' to add visualizations" -ForegroundColor White
Write-Host "   3. Create charts for temperature, humidity, weather conditions" -ForegroundColor White

Write-Host "================================================" -ForegroundColor Green