# Vienna Weather Monitoring System

A comprehensive weather monitoring system for Vienna, Austria using OpenWeatherMap API with ELK stack (Elasticsearch, Logstash, Kibana) and RabbitMQ for data processing and visualization.

## 🚀 Quick Start (Fresh Computer Setup)

### Prerequisites
1. **Python 3.8+** - [Download from python.org](https://www.python.org/downloads/)
2. **Docker Desktop** - [Download from docker.com](https://www.docker.com/products/docker-desktop/)
3. **Git** - [Download from git-scm.com](https://git-scm.com/downloads)

### Option 1: Automated Setup (Recommended)

```powershell
# Clone the repository
git clone https://github.com/shai1973private/vienna-weather-monitoring.git
cd vienna-weather-monitoring

# Run automated setup
.\setup-environment.ps1

# Run the complete CI/CD pipeline (sets up everything)
python simple-pipeline.py
```

### Option 2: Manual Setup

```powershell
# Clone the repository
git clone https://github.com/shai1973private/vienna-weather-monitoring.git
cd vienna-weather-monitoring

# Create virtual environment
python -m venv .venv
.venv\Scripts\Activate.ps1

# Install Python dependencies
pip install -r requirements.txt

# Setup ELK stack
.\setup-elk-simple.ps1

# Start weather monitoring
python weather_auto_rabbitmq.py
```

## 🔧 Dependencies (Auto-installed)

### Python Packages
- `requests>=2.31.0` - HTTP client for API calls
- `pika>=1.3.0` - RabbitMQ client library
- `elasticsearch>=8.0.0` - Elasticsearch Python client

**Note**: The enhanced pipeline automatically installs missing Python packages when running `python simple-pipeline.py`
