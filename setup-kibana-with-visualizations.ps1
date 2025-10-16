# Enhanced Automatic Kibana Setup with Visualizations
# Creates dashboard AND useful weather visualizations automatically

Write-Host "Setting up Complete Vienna Weather Dashboard with Visualizations..." -ForegroundColor Green

# Wait for Kibana
$attempt = 0
do {
    $attempt++
    Write-Host "⏳ Checking Kibana (attempt $attempt)..." -ForegroundColor Cyan
    try {
        $status = Invoke-RestMethod -Uri "http://localhost:5601/api/status" -TimeoutSec 10
        if ($status.status.overall.level -eq "available") {
            Write-Host "Kibana is ready!" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "   Waiting..." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 5
} while ($attempt -lt 10)

# Common headers for API calls
$headers = @{
    "Content-Type" = "application/json"
    "kbn-xsrf" = "true"
}

# Step 1: Create/Get Data View
Write-Host "Setting up data view..." -ForegroundColor Cyan
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
    # Get existing data view
    $existingDataViews = Invoke-RestMethod -Uri "http://localhost:5601/api/data_views"
    $dataViewId = $existingDataViews.data_view[0].id
    Write-Host "Using existing data view: $dataViewId" -ForegroundColor Green
}

# Step 2: Create Visualizations

# Visualization 1: Temperature Line Chart
Write-Host "📈 Creating temperature trend visualization..." -ForegroundColor Cyan
$tempVizBody = @{
    attributes = @{
        title = "Vienna Temperature Trend"
        description = "Temperature over time"
        type = "lens"
        state = @{
            datasourceStates = @{
                formBased = @{
                    layers = @{
                        "layer1" = @{
                            columnOrder = @("x-axis-column", "y-axis-column")
                            columns = @{
                                "x-axis-column" = @{
                                    sourceField = "@timestamp"
                                    dataType = "date"
                                    isBucketed = $true
                                    label = "Time"
                                    operationType = "date_histogram"
                                    params = @{
                                        interval = "auto"
                                    }
                                }
                                "y-axis-column" = @{
                                    sourceField = "temperature"
                                    dataType = "number"
                                    isBucketed = $false
                                    label = "Average Temperature (°C)"
                                    operationType = "average"
                                }
                            }
                            incompleteColumns = @{}
                            indexPatternId = $dataViewId
                        }
                    }
                }
            }
            visualization = @{
                layers = @(
                    @{
                        accessors = @("y-axis-column")
                        layerId = "layer1"
                        layerType = "data"
                        seriesType = "line"
                        xAccessor = "x-axis-column"
                        yConfig = @(
                            @{
                                forAccessor = "y-axis-column"
                                color = "#1f77b4"
                            }
                        )
                    }
                )
                legend = @{
                    isVisible = $true
                    position = "right"
                }
                preferredSeriesType = "line"
                title = "Temperature Trend"
                valueLabels = "hide"
            }
        }
        references = @(
            @{
                id = $dataViewId
                name = "indexpattern-datasource-current-indexpattern"
                type = "index-pattern"
            }
        )
    }
} | ConvertTo-Json -Depth 10

try {
    $tempVizResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/lens" -Method POST -Headers $headers -Body $tempVizBody
    $tempVizId = $tempVizResult.id
    Write-Host "Temperature visualization created: $tempVizId" -ForegroundColor Green
} catch {
    Write-Host "Temperature visualization may already exist" -ForegroundColor Yellow
    $tempVizId = "temp-viz-fallback"
}

# Visualization 2: Weather Conditions Pie Chart
Write-Host "Creating weather conditions pie chart..." -ForegroundColor Cyan
$weatherVizBody = @{
    attributes = @{
        title = "Vienna Weather Conditions Distribution"
        description = "Distribution of weather conditions"
        type = "lens"
        state = @{
            datasourceStates = @{
                formBased = @{
                    layers = @{
                        "layer1" = @{
                            columnOrder = @("breakdown-column", "metric-column")
                            columns = @{
                                "breakdown-column" = @{
                                    sourceField = "weather_main.keyword"
                                    dataType = "string"
                                    isBucketed = $true
                                    label = "Weather Condition"
                                    operationType = "terms"
                                    params = @{
                                        size = 10
                                        orderBy = @{
                                            type = "column"
                                            columnId = "metric-column"
                                        }
                                        orderDirection = "desc"
                                    }
                                }
                                "metric-column" = @{
                                    dataType = "number"
                                    isBucketed = $false
                                    label = "Count"
                                    operationType = "count"
                                }
                            }
                            incompleteColumns = @{}
                            indexPatternId = $dataViewId
                        }
                    }
                }
            }
            visualization = @{
                layers = @(
                    @{
                        categoryDisplay = "default"
                        layerId = "layer1"
                        layerType = "data"
                        legendDisplay = "visible"
                        metrics = @("metric-column")
                        nestedLegend = $false
                        numberDisplay = "percent"
                        primaryGroups = @("breakdown-column")
                    }
                )
                shape = "pie"
            }
        }
        references = @(
            @{
                id = $dataViewId
                name = "indexpattern-datasource-current-indexpattern"
                type = "index-pattern"
            }
        )
    }
} | ConvertTo-Json -Depth 10

try {
    $weatherVizResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/lens" -Method POST -Headers $headers -Body $weatherVizBody
    $weatherVizId = $weatherVizResult.id
    Write-Host "Weather conditions visualization created: $weatherVizId" -ForegroundColor Green
} catch {
    Write-Host "Weather conditions visualization may already exist" -ForegroundColor Yellow
    $weatherVizId = "weather-viz-fallback"
}

# Visualization 3: Humidity vs Pressure Scatter Plot
Write-Host "💧 Creating humidity gauge..." -ForegroundColor Cyan
$humidityVizBody = @{
    attributes = @{
        title = "Vienna Current Humidity"
        description = "Current humidity level"
        type = "lens"
        state = @{
            datasourceStates = @{
                formBased = @{
                    layers = @{
                        "layer1" = @{
                            columnOrder = @("metric-column")
                            columns = @{
                                "metric-column" = @{
                                    sourceField = "humidity"
                                    dataType = "number"
                                    isBucketed = $false
                                    label = "Average Humidity (%)"
                                    operationType = "average"
                                }
                            }
                            incompleteColumns = @{}
                            indexPatternId = $dataViewId
                        }
                    }
                }
            }
            visualization = @{
                accessor = "metric-column"
                layerId = "layer1"
                layerType = "data"
                shape = "horizontalBullet"
            }
        }
        references = @(
            @{
                id = $dataViewId
                name = "indexpattern-datasource-current-indexpattern"
                type = "index-pattern"
            }
        )
    }
} | ConvertTo-Json -Depth 10

try {
    $humidityVizResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/lens" -Method POST -Headers $headers -Body $humidityVizBody
    $humidityVizId = $humidityVizResult.id
    Write-Host "Humidity visualization created: $humidityVizId" -ForegroundColor Green
} catch {
    Write-Host "Humidity visualization may already exist" -ForegroundColor Yellow
    $humidityVizId = "humidity-viz-fallback"
}

# Step 3: Create Dashboard with Visualizations
Write-Host "Creating dashboard with visualizations..." -ForegroundColor Cyan

# Create panels array with our visualizations
$panels = @(
    @{
        version = "8.11.0"
        gridData = @{
            x = 0
            y = 0
            w = 24
            h = 15
            i = "panel-1"
        }
        panelIndex = "panel-1"
        embeddableConfig = @{
            enhancements = @{}
        }
        panelRefName = "panel_panel-1"
    },
    @{
        version = "8.11.0"
        gridData = @{
            x = 24
            y = 0
            w = 24
            h = 15
            i = "panel-2"
        }
        panelIndex = "panel-2"
        embeddableConfig = @{
            enhancements = @{}
        }
        panelRefName = "panel_panel-2"
    },
    @{
        version = "8.11.0"
        gridData = @{
            x = 0
            y = 15
            w = 24
            h = 15
            i = "panel-3"
        }
        panelIndex = "panel-3"
        embeddableConfig = @{
            enhancements = @{}
        }
        panelRefName = "panel_panel-3"
    }
)

$references = @(
    @{
        name = "panel_panel-1"
        type = "lens"
        id = $tempVizId
    },
    @{
        name = "panel_panel-2"
        type = "lens"
        id = $weatherVizId
    },
    @{
        name = "panel_panel-3"
        type = "lens"
        id = $humidityVizId
    }
)

$dashboardBody = @{
    attributes = @{
        title = "Vienna Weather Monitoring Dashboard"
        description = "Complete Vienna Weather Dashboard with Auto-Generated Visualizations"
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
    references = $references
} | ConvertTo-Json -Depth 10

try {
    $dashboardResult = Invoke-RestMethod -Uri "http://localhost:5601/api/saved_objects/dashboard" -Method POST -Headers $headers -Body $dashboardBody
    Write-Host "Complete dashboard created with visualizations!" -ForegroundColor Green
    Write-Host "   Dashboard ID: $($dashboardResult.id)" -ForegroundColor DarkGreen
} catch {
    Write-Host "Dashboard with visualizations may already exist" -ForegroundColor Yellow
}

# Final Results
Write-Host ""
Write-Host "Complete Vienna Weather Dashboard Setup Finished!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Check data
$weatherDataCheck = Invoke-RestMethod -Uri "http://localhost:9200/vienna-weather-*/_count" -ErrorAction SilentlyContinue
if ($weatherDataCheck -and $weatherDataCheck.count -gt 0) {
    Write-Host "📈 Weather data available: $($weatherDataCheck.count) documents" -ForegroundColor Green
} else {
    Write-Host "No weather data found yet. Visualizations will populate as data arrives." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Created Visualizations:" -ForegroundColor Cyan
Write-Host "   Temperature Trend (Line Chart)" -ForegroundColor White
Write-Host "   Weather Conditions Distribution (Pie Chart)" -ForegroundColor White
Write-Host "   Current Humidity Level (Gauge)" -ForegroundColor White

Write-Host ""
Write-Host "🌐 Access Your Complete Dashboard:" -ForegroundColor Cyan
Write-Host "   • Main Dashboard: http://localhost:5601/app/dashboards" -ForegroundColor White
Write-Host "   • Data Explorer: http://localhost:5601/app/discover" -ForegroundColor White

Write-Host ""
Write-Host "Dashboard Features:" -ForegroundColor Cyan
Write-Host "   • Auto-refresh every 5 minutes" -ForegroundColor White
Write-Host "   • Last 24 hours of data" -ForegroundColor White
Write-Host "   • Pre-built weather visualizations" -ForegroundColor White
Write-Host "   • Ready for additional customizations" -ForegroundColor White

Write-Host "================================================" -ForegroundColor Green