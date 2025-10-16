import requests
import json
import time
import pika
import subprocess
from datetime import datetime

# Your OpenWeatherMap API key
API_KEY = "7ea63a60ef095d75baf077171165c148"

# RabbitMQ Configuration
RABBITMQ_HOST = 'localhost'
RABBITMQ_PORT = 5672
RABBITMQ_USERNAME = 'guest'
RABBITMQ_PASSWORD = 'guest'
RABBITMQ_QUEUE = 'vienna_weather'
RABBITMQ_EXCHANGE = 'weather_exchange'
RABBITMQ_ROUTING_KEY = 'vienna.weather.hourly'
RABBITMQ_CONTAINER_NAME = 'rabbitmq'


class RabbitMQManager:

    def __init__(self):
        self.container_name = RABBITMQ_CONTAINER_NAME

    def is_docker_available(self):
        """Check if Docker is available"""
        try:
            result = subprocess.run(['docker', '--version'],
                                    capture_output=True, text=True, timeout=10)
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False

    def is_rabbitmq_running(self):
        """Check if RabbitMQ container is running"""
        try:
            result = subprocess.run(['docker', 'ps', '--filter', f'name={self.container_name}', '--format', '{{.Names}}'],
                                    capture_output=True, text=True, timeout=10)
            return self.container_name in result.stdout
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False

    def start_rabbitmq(self):
        """Start RabbitMQ container"""
        try:
            print("🐰 Starting RabbitMQ container...")

            # Check if container exists but is stopped
            result = subprocess.run(['docker', 'ps', '-a', '--filter', f'name={self.container_name}', '--format', '{{.Names}}'],
                                    capture_output=True, text=True, timeout=10)

            if self.container_name in result.stdout:
                # Container exists, start it
                print("📦 Found existing RabbitMQ container, starting it...")
                start_result = subprocess.run(['docker', 'start', self.container_name],
                                              capture_output=True, text=True, timeout=30)
                if start_result.returncode == 0:
                    print("✅ RabbitMQ container started successfully")
                    return True
                else:
                    print(f"❌ Failed to start existing container: {start_result.stderr}")
                    return False
            else:
                # Create new container
                print("🚀 Creating new RabbitMQ container...")
                create_result = subprocess.run([
                    'docker', 'run', '-d',
                    '--name', self.container_name,
                    '-p', '5672:5672',
                    '-p', '15672:15672',
                    'rabbitmq:3-management'
                ], capture_output=True, text=True, timeout=60)

                if create_result.returncode == 0:
                    print("✅ RabbitMQ container created and started successfully")
                    print("🌐 Management interface will be available at: http://localhost:15672")
                    print("⏳ Waiting 10 seconds for RabbitMQ to initialize...")
                    time.sleep(10)  # Wait for RabbitMQ to fully start
                    return True
                else:
                    print(f"❌ Failed to create RabbitMQ container: {create_result.stderr}")
                    return False

        except subprocess.TimeoutExpired:
            print("❌ Docker command timed out")
            return False
        except Exception as e:
            print(f"❌ Error managing RabbitMQ container: {e}")
            return False

    def ensure_rabbitmq_running(self):
        """Ensure RabbitMQ is running, start if necessary"""
        if not self.is_docker_available():
            print("❌ Docker is not available. Please install Docker to auto-manage RabbitMQ.")
            return False

        if self.is_rabbitmq_running():
            print("✅ RabbitMQ container is already running")
            return True
        else:
            print("🔍 RabbitMQ container not running, attempting to start...")
            return self.start_rabbitmq()


