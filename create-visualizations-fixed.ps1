# Fixed Vienna Weather Visualization Creator
# Addresses "Cannot read properties of undefined (reading 'searchSourceJSON')" error

Write-Host "Creating Vienna Weather Visualizations (Fixed Version)..." -ForegroundColor Green

$headers = @{"Content-Type"="application/json"; "kbn-xsrf"="true"}

# Get or create data view first
Write-Host "Step 1: Ensuring data view exists..." -ForegroundColor Yellow
try {
    $dataViews = Invoke-RestMethod -Uri "http://localhost:5601/api/data_views"
    if ($dataViews.data_view.Count -eq 0) {
        # Create data view if it doesn't exist
        $dvBody = @{
            data_view = @{
                title = "vienna-weather-*"
                timeFieldName = "@timestamp" 
                name = "Vienna Weather Data"
            }
        } | ConvertTo-Json -Depth 3
        
        $dvResult = Invoke-RestMethod -Uri "http://localhost:5601/api/data_views/data_view" -Method POST -Headers $headers -Body $dvBody
        $dataViewId = $dvResult.data_view.id
        Write-Host "Data view created: $dataViewId" -ForegroundColor Green
    } else {
        $dataViewId = $dataViews.data_view[0].id
        Write-Host "Using existing data view: $dataViewId" -ForegroundColor Green
    }
} catch {
    Write-Host "Error with data view: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create simple temperature metric (most compatible format)
Write-Host "Step 2: Creating temperature metric..." -ForegroundColor Yellow
$metricViz = @{
    attributes = @{
        title = "Current Vienna Temperature"
        type = "metric"
        visState = @{
            title = "Current Vienna Temperature"
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
                    labels = @{ show = $true }
                    style = @{
                        bgFill = "#000"
                        bgColor = $false
                        labelColor = $false
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
                        customLabel = "Temperature (°C)"
                    }
                }
            )
        } | ConvertTo-Json -Depth 10 -Compress
        kibanaSavedObjectMeta = @{
            searchSourceJSON = @{
                index = $dataViewId
                query = @{ match_all = @{} }
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
    $metricResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/visualization" -Method POST -Headers $headers -Body $metricViz
    Write-Host "Temperature metric created: $($metricResult.id)" -ForegroundColor Green
} catch {
    Write-Host "Temperature metric: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Create simple line chart for temperature trend
Write-Host "Step 3: Creating temperature trend chart..." -ForegroundColor Yellow
$lineViz = @{
    attributes = @{
        title = "Vienna Temperature Trend"
        type = "line"
        visState = @{
            title = "Vienna Temperature Trend"
            type = "line"
            params = @{
                grid = @{ categoryLines = $false; style = @{ color = "#eee" } }
                categoryAxes = @(
                    @{
                        id = "CategoryAxis-1"
                        type = "category"
                        position = "bottom"
                        show = $true
                        style = @{}
                        scale = @{ type = "linear" }
                        labels = @{ show = $true; truncate = 100 }
                        title = @{ text = "Time" }
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
                thresholdLine = @{
                    show = $false
                    value = 10
                    width = 1
                    style = "full"
                    color = "#E7664C"
                }
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
        } | ConvertTo-Json -Depth 15 -Compress
        kibanaSavedObjectMeta = @{
            searchSourceJSON = @{
                index = $dataViewId
                query = @{ match_all = @{} }
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
} | ConvertTo-Json -Depth 20

try {
    $lineResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/visualization" -Method POST -Headers $headers -Body $lineViz
    Write-Host "Temperature trend chart created: $($lineResult.id)" -ForegroundColor Green
} catch {
    Write-Host "Temperature trend: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Create weather conditions pie chart
Write-Host "Step 4: Creating weather conditions pie chart..." -ForegroundColor Yellow
$pieViz = @{
    attributes = @{
        title = "Vienna Weather Conditions"
        type = "pie"
        visState = @{
            title = "Vienna Weather Conditions" 
            type = "pie"
            params = @{
                addTooltip = $true
                addLegend = $true
                legendPosition = "right"
                isDonut = $false
                labels = @{
                    show = $false
                    values = $true
                    last_level = $true
                    truncate = 100
                }
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
                        otherBucket = $false
                        otherBucketLabel = "Other"
                        missingBucket = $false
                        missingBucketLabel = "Missing"
                    }
                }
            )
        } | ConvertTo-Json -Depth 10 -Compress
        kibanaSavedObjectMeta = @{
            searchSourceJSON = @{
                index = $dataViewId
                query = @{ match_all = @{} }
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
    $pieResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/visualization" -Method POST -Headers $headers -Body $pieViz
    Write-Host "Weather conditions pie chart created: $($pieResult.id)" -ForegroundColor Green
} catch {
    Write-Host "Weather pie chart: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Visualization Creation Complete!" -ForegroundColor Green
Write-Host "Created visualizations:" -ForegroundColor Cyan
Write-Host "   Current Vienna Temperature (Metric)" -ForegroundColor White
Write-Host "   Vienna Temperature Trend (Line Chart)" -ForegroundColor White  
Write-Host "   Vienna Weather Conditions (Pie Chart)" -ForegroundColor White

Write-Host ""
Write-Host "🌐 Access your visualizations:" -ForegroundColor Cyan
Write-Host "   • Visualizations: http://localhost:5601/app/visualize" -ForegroundColor White
Write-Host "   • Dashboards: http://localhost:5601/app/dashboards" -ForegroundColor White
Write-Host "   • Data Explorer: http://localhost:5601/app/discover" -ForegroundColor White

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "   1. Go to Dashboards and create/edit a dashboard" -ForegroundColor White
Write-Host "   2. Add the created visualizations to your dashboard" -ForegroundColor White
Write-Host "   3. Arrange and save your Vienna Weather Dashboard" -ForegroundColor White