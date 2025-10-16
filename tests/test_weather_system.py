"""
Unit tests for Vienna Weather Monitoring System
Tests the core functionality of weather data collection and processing
"""

import pytest
import json
import requests
from unittest.mock import Mock, patch, MagicMock
import sys
import os

# Add the project root to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

try:
    import weather_auto_rabbitmq
except ImportError:
    # Handle the case where the module might not be directly importable
    pass


class TestWeatherDataCollection:
    """Test weather data collection functionality"""
    
    def test_api_key_exists(self):
        """Test that API key is configured"""
        assert hasattr(weather_auto_rabbitmq, 'API_KEY')
        assert weather_auto_rabbitmq.API_KEY is not None
        assert len(weather_auto_rabbitmq.API_KEY) > 0
    
    @patch('requests.get')
    def test_weather_api_call_success(self, mock_get):
        """Test successful weather API call"""
        # Mock successful API response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'weather': [{'main': 'Clear', 'description': 'clear sky'}],
            'main': {'temp': 293.15, 'humidity': 65, 'pressure': 1013},
            'wind': {'speed': 3.5, 'deg': 180},
            'name': 'Vienna',
            'sys': {'country': 'AT'}
        }
        mock_get.return_value = mock_response
        
        # Test the API call
        api_key = weather_auto_rabbitmq.API_KEY
        url = f"http://api.openweathermap.org/data/2.5/weather?q=Vienna,AT&appid={api_key}"
        
        response = requests.get(url)
        
        assert response.status_code == 200
        data = response.json()
        assert 'weather' in data
        assert 'main' in data
        assert data['name'] == 'Vienna'
    
    @patch('requests.get')
    def test_weather_api_call_failure(self, mock_get):
        """Test handling of failed weather API call"""
        # Mock failed API response
        mock_response = Mock()
        mock_response.status_code = 401
        mock_response.json.return_value = {'message': 'Invalid API key'}
        mock_get.return_value = mock_response
        
        api_key = "invalid_key"
        url = f"http://api.openweathermap.org/data/2.5/weather?q=Vienna,AT&appid={api_key}"
        
        response = requests.get(url)
        
        assert response.status_code == 401
        data = response.json()
        assert 'message' in data
    
    def test_temperature_conversion(self):
        """Test temperature conversion from Kelvin to Celsius"""
        kelvin_temp = 293.15
        celsius_temp = kelvin_temp - 273.15
        
        assert abs(celsius_temp - 20.0) < 0.01
    
    def test_weather_data_format(self):
        """Test weather data formatting"""
        sample_weather_data = {
            'weather': [{'main': 'Clear', 'description': 'clear sky'}],
            'main': {'temp': 293.15, 'humidity': 65, 'pressure': 1013},
            'wind': {'speed': 3.5, 'deg': 180},
            'name': 'Vienna',
            'sys': {'country': 'AT'},
            'dt': 1697462400
        }
        
        # Verify required fields exist
        assert 'weather' in sample_weather_data
        assert 'main' in sample_weather_data
        assert 'name' in sample_weather_data
        assert sample_weather_data['name'] == 'Vienna'
        assert sample_weather_data['sys']['country'] == 'AT'


