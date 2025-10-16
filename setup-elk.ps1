# Stop and remove existing containers
Write-Host "🛑 Stopping existing containers..." -ForegroundColor Yellow
docker-compose down

# Start the ELK stack
Write-Host "Starting ELK Stack with RabbitMQ..." -ForegroundColor Green
docker-compose up -d

Write-Host "⏳ Waiting for services to start..." -ForegroundColor Cyan
Start-Sleep -Seconds 45

# Check if services are running
Write-Host "🔍 Checking service status..." -ForegroundColor Cyan

Write-Host "Checking Elasticsearch..." -ForegroundColor Yellow
try {
    $null = Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health" -Method Get -TimeoutSec 10 -ErrorAction SilentlyContinue
    Write-Host "Elasticsearch is running on http://localhost:9200" -ForegroundColor Green
} catch {
    Write-Host "Elasticsearch is not responding: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Checking Kibana..." -ForegroundColor Yellow
try {
    $null = Invoke-RestMethod -Uri "http://localhost:5601/api/status" -Method Get -TimeoutSec 10 -ErrorAction SilentlyContinue
    Write-Host "Kibana is running on http://localhost:5601" -ForegroundColor Green
} catch {
    Write-Host "Kibana is not responding: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Checking RabbitMQ..." -ForegroundColor Yellow
try {
    $null = Invoke-WebRequest -Uri "http://localhost:15672" -Method Get -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue -NoProxy
    Write-Host "RabbitMQ Management is running on http://localhost:15672" -ForegroundColor Green
} catch {
    Write-Host "RabbitMQ Management is not responding: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "ELK Stack Setup Complete!" -ForegroundColor Green
Write-Host "=============================="
Write-Host "Services:"
Write-Host "   • Elasticsearch: http://localhost:9200" -ForegroundColor White
Write-Host "   • Kibana: http://localhost:5601" -ForegroundColor White
Write-Host "   • RabbitMQ Management: http://localhost:15672 (guest/guest)" -ForegroundColor White
Write-Host "   • Logstash: Processing on port 5044" -ForegroundColor White
Write-Host ""
Write-Host "� Setting up Kibana index pattern automatically..." -ForegroundColor Cyan
& "C:/Users/ShaiAm/OneDrive - AMDOCS/Backup Folders/Desktop/עבודה/OpenWeatherMap/.venv/Scripts/python.exe" "setup_kibana_auto.py"
Write-Host ""
Write-Host "�🔄 Next Steps:"
Write-Host "   1. Your weather monitoring script should be running" -ForegroundColor Yellow
Write-Host "   2. Open Kibana at http://localhost:5601" -ForegroundColor Yellow
Write-Host "   3. Index pattern 'vienna-weather-*' is ready to use" -ForegroundColor Yellow
Write-Host "   4. Check 'Discover' tab to see weather data" -ForegroundColor Yellow
Write-Host ""