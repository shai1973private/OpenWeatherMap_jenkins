pipeline {
    agent any
    
    environment {
        // Application Configuration
        PROJECT_NAME = 'vienna-weather-monitoring'
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        DOCKER_COMPOSE_JENKINS_FILE = 'docker-compose.jenkins.yml'
        
        // OpenWeatherMap API Configuration
        API_KEY = credentials('openweathermap-api-key')
        
        // Service URLs
        ELASTICSEARCH_URL = 'http://localhost:9200'
        KIBANA_URL = 'http://localhost:5601'
        RABBITMQ_URL = 'http://localhost:15672'
        
        // Docker and Registry Configuration
        DOCKER_REGISTRY = credentials('docker-registry-url')
        DOCKER_REPO = "${DOCKER_REGISTRY}/${PROJECT_NAME}"
        
        // Build Information
        BUILD_VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
        BUILD_TIMESTAMP = sh(script: "date +%Y%m%d-%H%M%S", returnStdout: true).trim()
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        skipStagesAfterUnstable()
        parallelsAlwaysFailFast()
    }
    
    triggers {
        // Poll SCM every 5 minutes for changes
        pollSCM('H/5 * * * *')
        // Build daily at 2 AM
        cron('H 2 * * *')
    }
    
    stages {
        stage('Clone') {
            steps {
                script {
                    echo "📥 Cloning Vienna Weather Monitoring CI/CD Pipeline"
                    echo "Build: ${BUILD_VERSION}"
                    echo "Timestamp: ${BUILD_TIMESTAMP}"
                    echo "Branch: ${env.GIT_BRANCH}"
                    echo "Commit: ${env.GIT_COMMIT}"
                }
                
                // Clean workspace
                cleanWs()
                
                // Checkout code
                checkout scm
                
                // Display project structure and validate files
                sh '''
                    echo "📁 Project Structure:"
                    find . -type f -name "*.py" -o -name "*.yml" -o -name "*.json" -o -name "*.conf" | head -20
                    
                    echo "📋 Validating required files..."
                    # Check required files exist
                    test -f weather_auto_rabbitmq.py || (echo "Missing weather_auto_rabbitmq.py" && exit 1)
                    test -f docker-compose.yml || (echo "Missing docker-compose.yml" && exit 1)
                    test -f logstash/pipeline/logstash.conf || (echo "Missing logstash.conf" && exit 1)
                    echo "✅ All required files present"
                '''
            }
        }
        
        stage('Build') {
            steps {
                script {
                    echo "🔨 Building application and setting up environment..."
                    
                    // Setup Python environment
                    sh '''
                        echo "🐍 Setting up Python environment..."
                        python3 --version
                        pip3 --version
                        
                        # Install required packages
                        pip3 install --user -r requirements.txt || echo "No requirements.txt found, installing basic packages"
                        pip3 install --user pika requests pytest pytest-cov flake8
                    '''
                    
                    // Check Docker environment
                    sh '''
                        echo "🐳 Checking Docker environment..."
                        docker --version
                        docker-compose --version
                        docker system df
                    '''
                    
                    // Build and package application
                    sh '''
                        echo "📦 Building and packaging application..."
                        # Create build directory
                        mkdir -p build/artifacts
                        
                        # Copy application files
                        cp weather_auto_rabbitmq.py build/artifacts/
                        cp -r logstash build/artifacts/
                        cp docker-compose.yml build/artifacts/
                        cp setup-elk*.ps1 build/artifacts/ || true
                        
                        # Create version file
                        echo "version: ${BUILD_VERSION}" > build/artifacts/version.yml
                        echo "timestamp: ${BUILD_TIMESTAMP}" >> build/artifacts/version.yml
                        echo "commit: ${GIT_COMMIT}" >> build/artifacts/version.yml
                        echo "branch: ${GIT_BRANCH}" >> build/artifacts/version.yml
                        
                        # Basic syntax validation
                        python3 -m py_compile weather_auto_rabbitmq.py
                        python3 -m py_compile simple-pipeline.py
                        
                        # Code quality checks
                        python3 -m flake8 weather_auto_rabbitmq.py --max-line-length=120 --ignore=E501 || true
                        python3 -m flake8 simple-pipeline.py --max-line-length=120 --ignore=E501 || true
                        
                        echo "✅ Build completed successfully"
                    '''
                }
            }
        }
        
        stage('Unit Test') {
            steps {
                script {
                    echo "🧪 Running unit tests..."
                    sh '''
                        # Create test results directory
                        mkdir -p test-results
                        
                        # Run Python unit tests
                        python3 -m pytest tests/ --junit-xml=test-results/python-tests.xml --cov=. --cov-report=xml:test-results/coverage.xml || true
                        
                        # Start test environment for integration tests
                        echo "🔧 Starting test environment..."
                        # Stop any existing containers
                        docker-compose -f ${DOCKER_COMPOSE_JENKINS_FILE} down || true
                        
                        # Start test environment
                        docker-compose -f ${DOCKER_COMPOSE_JENKINS_FILE} up -d
                        
                        # Wait for services to be ready
                        echo "⏳ Waiting for services to start..."
                        sleep 30
                        
                        # Check service health
                        curl -f ${ELASTICSEARCH_URL}/_cluster/health || (echo "Elasticsearch not ready" && exit 1)
                        echo "✅ Elasticsearch is ready"
                        
                        # Test RabbitMQ connection
                        docker exec rabbitmq-jenkins rabbitmqctl status || (echo "RabbitMQ not ready" && exit 1)
                        echo "✅ RabbitMQ is ready"
                        
                        # Run integration tests
                        python3 -m pytest tests/test_integration.py --junit-xml=test-results/integration-tests.xml || true
                        
                        echo "✅ Unit and integration tests completed"
                    '''
                }
            }
            post {
                always {
                    // Publish test results
                    publishTestResults testResultsPattern: 'test-results/*.xml'
                    
                    // Publish coverage report
                    publishCoverage adapters: [coberturaAdapter('test-results/coverage.xml')], sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
                    
                    // Collect logs
                    sh '''
                        mkdir -p test-logs
                        docker-compose -f ${DOCKER_COMPOSE_JENKINS_FILE} logs > test-logs/docker-compose.log 2>&1 || true
                    '''
                    
                    // Archive logs
                    archiveArtifacts artifacts: 'test-logs/**/*', allowEmptyArchive: true
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    echo "🚀 Deploying Vienna Weather Monitoring System..."
                    
                    sh '''
                        # Create deployment directory
                        mkdir -p deploy
                        cp -r build/artifacts/* deploy/
                        
                        # Deploy with docker-compose
                        cd deploy
                        docker-compose -f docker-compose.yml down || true
                        docker-compose -f docker-compose.yml up -d
                        
                        # Wait for deployment
                        echo "⏳ Waiting for deployment to complete..."
                        sleep 45
                        
                        # Verify deployment
                        echo "🔍 Verifying deployment..."
                        curl -f ${ELASTICSEARCH_URL}/_cluster/health || (echo "Elasticsearch deployment verification failed" && exit 1)
                        curl -f ${KIBANA_URL}/api/status || (echo "Kibana deployment verification failed" && exit 1)
                        
                        # Test weather data pipeline
                        echo "🌤️  Testing weather data pipeline..."
                        python3 -c "
import requests
import json
api_key = '${API_KEY}'
url = f'http://api.openweathermap.org/data/2.5/weather?q=Vienna,AT&appid={api_key}'
response = requests.get(url, timeout=10)
if response.status_code == 200:
    print('✅ OpenWeatherMap API connection successful')
    data = response.json()
    print(f'Weather in Vienna: {data[\"weather\"][0][\"description\"]}')
    print(f'Temperature: {data[\"main\"][\"temp\"]} K')
else:
    print(f'⚠️  OpenWeatherMap API returned status: {response.status_code}')
" || echo "Weather API test completed with warnings"
                        
                        # Display deployment URLs
                        echo "🌐 Deployment URLs:"
                        echo "   • Elasticsearch: ${ELASTICSEARCH_URL}"
                        echo "   • Kibana: ${KIBANA_URL}"
                        echo "   • RabbitMQ Management: ${RABBITMQ_URL}"
                        
                        echo "✅ Deployment completed successfully"
                    '''
                }
            }
            post {
                always {
                    // Archive deployment artifacts
                    archiveArtifacts artifacts: 'deploy/**/*', allowEmptyArchive: true
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 Cleaning up..."
                sh '''
                    # Stop test containers
                    docker-compose -f ${DOCKER_COMPOSE_JENKINS_FILE} down || true
                    
                    # Clean up build artifacts older than 7 days
                    find build/ -type f -mtime +7 -delete 2>/dev/null || true
                '''
            }
            
            // Archive build artifacts
            archiveArtifacts artifacts: 'build/artifacts/**/*', allowEmptyArchive: true
            
            // Clean workspace
            cleanWs()
        }
        
        success {
            script {
                echo "✅ Pipeline completed successfully!"
                echo "🌟 Vienna Weather Monitoring System deployed and ready!"
                
                // Send success notification
                sh '''
                    curl -X POST ${ELASTICSEARCH_URL}/vienna-pipeline-notifications/_doc \\
                         -H "Content-Type: application/json" \\
                         -d "{
                           \\"pipeline_id\\": \\"${BUILD_NUMBER}\\",
                           \\"timestamp\\": \\"$(date -Iseconds)\\",
                           \\"status\\": \\"SUCCESS\\",
                           \\"stage\\": \\"DEPLOY\\",
                           \\"build_version\\": \\"${BUILD_VERSION}\\",
                           \\"branch\\": \\"${GIT_BRANCH}\\",
                           \\"project\\": \\"vienna-weather\\",
                           \\"deployment_urls\\": {
                             \\"elasticsearch\\": \\"${ELASTICSEARCH_URL}\\",
                             \\"kibana\\": \\"${KIBANA_URL}\\",
                             \\"rabbitmq\\": \\"${RABBITMQ_URL}\\"
                           }
                         }" || true
                '''
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed!"
                
                // Send failure notification
                sh '''
                    curl -X POST ${ELASTICSEARCH_URL}/vienna-pipeline-notifications/_doc \\
                         -H "Content-Type: application/json" \\
                         -d "{
                           \\"pipeline_id\\": \\"${BUILD_NUMBER}\\",
                           \\"timestamp\\": \\"$(date -Iseconds)\\",
                           \\"status\\": \\"FAILURE\\",
                           \\"stage\\": \\"${STAGE_NAME}\\",
                           \\"build_version\\": \\"${BUILD_VERSION}\\",
                           \\"branch\\": \\"${GIT_BRANCH}\\",
                           \\"project\\": \\"vienna-weather\\"
                         }" || true
                '''
            }
        }
        
        unstable {
            script {
                echo "⚠️ Pipeline unstable!"
                
                // Send unstable notification
                sh '''
                    curl -X POST ${ELASTICSEARCH_URL}/vienna-pipeline-notifications/_doc \\
                         -H "Content-Type: application/json" \\
                         -d "{
                           \\"pipeline_id\\": \\"${BUILD_NUMBER}\\",
                           \\"timestamp\\": \\"$(date -Iseconds)\\",
                           \\"status\\": \\"UNSTABLE\\",
                           \\"stage\\": \\"${STAGE_NAME}\\",
                           \\"build_version\\": \\"${BUILD_VERSION}\\",
                           \\"branch\\": \\"${GIT_BRANCH}\\",
                           \\"project\\": \\"vienna-weather\\"
                         }" || true
                '''
            }
        }
    }
}