# Vienna Weather Monitoring System

## 🌤️ Overview
Real-time weather monitoring system for Vienna, Austria using OpenWeatherMap API, RabbitMQ messaging, and ELK stack for data visualization.

## 🏗️ Architecture
```
OpenWeatherMap API → weather_auto_rabbitmq.py → RabbitMQ → Logstash → Elasticsearch → Kibana
```

## 📋 Essential Files

### Core Application
- `weather_auto_rabbitmq.py` - Main weather monitoring script
- `vienna_weather_log.json` - Local weather data backup

### Infrastructure
- `docker-compose.yml` - ELK stack (Elasticsearch, Logstash, Kibana) + RabbitMQ
- `setup-elk.ps1` - ELK stack setup script
- `logstash/` - Logstash configuration directory

## 🚀 Quick Start

### 1. Start ELK Stack
```powershell
.\setup-elk.ps1
```

### 2. Run Weather Monitoring
```powershell
python weather_auto_rabbitmq.py
```

### 3. Access Dashboards
- **Today's Weather**: http://localhost:5601/app/dashboards#/view/vienna-today-start-to-now
- **User Friendly**: http://localhost:5601/app/dashboards#/view/vienna-weather-friendly

## 📊 Data Flow
1. **Collection**: Hourly weather data from OpenWeatherMap API
2. **Messaging**: Data sent to RabbitMQ queue
3. **Processing**: Logstash processes and indexes to Elasticsearch
4. **Visualization**: Kibana dashboards display real-time weather trends

## 🔧 Configuration
- **API Key**: 7ea63a60ef095d75baf077171165c148
- **Location**: Vienna, Austria (48.2085, 16.3721)
- **Update Frequency**: Every hour
- **Data Retention**: Elasticsearch indexes by date

## 📈 Dashboards
- **Vienna Weather - Today**: Time-series view of today's weather progression
- **Vienna Weather - User Friendly**: Simple cards with current weather data

## 🛠️ Maintenance
- **ELK Stack**: Managed via Docker Compose
- **Data Collection**: Automated via weather_auto_rabbitmq.py
- **Monitoring**: Check Kibana dashboards for data flow

## 📝 Notes
- System automatically handles Docker container management
- Weather data backed up locally in JSON format
- Millisecond precision timestamps for accurate data tracking
