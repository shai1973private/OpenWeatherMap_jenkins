# Simple ELK Stack Setup - Non-Interactive Version
# Stop and remove existing containers
Write-Host "Stopping existing containers..." -ForegroundColor Yellow
docker-compose down

# Start the ELK stack
Write-Host "Starting ELK Stack with RabbitMQ..." -ForegroundColor Green
docker-compose up -d

Write-Host "Waiting for services to start..." -ForegroundColor Cyan
Start-Sleep -Seconds 45

# Check if services are running
Write-Host "Checking service status..." -ForegroundColor Cyan

Write-Host "Checking Elasticsearch..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health" -Method Get -TimeoutSec 10 -ErrorAction SilentlyContinue
    Write-Host "SUCCESS: Elasticsearch is running on http://localhost:9200" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Elasticsearch not responding" -ForegroundColor Red
}

Write-Host "Checking Kibana..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:5601/api/status" -Method Get -TimeoutSec 10 -ErrorAction SilentlyContinue
    Write-Host "SUCCESS: Kibana is running on http://localhost:5601" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Kibana not responding" -ForegroundColor Red
}

Write-Host "Checking RabbitMQ..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:15672" -Method Get -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue
    Write-Host "SUCCESS: RabbitMQ Management is running on http://localhost:15672" -ForegroundColor Green
} catch {
    Write-Host "WARNING: RabbitMQ Management not responding" -ForegroundColor Red
}

Write-Host ""
Write-Host "ELK Stack Setup Complete!" -ForegroundColor Green
Write-Host "=============================="
Write-Host "Services:"
Write-Host "  Elasticsearch: http://localhost:9200" -ForegroundColor White
Write-Host "  Kibana: http://localhost:5601" -ForegroundColor White
Write-Host "  RabbitMQ Management: http://localhost:15672" -ForegroundColor White
Write-Host "  Logstash: Processing on port 5044" -ForegroundColor White
Write-Host ""