class WeatherRabbitMQPublisher:

    def __init__(self, host=RABBITMQ_HOST, port=RABBITMQ_PORT, username=RABBITMQ_USERNAME, password=RABBITMQ_PASSWORD):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.connection = None
        self.channel = None

    def connect(self, max_retries=3):
        """Connect to RabbitMQ with retries"""
        for attempt in range(max_retries):
            try:
                credentials = pika.PlainCredentials(self.username, self.password)
                parameters = pika.ConnectionParameters(
                    host=self.host,
                    port=self.port,
                    credentials=credentials,
                    connection_attempts=3,
                    retry_delay=2
                )
                self.connection = pika.BlockingConnection(parameters)
                self.channel = self.connection.channel()

                # Declare exchange
                self.channel.exchange_declare(
                    exchange=RABBITMQ_EXCHANGE,
                    exchange_type='topic',
                    durable=True
                )

                # Declare queue
                self.channel.queue_declare(queue=RABBITMQ_QUEUE, durable=True)

                # Bind queue to exchange
                self.channel.queue_bind(
                    exchange=RABBITMQ_EXCHANGE,
                    queue=RABBITMQ_QUEUE,
                    routing_key=RABBITMQ_ROUTING_KEY
                )

                print("✅ Connected to RabbitMQ successfully")
                return True

            except Exception as e:
                print(f"❌ Attempt {attempt + 1}/{max_retries} failed to connect to RabbitMQ: {e}")
                if attempt < max_retries - 1:
                    print("⏳ Waiting 5 seconds before retry...")
                    time.sleep(5)

        print("❌ Failed to connect to RabbitMQ after all attempts")
        return False

    def publish_weather_data(self, weather_data):
        """Publish weather data to RabbitMQ"""
        try:
            if not self.channel:
                print("❌ No RabbitMQ connection available")
                return False

            # Prepare message with millisecond precision timestamp
            message = {
                "timestamp": datetime.now().isoformat(timespec='milliseconds'),
                "weather_check_time_ms": int(datetime.now().timestamp() * 1000),
                "city": "Vienna",
                "country": "Austria",
                "weather_data": weather_data,
                "source": "OpenWeatherMap",
                "api_response_time": datetime.now().isoformat(timespec='milliseconds')
            }

            # Publish message
            self.channel.basic_publish(
                exchange=RABBITMQ_EXCHANGE,
                routing_key=RABBITMQ_ROUTING_KEY,
                body=json.dumps(message, ensure_ascii=False),
                properties=pika.BasicProperties(
                    delivery_mode=2,  # Make message persistent
                    content_type='application/json'
                )
            )

            print("📤 Weather data sent to RabbitMQ")
            return True

        except Exception as e:
            print(f"❌ Failed to publish to RabbitMQ: {e}")
            return False

    def close(self):
        """Close RabbitMQ connection"""
        try:
            if self.connection and not self.connection.is_closed:
                self.connection.close()
                print("🔌 RabbitMQ connection closed")
        except Exception as e:
            print(f"⚠️  Error closing RabbitMQ connection: {e}")


def get_vienna_weather():
    """Get Vienna weather data from OpenWeatherMap API"""

    if API_KEY == "YOUR_API_KEY_HERE":
        print("❌ Please replace 'YOUR_API_KEY_HERE' with your actual OpenWeatherMap API key")
        return None

    url = "http://api.openweathermap.org/data/2.5/weather"
    params = {
        'q': 'Vienna,AT',
        'appid': API_KEY,
        'units': 'metric'
    }

    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()

        # Display weather information
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"\n{'=' * 60}")
        print(f"🕐 Weather Check Time: {current_time}")
        print("🌍 Vienna, Austria Weather")
        print(f"{'=' * 60}")
        print(f"🌤️  Condition: {data['weather'][0]['description'].title()}")
        print(f"🌡️  Temperature: {data['main']['temp']}°C")
        print(f"🤔 Feels like: {data['main']['feels_like']}°C")
        print(f"📊 Min/Max: {data['main']['temp_min']}°C / {data['main']['temp_max']}°C")
        print(f"💧 Humidity: {data['main']['humidity']}%")
        print(f"💨 Wind: {data['wind']['speed']} m/s")
        print(f"🔽 Pressure: {data['main']['pressure']} hPa")
        print(f"☁️  Cloudiness: {data['clouds']['all']}%")

        if 'visibility' in data:
            print(f"👁️  Visibility: {data['visibility'] / 1000:.1f} km")

        print(f"{'=' * 60}")

        return data

    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching weather: {e}")
        return None
    except KeyError as e:
        print(f"❌ Error parsing weather data: {e}")
        return None


