# Vienna Weather Monitoring System - Setup Script
# This script sets up the environment and installs all dependencies

Write-Host "Vienna Weather Monitoring System - Environment Setup" -ForegroundColor Green
Write-Host "=" * 60

# Check Python installation
Write-Host "Checking Python installation..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "SUCCESS: $pythonVersion found" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Python not found. Please install Python 3.8+ first." -ForegroundColor Red
    exit 1
}

# Check if virtual environment exists
Write-Host "Checking virtual environment..." -ForegroundColor Yellow
if (Test-Path ".venv") {
    Write-Host "SUCCESS: Virtual environment found" -ForegroundColor Green
    Write-Host "Activating virtual environment..." -ForegroundColor Yellow
    & ".venv\Scripts\Activate.ps1"
} else {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv .venv
    Write-Host "Activating virtual environment..." -ForegroundColor Yellow
    & ".venv\Scripts\Activate.ps1"
}

# Install Python dependencies
Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
if (Test-Path "requirements.txt") {
    pip install -r requirements.txt
    Write-Host "SUCCESS: Python dependencies installed" -ForegroundColor Green
} else {
    Write-Host "WARNING: requirements.txt not found, installing core packages..." -ForegroundColor Yellow
    pip install requests pika elasticsearch
}

# Check Docker installation
Write-Host "Checking Docker installation..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version 2>&1
    Write-Host "SUCCESS: $dockerVersion found" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Docker not found. Please install Docker Desktop first." -ForegroundColor Red
    Write-Host "Download from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

# Check if Docker is running
Write-Host "Checking if Docker is running..." -ForegroundColor Yellow
try {
    docker ps | Out-Null
    Write-Host "SUCCESS: Docker is running" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Environment Setup Complete!" -ForegroundColor Green
Write-Host "=" * 60
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run the CI/CD pipeline: python simple-pipeline.py" -ForegroundColor White
Write-Host "  2. Or setup ELK stack manually: .\setup-elk-simple.ps1" -ForegroundColor White
Write-Host "  3. Start weather monitoring: python weather_auto_rabbitmq.py" -ForegroundColor White
Write-Host ""