"""
Test configuration for Vienna Weather Monitoring System
"""

import pytest
import os
import sys

# Add the project root to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

# Test configuration
pytest_plugins = []

def pytest_configure(config):
    """Configure pytest with custom markers"""
    config.addinivalue_line(
        "markers", "integration: mark test as integration test"
    )
    config.addinivalue_line(
        "markers", "unit: mark test as unit test"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )

def pytest_collection_modifyitems(config, items):
    """Modify test collection to add markers automatically"""
    for item in items:
        # Add integration marker to integration tests
        if "test_integration" in item.nodeid:
            item.add_marker(pytest.mark.integration)
        # Add unit marker to unit tests
        elif "test_weather_system" in item.nodeid:
            item.add_marker(pytest.mark.unit)

@pytest.fixture(scope="session")
def test_config():
    """Test configuration fixture"""
    return {
        'api_key': os.getenv('API_KEY', '7ea63a60ef095d75baf077171165c148'),
        'elasticsearch_url': os.getenv('ELASTICSEARCH_URL', 'http://localhost:9200'),
        'kibana_url': os.getenv('KIBANA_URL', 'http://localhost:5601'),
        'rabbitmq_url': os.getenv('RABBITMQ_URL', 'http://localhost:15672'),
        'rabbitmq_host': os.getenv('RABBITMQ_HOST', 'localhost'),
        'rabbitmq_port': int(os.getenv('RABBITMQ_PORT', '5672')),
    }

@pytest.fixture
def sample_weather_data():
    """Sample weather data for testing"""
    return {
        'weather': [{'main': 'Clear', 'description': 'clear sky'}],
        'main': {
            'temp': 293.15,  # 20°C in Kelvin
            'humidity': 65,
            'pressure': 1013
        },
        'wind': {
            'speed': 3.5,
            'deg': 180
        },
        'name': 'Vienna',
        'sys': {'country': 'AT'},
        'dt': 1697462400
    }