def save_to_log(weather_data, check_number):
    """Save weather data to local log file (backup)"""
    try:
        now = datetime.now()
        timestamp = now.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]  # Millisecond precision
        timestamp_ms = int(now.timestamp() * 1000)

        log_entry = {
            "check_number": check_number,
            "timestamp": timestamp,
            "timestamp_ms": timestamp_ms,
            "temperature": weather_data['main']['temp'],
            "feels_like": weather_data['main']['feels_like'],
            "humidity": weather_data['main']['humidity'],
            "pressure": weather_data['main']['pressure'],
            "description": weather_data['weather'][0]['description'],
            "wind_speed": weather_data['wind']['speed'],
            "cloudiness": weather_data['clouds']['all'],
            "api_call_time": now.isoformat(timespec='milliseconds')
        }

        with open("vienna_weather_log.json", "a", encoding="utf-8") as f:
            f.write(json.dumps(log_entry) + "\n")

        print("💾 Weather data saved to local log file")

    except Exception as e:
        print(f"⚠️  Warning: Could not save to log file: {e}")


def hourly_weather_monitoring():
    """Main function for hourly weather monitoring with auto-managed RabbitMQ"""

    print("🚀 Starting Vienna Weather Monitor with Auto-Managed RabbitMQ")
    print("=" * 70)

    # Initialize RabbitMQ manager
    rabbitmq_manager = RabbitMQManager()

    # Ensure RabbitMQ is running
    print("🔍 Checking RabbitMQ status...")
    if not rabbitmq_manager.ensure_rabbitmq_running():
        print("⚠️  Could not start RabbitMQ automatically. Continuing with local logging only.")
        rabbitmq_connected = False
    else:
        # Initialize RabbitMQ publisher
        publisher = WeatherRabbitMQPublisher()
        rabbitmq_connected = publisher.connect()

    print("\n📊 Monitoring Configuration:")
    print("   • Weather API: OpenWeatherMap")
    print("   • Location: Vienna, Austria")
    print("   • Frequency: Every hour")
    print(f"   • RabbitMQ: {'✅ Connected' if rabbitmq_connected else '❌ Not available'}")
    print("   • Local Backup: ✅ Enabled")
    if rabbitmq_connected:
        print("   • Management UI: http://localhost:15672 (guest/guest)")
    print("=" * 70)

    print("Press Ctrl+C to stop the monitoring")
    print("Next check will be in 1 hour after the first check\n")

    check_count = 0

    try:
        while True:
            check_count += 1
            print(f"\n🔄 Weather Check #{check_count}")

            # Get weather data
            weather_data = get_vienna_weather()

            if weather_data:
                # Save to local log file (backup)
                save_to_log(weather_data, check_count)

                # Send to RabbitMQ if connected
                if rabbitmq_connected:
                    success = publisher.publish_weather_data(weather_data)
                    if not success:
                        print("⚠️  Failed to send to RabbitMQ, but data saved locally")
                else:
                    print("⚠️  RabbitMQ not available, data saved locally only")

            # Wait for 1 hour
            print("\n⏰ Waiting 1 hour for next check...")
            next_check = datetime.now().replace(hour=(datetime.now().hour + 1) % 24, minute=0, second=0)
            print(f"💤 Next check at: {next_check.strftime('%H:%M:%S')}")

            time.sleep(3600)  # 1 hour

    except KeyboardInterrupt:
        print("\n\n👋 Weather monitoring stopped by user")
        print(f"📊 Total checks performed: {check_count}")
        print("Thank you for using Vienna Weather Monitor!")

    finally:
        # Close RabbitMQ connection if it exists
        if rabbitmq_connected:
            publisher.close()


if __name__ == "__main__":
    print("Vienna Weather Monitor - Auto-Managed RabbitMQ Edition")
    print("=" * 60)
    hourly_weather_monitoring()
