#!/bin/bash
# Kibana Dashboard Setup Script

echo "Setting up Kibana Dashboard for Vienna Weather Monitoring..."

# Wait for Kibana to be ready
until curl -s http://localhost:5601/api/status | grep -q "All services are available"; do
    echo "Waiting for Kibana to be ready..."
    sleep 10
done

echo "Kibana is ready. Creating data view..."

# Create data view for vienna-weather-* indices
curl -X POST "localhost:5601/api/data_views/data_view" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -d '{
    "data_view": {
      "title": "vienna-weather-*",
      "timeFieldName": "@timestamp",
      "name": "Vienna Weather Data"
    }
  }'

echo -e "\n✅ Data view created successfully!"

# Create visualization for temperature over time
curl -X POST "localhost:5601/api/saved_objects/visualization" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -d '{
    "attributes": {
      "title": "Vienna Temperature Over Time",
      "type": "line",
      "params": {
        "grid": {"categoryLines": false, "style": {"color": "#eee"}},
        "categoryAxes": [{"id": "CategoryAxis-1", "type": "category", "position": "bottom", "show": true, "style": {}, "scale": {"type": "linear"}, "labels": {"show": true, "truncate": 100}, "title": {}}],
        "valueAxes": [{"id": "ValueAxis-1", "name": "LeftAxis-1", "type": "value", "position": "left", "show": true, "style": {}, "scale": {"type": "linear", "mode": "normal"}, "labels": {"show": true, "rotate": 0, "filter": false, "truncate": 100}, "title": {"text": "Temperature (°C)"}}],
        "seriesParams": [{"show": true, "type": "line", "mode": "normal", "data": {"label": "Temperature", "id": "1"}, "valueAxis": "ValueAxis-1", "drawLinesBetweenPoints": true, "showCircles": true}],
        "addTooltip": true,
        "addLegend": true,
        "legendPosition": "right",
        "times": [],
        "addTimeMarker": false
      },
      "aggs": [
        {"id": "1", "enabled": true, "type": "avg", "schema": "metric", "params": {"field": "temperature"}},
        {"id": "2", "enabled": true, "type": "date_histogram", "schema": "segment", "params": {"field": "@timestamp", "interval": "auto", "customInterval": "2h", "min_doc_count": 1, "extended_bounds": {}}}
      ]
    }
  }'

echo -e "\n✅ Temperature visualization created!"

# Create dashboard
curl -X POST "localhost:5601/api/saved_objects/dashboard" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -d '{
    "attributes": {
      "title": "Vienna Weather Monitoring Dashboard",
      "description": "Real-time weather monitoring for Vienna, Austria - Auto-created by Jenkins CI/CD",
      "panelsJSON": "[]",
      "timeRestore": true,
      "timeTo": "now",
      "timeFrom": "now-24h",
      "refreshInterval": {
        "pause": false,
        "value": 300000
      }
    }
  }'

echo -e "\n🎉 Vienna Weather Dashboard created successfully!"
echo "Dashboard URL: http://localhost:5601/app/dashboards"
echo "Data Explorer URL: http://localhost:5601/app/discover"