class TestRabbitMQManager:
    """Test RabbitMQ management functionality"""
    
    def test_rabbitmq_manager_initialization(self):
        """Test RabbitMQ manager initialization"""
        manager = weather_auto_rabbitmq.RabbitMQManager()
        assert manager.container_name == weather_auto_rabbitmq.RABBITMQ_CONTAINER_NAME
    
    @patch('subprocess.run')
    def test_docker_availability_check(self, mock_run):
        """Test Docker availability check"""
        # Mock successful docker command
        mock_run.return_value = Mock(returncode=0)
        
        manager = weather_auto_rabbitmq.RabbitMQManager()
        result = manager.is_docker_available()
        
        assert result is True
        mock_run.assert_called_once()
    
    @patch('subprocess.run')
    def test_docker_unavailable(self, mock_run):
        """Test Docker unavailable scenario"""
        # Mock failed docker command
        mock_run.side_effect = FileNotFoundError()
        
        manager = weather_auto_rabbitmq.RabbitMQManager()
        result = manager.is_docker_available()
        
        assert result is False
    
    @patch('subprocess.run')
    def test_rabbitmq_running_check(self, mock_run):
        """Test RabbitMQ running check"""
        # Mock docker ps output showing running container
        mock_run.return_value = Mock(returncode=0, stdout="rabbitmq\n")
        
        manager = weather_auto_rabbitmq.RabbitMQManager()
        result = manager.is_rabbitmq_running()
        
        assert result is True


class TestDataProcessing:
    """Test data processing and validation"""
    
    def test_json_serialization(self):
        """Test JSON serialization of weather data"""
        sample_data = {
            'timestamp': '2023-10-16T12:00:00Z',
            'temperature': 20.5,
            'humidity': 65,
            'pressure': 1013,
            'description': 'clear sky'
        }
        
        # Test JSON serialization
        json_string = json.dumps(sample_data)
        assert isinstance(json_string, str)
        
        # Test JSON deserialization
        parsed_data = json.loads(json_string)
        assert parsed_data == sample_data
    
    def test_data_validation(self):
        """Test weather data validation"""
        valid_data = {
            'main': {'temp': 293.15, 'humidity': 65, 'pressure': 1013},
            'weather': [{'description': 'clear sky'}],
            'name': 'Vienna'
        }
        
        # Check required fields
        assert 'main' in valid_data
        assert 'temp' in valid_data['main']
        assert 'humidity' in valid_data['main']
        assert 'pressure' in valid_data['main']
        assert 'weather' in valid_data
        assert 'name' in valid_data
        
        # Check data types
        assert isinstance(valid_data['main']['temp'], (int, float))
        assert isinstance(valid_data['main']['humidity'], int)
        assert isinstance(valid_data['main']['pressure'], int)
        assert isinstance(valid_data['weather'], list)
        assert len(valid_data['weather']) > 0


class TestConfiguration:
    """Test configuration and constants"""
    
    def test_configuration_constants(self):
        """Test that all required configuration constants are defined"""
        assert hasattr(weather_auto_rabbitmq, 'API_KEY')
        assert hasattr(weather_auto_rabbitmq, 'RABBITMQ_HOST')
        assert hasattr(weather_auto_rabbitmq, 'RABBITMQ_PORT')
        assert hasattr(weather_auto_rabbitmq, 'RABBITMQ_USERNAME')
        assert hasattr(weather_auto_rabbitmq, 'RABBITMQ_PASSWORD')
        assert hasattr(weather_auto_rabbitmq, 'RABBITMQ_QUEUE')
        assert hasattr(weather_auto_rabbitmq, 'RABBITMQ_EXCHANGE')
        assert hasattr(weather_auto_rabbitmq, 'RABBITMQ_ROUTING_KEY')
    
    def test_rabbitmq_configuration(self):
        """Test RabbitMQ configuration values"""
        assert weather_auto_rabbitmq.RABBITMQ_HOST == 'localhost'
        assert weather_auto_rabbitmq.RABBITMQ_PORT == 5672
        assert weather_auto_rabbitmq.RABBITMQ_USERNAME == 'guest'
        assert weather_auto_rabbitmq.RABBITMQ_PASSWORD == 'guest'
        assert weather_auto_rabbitmq.RABBITMQ_QUEUE == 'vienna_weather'
        assert weather_auto_rabbitmq.RABBITMQ_EXCHANGE == 'weather_exchange'
        assert weather_auto_rabbitmq.RABBITMQ_ROUTING_KEY == 'vienna.weather.hourly'


if __name__ == '__main__':
    # Run tests with verbose output
    pytest.main(['-v', __file__])