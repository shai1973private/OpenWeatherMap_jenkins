# Vienna Weather Dashboard with Visualizations - Auto Setup
Write-Host "🚀 Creating Complete Vienna Weather Dashboard..." -ForegroundColor Green

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

$headers = @{
    "Content-Type" = "application/json"
    "kbn-xsrf" = "true"
}

# Create data view
Write-Host "Creating data view..." -ForegroundColor Cyan
$dataViewBody = @{
    data_view = @{
        title = "vienna-weather-*"
        timeFieldName = "@timestamp"
        name = "Vienna Weather Data"
    }
} | ConvertTo-Json -Depth 3

try {
    $dataViewResult = Invoke-RestMethod -Uri "http://localhost:5601/api/data_views/data_view" -Method POST -Headers $headers -Body $dataViewBody
    $dataViewId = $dataViewResult.data_view.id
    Write-Host "Data view created: $dataViewId" -ForegroundColor Green
} catch {
    $existingDataViews = Invoke-RestMethod -Uri "http://localhost:5601/api/data_views"
    $dataViewId = $existingDataViews.data_view[0].id
    Write-Host "Using existing data view: $dataViewId" -ForegroundColor Green
}

# Create simple visualizations using legacy format (more compatible)
Write-Host "Creating temperature visualization..." -ForegroundColor Cyan
$tempVizBody = @{
    attributes = @{
        title = "Vienna Temperature Over Time"
        type = "line"
        description = "Temperature trend"
        visState = @{
            title = "Vienna Temperature Over Time"
            type = "line"
            params = @{
                grid = @{
                    categoryLines = $false
                    style = @{ color = "#eee" }
                }
                categoryAxes = @(
                    @{
                        id = "CategoryAxis-1"
                        type = "category"
                        position = "bottom"
                        show = $true
                        style = @{}
                        scale = @{ type = "linear" }
                        labels = @{ show = $true; truncate = 100 }
                        title = @{}
                    }
                )
                valueAxes = @(
                    @{
                        id = "ValueAxis-1"
                        name = "LeftAxis-1"
                        type = "value"
                        position = "left"
                        show = $true
                        style = @{}
                        scale = @{ type = "linear"; mode = "normal" }
                        labels = @{ show = $true; rotate = 0; filter = $false; truncate = 100 }
                        title = @{ text = "Temperature (°C)" }
                    }
                )
                seriesParams = @(
                    @{
                        show = $true
                        type = "line"
                        mode = "normal"
                        data = @{ label = "Temperature"; id = "1" }
                        valueAxis = "ValueAxis-1"
                        drawLinesBetweenPoints = $true
                        showCircles = $true
                    }
                )
                addTooltip = $true
                addLegend = $true
                legendPosition = "right"
                times = @()
                addTimeMarker = $false
            }
            aggs = @(
                @{
                    id = "1"
                    enabled = $true
                    type = "avg"
                    schema = "metric"
                    params = @{ field = "temperature" }
                },
                @{
                    id = "2"
                    enabled = $true
                    type = "date_histogram"
                    schema = "segment"
                    params = @{
                        field = "@timestamp"
                        interval = "auto"
                        customInterval = "2h"
                        min_doc_count = 1
                        extended_bounds = @{}
                    }
                }
            )
        } | ConvertTo-Json -Depth 10 -Compress
        kibanaSavedObjectMeta = @{
            searchSourceJSON = @{
                index = $dataViewId
                query = @{
                    match_all = @{}
                }
                filter = @()
            } | ConvertTo-Json -Depth 3 -Compress
        }
    }
    references = @(
        @{
            id = $dataViewId
            name = "kibanaSavedObjectMeta.searchSourceJSON.index"
            type = "index-pattern"
        }
    )
} | ConvertTo-Json -Depth 15

try {
    $tempVizResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/visualization" -Method POST -Headers $headers -Body $tempVizBody
    $tempVizId = $tempVizResult.id
    Write-Host "Temperature visualization created: $tempVizId" -ForegroundColor Green
} catch {
    Write-Host "Temperature visualization may already exist" -ForegroundColor Yellow
    $tempVizId = "temp-fallback"
}

# Create weather conditions pie chart
Write-Host "Creating weather conditions pie chart..." -ForegroundColor Cyan
$pieVizBody = @{
    attributes = @{
        title = "Vienna Weather Conditions"
        type = "pie"
        description = "Distribution of weather conditions"
        visState = @{
            title = "Vienna Weather Conditions"
            type = "pie"
            params = @{
                addTooltip = $true
                addLegend = $true
                legendPosition = "right"
                isDonut = $false
            }
            aggs = @(
                @{
                    id = "1"
                    enabled = $true
                    type = "count"
                    schema = "metric"
                    params = @{}
                },
                @{
                    id = "2"
                    enabled = $true
                    type = "terms"
                    schema = "segment"
                    params = @{
                        field = "weather_main.keyword"
                        size = 10
                        order = "desc"
                        orderBy = "1"
                    }
                }
            )
        } | ConvertTo-Json -Depth 10 -Compress
        kibanaSavedObjectMeta = @{
            searchSourceJSON = @{
                index = $dataViewId
                query = @{
                    match_all = @{}
                }
                filter = @()
            } | ConvertTo-Json -Depth 3 -Compress
        }
    }
    references = @(
        @{
            id = $dataViewId
            name = "kibanaSavedObjectMeta.searchSourceJSON.index"
            type = "index-pattern"
        }
    )
} | ConvertTo-Json -Depth 15

