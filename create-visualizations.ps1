# Create Vienna Weather Visualizations
Write-Host "Creating Vienna Weather Visualizations..." -ForegroundColor Green

$headers = @{"Content-Type"="application/json"; "kbn-xsrf"="true"}

# Get data view ID
$dataViews = Invoke-RestMethod -Uri "http://localhost:5601/api/data_views"
$dataViewId = $dataViews.data_view[0].id
Write-Host "Using data view: $dataViewId" -ForegroundColor Cyan

# Create Temperature Line Chart
Write-Host "Creating temperature trend visualization..." -ForegroundColor Yellow
$tempViz = @{
    attributes = @{
        title = "Vienna Temperature Trend"
        type = "line"
        visState = @{
            title = "Vienna Temperature Trend"
            type = "line"
            params = @{
                grid = @{ categoryLines = $false; style = @{ color = "#eee" } }
                categoryAxes = @(@{
                    id = "CategoryAxis-1"
                    type = "category"
                    position = "bottom"
                    show = $true
                    title = @{ text = "Time" }
                })
                valueAxes = @(@{
                    id = "ValueAxis-1"
                    name = "LeftAxis-1"
                    type = "value"
                    position = "left"
                    show = $true
                    title = @{ text = "Temperature (°C)" }
                })
                seriesParams = @(@{
                    show = $true
                    type = "line"
                    mode = "normal"
                    data = @{ label = "Temperature"; id = "1" }
                    valueAxis = "ValueAxis-1"
                })
                addTooltip = $true
                addLegend = $true
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
                        min_doc_count = 1
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
    references = @(@{
        id = $dataViewId
        name = "kibanaSavedObjectMeta.searchSourceJSON.index"
        type = "index-pattern"
    })
} | ConvertTo-Json -Depth 15

try {
    $tempResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/visualization" -Method POST -Headers $headers -Body $tempViz
    Write-Host "Temperature visualization created: $($tempResult.id)" -ForegroundColor Green
} catch {
    Write-Host "Temperature visualization may already exist" -ForegroundColor Yellow
}

# Create Weather Conditions Pie Chart
Write-Host "Creating weather conditions pie chart..." -ForegroundColor Yellow
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
                query = @{ match_all = @{} }
                filter = @()
            } | ConvertTo-Json -Depth 3 -Compress
        }
    }
    references = @(@{
        id = $dataViewId
        name = "kibanaSavedObjectMeta.searchSourceJSON.index"
        type = "index-pattern"
    })
} | ConvertTo-Json -Depth 15

try {
    $pieResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/visualization" -Method POST -Headers $headers -Body $pieViz
    Write-Host "Weather conditions pie chart created: $($pieResult.id)" -ForegroundColor Green
} catch {
    Write-Host "Weather pie chart may already exist" -ForegroundColor Yellow
}

# Create Current Temperature Metric
Write-Host "Creating current temperature metric..." -ForegroundColor Yellow
$metricViz = @{
    attributes = @{
        title = "Current Temperature"
        type = "metric"
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
                    labels = @{ show = $true }
                    style = @{
                        bgFill = "#000"
                        bgColor = $false
                        labelColor = $false
                        fontSize = 60
                    }
                }
            }
            aggs = @(@{
                id = "1"
                enabled = $true
                type = "avg"
                schema = "metric"
                params = @{
                    field = "temperature"
                    customLabel = "Current Temperature (°C)"
                }
            })
        } | ConvertTo-Json -Depth 10 -Compress
        kibanaSavedObjectMeta = @{
            searchSourceJSON = @{
                index = $dataViewId
                query = @{ match_all = @{} }
                filter = @()
            } | ConvertTo-Json -Depth 3 -Compress
        }
    }
    references = @(@{
        id = $dataViewId
        name = "kibanaSavedObjectMeta.searchSourceJSON.index"
        type = "index-pattern"
    })
} | ConvertTo-Json -Depth 15

try {
    $metricResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/visualization" -Method POST -Headers $headers -Body $metricViz
    Write-Host "Temperature metric created: $($metricResult.id)" -ForegroundColor Green
} catch {
    Write-Host "Temperature metric may already exist" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Visualization Creation Complete!" -ForegroundColor Green
Write-Host "Created visualizations:" -ForegroundColor Cyan
Write-Host "  - Vienna Temperature Trend (Line Chart)" -ForegroundColor White
Write-Host "  - Vienna Weather Conditions (Pie Chart)" -ForegroundColor White
Write-Host "  - Current Temperature (Metric)" -ForegroundColor White

Write-Host ""
Write-Host "Access at: http://localhost:5601/app/visualize" -ForegroundColor Cyan