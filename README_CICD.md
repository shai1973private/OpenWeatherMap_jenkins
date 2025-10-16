# 🚀 Vienna Weather Python Pipeline Guide

## Overview
This project provides a simple Python-based CI/CD pipeline for the Vienna Weather monitoring system with comprehensive notification system.

## Available Pipeline Options

### 1. Python Pipeline (`pipeline.py`)
- **Description**: Comprehensive Python-based CI/CD pipeline
- **Features**: Full stage implementation (clone, build, unittest, deploy)
- **Notifications**: Sends pipeline status to Elasticsearch/Kibana
- **Usage**: `python pipeline.py`

### 2. Pipeline Manager (`pipeline-manager.py`)
- **Description**: Simplified pipeline runner
- **Features**: Direct pipeline execution with notifications
- **Usage**: `python pipeline-manager.py`

## Quick Start

### Option 1: Using the Batch Runner
```bash
run-pipeline.bat
```

### Option 2: Direct Pipeline Execution
```bash
# Python pipeline
python pipeline.py

# Pipeline manager
python pipeline-manager.py
```

## Pipeline Stages

The Python pipeline implements these four core stages:

### 1. Clone Stage
- ✅ Project structure validation
- ✅ Source code management
- ✅ Dependency verification

### 2. Build Stage
- ✅ Python environment setup
- ✅ Dependency installation
- ✅ Docker container preparation
- ✅ ELK stack verification

### 3. Unit Test Stage
- ✅ Configuration validation
- ✅ API connectivity testing
- ✅ Data format validation
- ✅ Service health checks
- ✅ File structure validation

### 4. Deploy Stage
- ✅ ELK stack deployment
- ✅ Service verification
- ✅ Dashboard availability check
- ✅ Data pipeline validation

## Configuration

### Pipeline Configuration (`pipeline-config.json`)
```json
{
  "elasticsearch_url": "http://localhost:9200",
  "kibana_url": "http://localhost:5601",
  "environment": "development",
  "notification_index": "pipeline-notifications"
}
```

### Jenkins Job Configuration
- **Job Name**: `vienna-weather-pipeline`
- **Type**: Pipeline
- **SCM**: Git
- **Script Path**: `Jenkinsfile`
- **Triggers**: SCM polling, scheduled builds

## Notification System

### Elasticsearch Integration
All pipelines send notifications to Elasticsearch with:
- Pipeline execution status
- Stage-by-stage results
- Timing information
- Error details (if any)
- Environment information

### Kibana Dashboard
Monitor pipeline activity through:
- Index: `vienna-pipeline-notifications`
- Dashboard: Available in Kibana
- Real-time pipeline status tracking

## Prerequisites

### Required Software
- **Python 3.12+**: Core pipeline execution
- **Docker**: ELK stack deployment

### Required Python Packages
```bash
pip install requests pika python-dotenv elasticsearch
```

### Required Services
- **Elasticsearch**: Data storage and indexing
- **Logstash**: Data processing pipeline
- **Kibana**: Visualization and monitoring
- **RabbitMQ**: Message queuing

## File Structure
```
vienna-weather/
├── weather_auto_rabbitmq.py    # Main weather collection app
├── docker-compose.yml          # ELK stack configuration
├── pipeline.py                 # Python CI/CD pipeline
├── pipeline-manager.py         # Simplified pipeline manager
├── run-pipeline.bat           # Interactive pipeline runner
├── pipeline-config.json       # Pipeline configuration
├── logstash/pipeline/          # Logstash configuration
└── README_CICD.md             # This documentation
```

## Usage Examples

### Basic Pipeline Execution
```bash
# Run Python pipeline with default settings
python pipeline.py

# Run pipeline manager (simplified)
python pipeline-manager.py

# Run using batch file
run-pipeline.bat
```

## Monitoring and Troubleshooting

### Pipeline Logs
- **Location**: Elasticsearch index `vienna-pipeline-notifications`
- **Access**: Via Kibana dashboard
- **Format**: JSON with structured logging

### Common Issues
1. **Docker not running**: Ensure Docker Desktop is started
2. **Port conflicts**: Check ports 9200, 5601, 5672, 15672
3. **Python dependencies**: Run `pip install -r requirements.txt`

### Health Checks
```bash
# Check all services
docker-compose ps

# Test Elasticsearch
curl http://localhost:9200/_cluster/health

# Test Kibana
curl http://localhost:5601/api/status

# Run pipeline
python pipeline-manager.py
```

## Advanced Configuration

### Custom Notification Endpoints
Update `pipeline-config.json`:
```json
{
  "elasticsearch_url": "http://your-elk-cluster:9200",
  "kibana_url": "http://your-kibana:5601",
  "environment": "production",
  "notification_index": "prod-pipeline-notifications"
}
```

## Support and Contributing

For issues or enhancements:
1. Check pipeline logs in Kibana
2. Run system status check
3. Review configuration settings
4. Submit detailed issue reports

## License
This project is part of the Vienna Weather monitoring system.