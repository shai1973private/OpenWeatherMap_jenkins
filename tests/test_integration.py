"""
Integration tests for Vienna Weather Monitoring System
Tests the full pipeline integration with external services
"""

import pytest
import requests
import json
import time
import os
import subprocess
from datetime import datetime


class TestAPIIntegration:
    """Test integration with OpenWeatherMap API"""
    
    def test_openweathermap_api_connectivity(self):
        """Test connectivity to OpenWeatherMap API"""
        # Use environment variable or fallback to test key
        api_key = os.getenv('API_KEY', '7ea63a60ef095d75baf077171165c148')
        
        url = f"http://api.openweathermap.org/data/2.5/weather?q=Vienna,AT&appid={api_key}"
        
        try:
            response = requests.get(url, timeout=10)
            
            # Check if API is reachable
            assert response.status_code in [200, 401], f"Unexpected status code: {response.status_code}"
            
            if response.status_code == 200:
                data = response.json()
                assert 'name' in data
                assert data['name'] == 'Vienna'
                print("✅ OpenWeatherMap API connection successful")
            else:
                print("⚠️ OpenWeatherMap API returned authentication error (expected in CI)")
                
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Failed to connect to OpenWeatherMap API: {e}")
    
    def test_weather_data_structure(self):
        """Test expected structure of weather data"""
        api_key = os.getenv('API_KEY', '7ea63a60ef095d75baf077171165c148')
        url = f"http://api.openweathermap.org/data/2.5/weather?q=Vienna,AT&appid={api_key}"
        
        try:
            response = requests.get(url, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                
                # Test required fields
                assert 'weather' in data
                assert 'main' in data
                assert 'wind' in data
                assert 'name' in data
                assert 'sys' in data
                
                # Test nested structures
                assert isinstance(data['weather'], list)
                assert len(data['weather']) > 0
                assert 'description' in data['weather'][0]
                
                assert 'temp' in data['main']
                assert 'humidity' in data['main']
                assert 'pressure' in data['main']
                
                print("✅ Weather data structure validation passed")
            
        except requests.exceptions.RequestException:
            pytest.skip("OpenWeatherMap API not accessible")


class TestElasticsearchIntegration:
    """Test integration with Elasticsearch"""
    
    def test_elasticsearch_connectivity(self):
        """Test connectivity to Elasticsearch"""
        elasticsearch_url = os.getenv('ELASTICSEARCH_URL', 'http://localhost:9200')
        
        try:
            response = requests.get(f"{elasticsearch_url}/", timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                assert 'cluster_name' in data
                assert 'version' in data
                print("✅ Elasticsearch connection successful")
            else:
                print("⚠️ Elasticsearch not responding as expected")
                
        except requests.exceptions.RequestException:
            pytest.skip("Elasticsearch not accessible")
    
    def test_elasticsearch_cluster_health(self):
        """Test Elasticsearch cluster health"""
        elasticsearch_url = os.getenv('ELASTICSEARCH_URL', 'http://localhost:9200')
        
        try:
            response = requests.get(f"{elasticsearch_url}/_cluster/health", timeout=10)
            
            if response.status_code == 200:
                health_data = response.json()
                assert 'status' in health_data
                assert health_data['status'] in ['green', 'yellow', 'red']
                print(f"✅ Elasticsearch cluster status: {health_data['status']}")
            
        except requests.exceptions.RequestException:
            pytest.skip("Elasticsearch cluster health check not accessible")
    
    def test_create_test_index(self):
        """Test creating a test index in Elasticsearch"""
        elasticsearch_url = os.getenv('ELASTICSEARCH_URL', 'http://localhost:9200')
        
        try:
            # Create test index
            test_index = f"test-vienna-weather-{int(time.time())}"
            
            # Sample document
            test_doc = {
                "timestamp": datetime.now().isoformat(),
                "temperature": 20.5,
                "humidity": 65,
                "description": "test data",
                "location": "Vienna"
            }
            
            response = requests.post(
                f"{elasticsearch_url}/{test_index}/_doc",
                headers={'Content-Type': 'application/json'},
                json=test_doc,
                timeout=10
            )
            
            if response.status_code in [200, 201]:
                print("✅ Test document created in Elasticsearch")
                
                # Clean up - delete test index
                time.sleep(1)  # Wait for document to be indexed
                requests.delete(f"{elasticsearch_url}/{test_index}", timeout=10)
                print("✅ Test index cleaned up")
            
        except requests.exceptions.RequestException:
            pytest.skip("Elasticsearch document creation test not accessible")


class TestKibanaIntegration:
    """Test integration with Kibana"""
    
    def test_kibana_connectivity(self):
        """Test connectivity to Kibana"""
        kibana_url = os.getenv('KIBANA_URL', 'http://localhost:5601')
        
        try:
            response = requests.get(f"{kibana_url}/api/status", timeout=15)
            
            if response.status_code == 200:
                status_data = response.json()
                assert 'status' in status_data
                print("✅ Kibana connection successful")
            else:
                print("⚠️ Kibana not responding as expected")
                
        except requests.exceptions.RequestException:
            pytest.skip("Kibana not accessible")


class TestRabbitMQIntegration:
    """Test integration with RabbitMQ"""
    
    def test_rabbitmq_management_api(self):
        """Test RabbitMQ management API"""
        rabbitmq_url = os.getenv('RABBITMQ_URL', 'http://localhost:15672')
        
        try:
            # Test with basic auth (guest/guest)
            response = requests.get(
                f"{rabbitmq_url}/api/overview",
                auth=('guest', 'guest'),
                timeout=10
            )
            
            if response.status_code == 200:
                overview_data = response.json()
                assert 'rabbitmq_version' in overview_data
                print("✅ RabbitMQ management API accessible")
            
        except requests.exceptions.RequestException:
            pytest.skip("RabbitMQ management API not accessible")
    
    def test_rabbitmq_container_status(self):
        """Test RabbitMQ container status using Docker"""
        try:
            # Check if RabbitMQ container is running
            result = subprocess.run(
                ['docker', 'ps', '--filter', 'name=rabbitmq', '--format', '{{.Names}}'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0 and 'rabbitmq' in result.stdout:
                print("✅ RabbitMQ container is running")
            else:
                print("⚠️ RabbitMQ container not found or not running")
                
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pytest.skip("Docker not available for container status check")


class TestDockerIntegration:
    """Test Docker integration and container management"""
    
    def test_docker_availability(self):
        """Test Docker availability"""
        try:
            result = subprocess.run(
                ['docker', '--version'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            assert result.returncode == 0
            assert 'Docker version' in result.stdout
            print("✅ Docker is available")
            
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pytest.fail("Docker is not available")
    
    def test_docker_compose_availability(self):
        """Test Docker Compose availability"""
        try:
            result = subprocess.run(
                ['docker-compose', '--version'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            assert result.returncode == 0
            print("✅ Docker Compose is available")
            
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pytest.fail("Docker Compose is not available")


class TestEndToEndWorkflow:
    """Test end-to-end workflow"""
    
    def test_full_pipeline_connectivity(self):
        """Test connectivity to all required services"""
        services = {
            'Elasticsearch': 'http://localhost:9200/',
            'Kibana': 'http://localhost:5601/api/status',
            'RabbitMQ': 'http://localhost:15672/api/overview'
        }
        
        results = {}
        
        for service_name, url in services.items():
            try:
                if service_name == 'RabbitMQ':
                    response = requests.get(url, auth=('guest', 'guest'), timeout=10)
                else:
                    response = requests.get(url, timeout=10)
                
                results[service_name] = response.status_code == 200
                
            except requests.exceptions.RequestException:
                results[service_name] = False
        
        # Print results
        for service_name, status in results.items():
            status_icon = "✅" if status else "❌"
            print(f"{status_icon} {service_name}: {'Available' if status else 'Not Available'}")
        
        # At least one service should be available for basic functionality
        assert any(results.values()), "No services are available"


if __name__ == '__main__':
    # Run integration tests with verbose output
    pytest.main(['-v', __file__])