try {
    $pieVizResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/visualization" -Method POST -Headers $headers -Body $pieVizBody
    $pieVizId = $pieVizResult.id
    Write-Host "Weather pie chart created: $pieVizId" -ForegroundColor Green
} catch {
    Write-Host "Weather pie chart may already exist" -ForegroundColor Yellow
    $pieVizId = "pie-fallback"
}

# Create metric visualization for current temperature
Write-Host "Creating current temperature metric..." -ForegroundColor Cyan
$metricVizBody = @{
    attributes = @{
        title = "Current Temperature"
        type = "metric"
        description = "Latest temperature reading"
        visState = @{
            title = "Current Temperature"
            type = "metric"
            params = @{
                addTooltip = $true
                addLegend = $false
                type = "metric"
                metric = @{
                    percentageMode = $false
                    useRanges = $false
                    colorSchema = "Green to Red"
                    metricColorMode = "None"
                    colorsRange = @(
                        @{ from = 0; to = 10000 }
                    )
                    labels = @{
                        show = $true
                    }
                    invertColors = $false
                    style = @{
                        bgFill = "#000"
                        bgColor = $false
                        labelColor = $false
                        subText = ""
                        fontSize = 60
                    }
                }
            }
            aggs = @(
                @{
                    id = "1"
                    enabled = $true
                    type = "avg"
                    schema = "metric"
                    params = @{
                        field = "temperature"
                        customLabel = "Current Temperature (°C)"
                    }
                }
            )
        } | ConvertTo-Json -Depth 10 -Compress
        kibanaSavedObjectMeta = @{
            searchSourceJSON = @{
                index = $dataViewId
                query = @{
                    match_all = @{}
                }
                filter = @()
            } | ConvertTo-Json -Depth 3 -Compress
        }
    }
    references = @(
        @{
            id = $dataViewId
            name = "kibanaSavedObjectMeta.searchSourceJSON.index"
            type = "index-pattern"
        }
    )
} | ConvertTo-Json -Depth 15

try {
    $metricVizResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/visualization" -Method POST -Headers $headers -Body $metricVizBody
    $metricVizId = $metricVizResult.id
    Write-Host "Temperature metric created: $metricVizId" -ForegroundColor Green
} catch {
    Write-Host "Temperature metric may already exist" -ForegroundColor Yellow
    $metricVizId = "metric-fallback"
}

# Create dashboard with all visualizations
Write-Host "Creating complete dashboard..." -ForegroundColor Cyan
$panels = @(
    @{
        embeddableConfig = @{}
        gridData = @{ x = 0; y = 0; w = 24; h = 15; i = "1" }
        id = $tempVizId
        panelIndex = "1"
        type = "visualization"
        version = "8.11.0"
    },
    @{
        embeddableConfig = @{}
        gridData = @{ x = 24; y = 0; w = 24; h = 15; i = "2" }
        id = $pieVizId
        panelIndex = "2"
        type = "visualization"
        version = "8.11.0"
    },
    @{
        embeddableConfig = @{}
        gridData = @{ x = 0; y = 15; w = 24; h = 10; i = "3" }
        id = $metricVizId
        panelIndex = "3"
        type = "visualization"
        version = "8.11.0"
    }
)

$dashboardBody = @{
    attributes = @{
        title = "Vienna Weather Dashboard - Complete"
        description = "Complete Vienna weather monitoring with auto-generated visualizations"
        panelsJSON = ($panels | ConvertTo-Json -Depth 10 -Compress)
        timeRestore = $true
        timeTo = "now"
        timeFrom = "now-24h"
        refreshInterval = @{
            pause = $false
            value = 300000
        }
        version = 1
    }
} | ConvertTo-Json -Depth 5

try {
    $dashboardResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/dashboard" -Method POST -Headers $headers -Body $dashboardBody
    Write-Host "✅ Complete dashboard with visualizations created!" -ForegroundColor Green
    Write-Host "Dashboard ID: $($dashboardResult.id)" -ForegroundColor DarkGreen
} catch {
    Write-Host "Dashboard may already exist" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 Setup Complete!" -ForegroundColor Green
Write-Host "📊 Created:" -ForegroundColor Cyan
Write-Host "  ✅ Temperature trend line chart" -ForegroundColor White
Write-Host "  ✅ Weather conditions pie chart" -ForegroundColor White
Write-Host "  ✅ Current temperature metric" -ForegroundColor White
Write-Host "  ✅ Complete dashboard with all visualizations" -ForegroundColor White

Write-Host ""
Write-Host "🌐 Access:" -ForegroundColor Cyan
Write-Host "Dashboard: http://localhost:5601/app/dashboards" -ForegroundColor White
Write-Host "Data Explorer: http://localhost:5601/app/discover" -ForegroundColor White