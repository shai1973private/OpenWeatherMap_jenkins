# Vienna Weather ELK Stack with Millisecond Precision

Complete setup for monitoring Vienna weather with ELK Stack (Elasticsearch, Logstash, Kibana) and RabbitMQ, featuring millisecond precision timestamps for detailed performance analysis.

## 🏗️ **Architecture Overview**

```
Weather API → Python Script → RabbitMQ → Logstash → Elasticsearch ← Kibana
                     ↓
               Local JSON Backup
```

## 📦 **Components**

### **Data Flow:**
1. **Weather Script** (`weather_auto_rabbitmq.py`) fetches Vienna weather hourly
2. **RabbitMQ** queues weather messages with millisecond timestamps
3. **Logstash** processes messages and enriches data
4. **Elasticsearch** stores structured weather data with full-text search
5. **Kibana** provides dashboards and visualizations

### **Timestamp Precision:**
- **weather_check_time_ms**: Exact moment of weather check (Unix timestamp in milliseconds)
- **timestamp**: ISO 8601 format with millisecond precision
- **processed_at**: When Logstash processed the message
- **processing_delay_ms**: Delay between weather check and processing

## 🚀 **Quick Start**

### **1. Start the ELK Stack**
```powershell
# Using PowerShell script
.\setup-elk.ps1

# Or manually with Docker Compose
docker-compose up -d
```

### **2. Run Weather Monitoring**
```powershell
&"C:/Users/ShaiAm/OneDrive - AMDOCS/Backup Folders/Desktop/עבודה/OpenWeatherMap/.venv/Scripts/python.exe" "weather_auto_rabbitmq.py"
```

### **3. Access Services**
- **Kibana**: http://localhost:5601
- **Elasticsearch**: http://localhost:9200
- **RabbitMQ Management**: http://localhost:15672 (guest/guest)

## 📊 **Data Structure in Elasticsearch**

### **Index Pattern**: `vienna-weather-YYYY.MM.dd`

### **Key Fields with Millisecond Precision:**
```json
{
  "@timestamp": "2025-10-16T10:43:26.123Z",
  "timestamp": "2025-10-16T10:43:26.123Z",
  "weather_check_time_ms": 1729078406123,
  "processed_at": "2025-10-16T10:43:26.456Z",
  "processing_delay_ms": 333.0,
  "temperature": 11.04,
  "feels_like": 10.31,
  "humidity": 81,
  "pressure": 1024,
  "wind_speed": 1.03,
  "wind_direction": 180,
  "cloudiness": 0,
  "visibility_km": 10.0,
  "weather_condition": "Clear",
  "weather_description": "clear sky",
  "location": {
    "lat": 48.2082,
    "lon": 16.3738
  },
  "hour_of_day": 10,
  "heat_index": 23.45
}
```

## 📈 **Kibana Dashboard Setup**

### **1. Create Index Pattern**
1. Go to **Stack Management** → **Index Patterns**
2. Create pattern: `vienna-weather-*`
3. Set timestamp field: `@timestamp`

### **2. Suggested Visualizations**

#### **Temperature Trends**
- **Type**: Line chart
- **X-axis**: @timestamp (date histogram)
- **Y-axis**: temperature, feels_like
- **Split series**: temperature vs feels_like

#### **Weather Conditions Distribution**
- **Type**: Pie chart
- **Buckets**: weather_condition

#### **Processing Performance**
- **Type**: Line chart
- **X-axis**: @timestamp
- **Y-axis**: processing_delay_ms
- **Title**: "Message Processing Delay (ms)"

#### **Hourly Weather Patterns**
- **Type**: Heatmap
- **X-axis**: hour_of_day
- **Y-axis**: date
- **Metrics**: average temperature

#### **Geographic Mapping**
- **Type**: Maps
- **Layer**: Documents
- **Geospatial field**: location

### **3. Sample Kibana Queries**

#### **High Processing Delays**
```
processing_delay_ms:>1000
```

#### **Weather Checks in Last Hour**
```
@timestamp:[now-1h TO now]
```

#### **Temperature Above 25°C**
```
temperature:>=25
```

#### **Specific Weather Conditions**
```
weather_condition:("Rain" OR "Snow" OR "Thunderstorm")
```

## 🔧 **Logstash Processing Features**

### **Data Enrichment:**
- ✅ **Millisecond precision** timestamps
- ✅ **Processing delay calculation**
- ✅ **Geographic coordinates** for mapping
- ✅ **Heat index calculation** for comfort analysis
- ✅ **Hour extraction** for time-based analysis
- ✅ **Unit conversions** (meters to kilometers)

### **Performance Monitoring:**
- ✅ **API response time** tracking
- ✅ **Message processing latency**
- ✅ **Queue depth** monitoring via RabbitMQ

## 🏃‍♂️ **Performance Analysis Queries**

### **Average Processing Delay by Hour**
```json
{
  "aggs": {
    "by_hour": {
      "date_histogram": {
        "field": "@timestamp",
        "interval": "1h"
      },
      "aggs": {
        "avg_delay": {
          "avg": {
            "field": "processing_delay_ms"
          }
        }
      }
    }
  }
}
```

### **Weather Check Frequency**
```json
{
  "aggs": {
    "checks_per_hour": {
      "date_histogram": {
        "field": "@timestamp",
        "interval": "1h"
      }
    }
  }
}
```

## 🔄 **Operational Commands**

### **Check ELK Stack Status**
```powershell
docker-compose ps
```

### **View Logs**
```powershell
# Logstash logs
docker logs logstash -f

# Elasticsearch logs
docker logs elasticsearch -f
```

### **Restart Services**
```powershell
docker-compose restart logstash
```

### **Stop All Services**
```powershell
docker-compose down
```

### **Clean Up (Remove Data)**
```powershell
docker-compose down -v
```

## 📋 **Troubleshooting**

### **Logstash Not Processing Messages**
1. Check RabbitMQ queue has messages
2. Verify Logstash configuration syntax
3. Check Elasticsearch connectivity

### **Missing Data in Kibana**
1. Refresh index patterns
2. Check time range filters
3. Verify Elasticsearch indices: `GET /_cat/indices`

### **High Processing Delays**
1. Check system resources
2. Verify network connectivity
3. Monitor Elasticsearch cluster health

## 🎯 **Use Cases for Millisecond Precision**

1. **Performance Analysis**: Identify processing bottlenecks
2. **Real-time Monitoring**: Track system responsiveness
3. **SLA Monitoring**: Ensure sub-second processing times
4. **Debugging**: Correlate events with precise timing
5. **Capacity Planning**: Understand processing patterns

## 📊 **Sample Alerts in Kibana**

### **High Processing Delay Alert**
- **Condition**: processing_delay_ms > 5000
- **Action**: Send notification

### **Missing Weather Data Alert**
- **Condition**: No documents in last 2 hours
- **Action**: System health check

This setup provides enterprise-grade weather monitoring with millisecond precision for detailed performance analysis and operational insights.