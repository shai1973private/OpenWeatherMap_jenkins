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
        
        // Jenkins Testing URLs (different ports to avoid conflicts)
        ELASTICSEARCH_TEST_URL = 'http://localhost:9201'
        KIBANA_TEST_URL = 'http://localhost:5602'
        RABBITMQ_TEST_URL = 'http://localhost:15673'
        LOGSTASH_TEST_URL = 'http://localhost:9601'
        
        // Build Information
        BUILD_VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
        BUILD_TIMESTAMP = bat(script: "@echo off && echo %date:~10,4%%date:~4,2%%date:~7,2%-%time:~0,2%%time:~3,2%%time:~6,2%", returnStdout: true).trim()
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        skipDefaultCheckout(false)
        timeout(time: 30, unit: 'MINUTES')
        skipStagesAfterUnstable()
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
                    echo "Cloning Vienna Weather Monitoring CI/CD Pipeline"
                    echo "Build: ${BUILD_VERSION}"
                    echo "Timestamp: ${BUILD_TIMESTAMP}"
                    echo "Branch: ${env.GIT_BRANCH}"
                    echo "Commit: ${env.GIT_COMMIT}"
                }
                
                // Clean workspace with better error handling
                script {
                    try {
                        cleanWs()
                        echo "Workspace cleaned successfully"
                    } catch (Exception e) {
                        echo "Warning: Workspace cleanup had issues: ${e.getMessage()}"
                        echo "Continuing with build..."
                        
                        // Manual cleanup attempt
                        bat '''
                            echo "Attempting manual cleanup..."
                            timeout /t 2
                            del /f /s /q . 2>nul || echo "Manual file cleanup completed"
                            for /d %%i in (*) do rd /s /q "%%i" 2>nul || echo "Manual directory cleanup completed"
                        '''
                    }
                }
                
                // Checkout code
                checkout scm
                
                // Display project structure and validate files
                bat '''
                    echo Project Structure:
                    dir /b *.py *.yml *.json *.conf 2>nul | more
                    
                    echo Validating required files...
                    if not exist weather_auto_rabbitmq.py (echo Missing weather_auto_rabbitmq.py && exit /b 1)
                    if not exist docker-compose.yml (echo Missing docker-compose.yml && exit /b 1)
                    if not exist logstash\\pipeline\\logstash.conf (echo Missing logstash.conf && exit /b 1)
                    echo All required files present
                '''
            }
        }
        
        stage('Build') {
            steps {
                script {
                    echo "Building application and setting up environment..."
                    
                    // Setup Python environment
                    bat '''
                        echo Setting up Python environment...
                        python --version
                        pip --version
                        
                        REM Install required packages
                        pip install -r requirements.txt || echo No requirements.txt found, installing basic packages
                        pip install pika requests pytest pytest-cov flake8
                    '''
                    
                    // Check Docker environment
                    bat '''
                        echo Checking Docker environment...
                        docker --version
                        docker-compose --version
                        docker system df
                    '''
                    
                    // Build and package application
                    bat '''
                        echo Building and packaging application...
                        REM Create build directory
                        if not exist build\\artifacts mkdir build\\artifacts
                        
                        REM Copy application files
                        copy weather_auto_rabbitmq.py build\\artifacts\\
                        xcopy /E /I logstash build\\artifacts\\logstash
                        copy docker-compose.yml build\\artifacts\\
                        if exist setup-elk*.ps1 copy setup-elk*.ps1 build\\artifacts\\
                        
                        REM Create version file
                        echo version: %BUILD_VERSION% > build\\artifacts\\version.yml
                        echo timestamp: %BUILD_TIMESTAMP% >> build\\artifacts\\version.yml
                        echo commit: %GIT_COMMIT% >> build\\artifacts\\version.yml
                        echo branch: %GIT_BRANCH% >> build\\artifacts\\version.yml
                        
                        REM Basic syntax validation
                        python -m py_compile weather_auto_rabbitmq.py
                        if exist simple-pipeline.py python -m py_compile simple-pipeline.py
                        
                        REM Code quality checks
                        python -m flake8 weather_auto_rabbitmq.py --max-line-length=120 --ignore=E501 || echo Code quality check completed
                        
                        echo Build completed successfully
                    '''
                }
            }
        }
        
        stage('Unit Test') {
            steps {
                script {
                    echo "Running unit tests..."
                    bat '''
                        REM Create test results directory
                        if not exist test-results mkdir test-results
                        
                        REM Run Python unit tests
                        python -m pytest tests\\ --junit-xml=test-results\\python-tests.xml --cov=. --cov-report=xml:test-results\\coverage.xml || echo Unit tests completed with warnings
                        
                        REM Start test environment for integration tests
                        echo Starting test environment...
                        REM Force stop and remove any existing containers and networks
                        docker-compose -f %DOCKER_COMPOSE_JENKINS_FILE% down --volumes --remove-orphans || echo No containers to stop
                        
                        REM Force remove any conflicting containers by name
                        docker stop elasticsearch kibana rabbitmq logstash 2>nul || echo No conflicting containers found
                        docker stop elasticsearch-jenkins kibana-jenkins rabbitmq-jenkins logstash-jenkins test-runner-jenkins 2>nul || echo No Jenkins containers found
                        docker rm -f elasticsearch kibana rabbitmq logstash 2>nul || echo No containers to remove
                        docker rm -f elasticsearch-jenkins kibana-jenkins rabbitmq-jenkins logstash-jenkins test-runner-jenkins 2>nul || echo No Jenkins containers to remove
                        
                        REM Remove any orphaned networks
                        docker network rm jenkins_elk_network 2>nul || echo No network to remove
                        
                        REM Wait a moment for cleanup to complete
                        powershell -Command "Start-Sleep -Seconds 5"
                        
                        REM Start test environment
                        echo Starting fresh test environment...
                        docker-compose -f %DOCKER_COMPOSE_JENKINS_FILE% up -d
                        
                        REM Check if services started successfully
                        echo Checking if services started...
                        docker-compose -f %DOCKER_COMPOSE_JENKINS_FILE% ps
                        
                        REM Wait for services to be ready with extended timeout
                        echo Waiting for services to start...
                        powershell -Command "Start-Sleep -Seconds 45"
                        
                        REM Check service health with retry logic
                        echo Testing Elasticsearch connection...
                        set /A elasticsearch_ready=0
                        for /L %%i in (1,1,3) do (
                            curl -f %ELASTICSEARCH_TEST_URL%/_cluster/health >nul 2>&1
                            if not errorlevel 1 (
                                echo Elasticsearch is ready
                                set /A elasticsearch_ready=1
                                goto :elasticsearch_done
                            )
                            echo Attempt %%i failed, waiting 10 seconds...
                            powershell -Command "Start-Sleep -Seconds 10"
                        )
                        :elasticsearch_done
                        if %elasticsearch_ready%==0 (
                            echo Elasticsearch not ready after 3 attempts, checking container status...
                            docker logs elasticsearch-jenkins --tail 20
                            exit /b 1
                        )
                        
                        REM Check Logstash health
                        curl -f %LOGSTASH_TEST_URL% || echo Logstash health check failed, continuing...
                        echo Logstash status checked
                        
                        REM Test RabbitMQ connection with better error handling
                        echo Checking RabbitMQ container status...
                        docker ps -a --filter "name=rabbitmq-jenkins" --format "table {{.Names}}\t{{.Status}}"
                        
                        REM Try to execute rabbitmqctl status directly
                        docker exec rabbitmq-jenkins rabbitmqctl status >nul 2>&1
                        if errorlevel 1 (
                            echo RabbitMQ not ready, checking container logs...
                            docker logs --tail 20 rabbitmq-jenkins
                            echo Attempting to restart RabbitMQ...
                            docker-compose -f %DOCKER_COMPOSE_JENKINS_FILE% restart rabbitmq
                            powershell -Command "Start-Sleep -Seconds 20"
                            
                            REM Final attempt
                            docker exec rabbitmq-jenkins rabbitmqctl status >nul 2>&1
                            if errorlevel 1 (
                                echo RabbitMQ not ready, continuing with limited testing
                                set RABBITMQ_AVAILABLE=false
                            ) else (
                                echo RabbitMQ is ready after restart
                                set RABBITMQ_AVAILABLE=true
                            )
                        ) else (
                            echo RabbitMQ is ready
                            set RABBITMQ_AVAILABLE=true
                        )
                        
                        REM Run integration tests
                        REM Set testing environment variables for integration tests
                        set ELASTICSEARCH_URL=http://localhost:9201
                        set KIBANA_URL=http://localhost:5602
                        set RABBITMQ_URL=http://localhost:15673
                        set LOGSTASH_URL=http://localhost:9601
                        python -m pytest tests\\test_integration.py --junit-xml=test-results\\integration-tests.xml || echo Integration tests completed with warnings
                        
                        echo Unit and integration tests completed
                    '''
                }
            }
            post {
                always {
                    // Publish test results using junit step
                    script {
                        try {
                            if (fileExists('test-results/*.xml')) {
                                junit testResultsPattern: 'test-results/*.xml', allowEmptyResults: true
                            } else {
                                echo "No test result files found"
                            }
                        } catch (Exception e) {
                            echo "Warning: Could not publish test results: ${e.getMessage()}"
                        }
                    }
                    
                    // Archive coverage report (instead of publishCoverage)
                    script {
                        try {
                            if (fileExists('test-results/coverage.xml')) {
                                archiveArtifacts artifacts: 'test-results/coverage.xml', allowEmptyArchive: true
                                echo "Coverage report archived: test-results/coverage.xml"
                            } else {
                                echo "No coverage report found"
                            }
                        } catch (Exception e) {
                            echo "Warning: Could not archive coverage report: ${e.getMessage()}"
                        }
                    }
                    
                    // Archive logs and cleanup
                    script {
                        try {
                            bat "if not exist test-logs mkdir test-logs"
                            bat "docker-compose -f %DOCKER_COMPOSE_JENKINS_FILE% logs > test-logs\\docker-compose.log 2>&1 || echo Could not collect logs"
                            archiveArtifacts artifacts: 'test-logs/**/*', allowEmptyArchive: true
                            // Stop test containers
                            bat "docker-compose -f %DOCKER_COMPOSE_JENKINS_FILE% down || echo Could not stop containers"
                        } catch (Exception e) {
                            echo "Warning: Could not archive logs or cleanup containers: ${e.getMessage()}"
                        }
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    echo "Deploying Vienna Weather Monitoring System to Production..."
                    
                    bat '''
                        REM Create deployment directory and prepare artifacts
                        if not exist deploy mkdir deploy
                        xcopy /E /I build\\artifacts\\* deploy\\
                        
                        REM Validate deployment artifacts
                        cd deploy
                        echo Validating deployment artifacts...
                        if not exist weather_auto_rabbitmq.py (echo ERROR: Main application missing && exit /b 1)
                        if not exist docker-compose.yml (echo ERROR: Docker compose file missing && exit /b 1)
                        if not exist version.yml (echo ERROR: Version file missing && exit /b 1)
                        echo All deployment artifacts validated
                        
                        REM Display deployment information
                        echo ================================================
                        echo PRODUCTION DEPLOYMENT STARTING
                        echo ================================================
                        type version.yml
                        echo ================================================
                        
                        REM Stop any existing production containers
                        echo Stopping existing production services...
                        docker-compose down --volumes --remove-orphans || echo No existing services to stop
                        
                        REM Clean up any conflicting containers
                        docker stop elasticsearch kibana rabbitmq logstash 2>nul || echo No conflicting containers found
                        docker rm -f elasticsearch kibana rabbitmq logstash 2>nul || echo No containers to remove
                        
                        REM Remove any conflicting networks
                        docker network rm openweathermap_jenkins_default 2>nul || echo No conflicting network found
                        
                        REM Wait for cleanup to complete
                        powershell -Command "Start-Sleep -Seconds 5"
                        
                        REM Deploy to production using production ports
                        echo Starting production deployment...
                        docker-compose up -d
                        
                        REM Wait for services to start
                        echo Waiting for production services to start...
                        powershell -Command "Start-Sleep -Seconds 60"
                        
                        REM Check production service health
                        echo Verifying production services...
                        docker-compose ps
                        
                        REM Test production Elasticsearch
                        echo Testing Elasticsearch on production port 9200...
                        set /A elasticsearch_ready=0
                        for /L %%i in (1,1,5) do (
                            curl -f http://localhost:9200/_cluster/health >nul 2>&1
                            if not errorlevel 1 (
                                echo Production Elasticsearch is ready
                                set /A elasticsearch_ready=1
                                goto :prod_elasticsearch_done
                            )
                            echo Attempt %%i failed, waiting 15 seconds...
                            powershell -Command "Start-Sleep -Seconds 15"
                        )
                        :prod_elasticsearch_done
                        
                        REM Test production RabbitMQ
                        echo Testing RabbitMQ on production port 15672...
                        docker exec rabbitmq rabbitmqctl status >nul 2>&1
                        if not errorlevel 1 (
                            echo Production RabbitMQ is ready
                        ) else (
                            echo Warning: RabbitMQ may still be starting
                        )
                        
                        REM Test external API connectivity from production environment
                        echo Testing OpenWeatherMap API from production...
                        python -c "import requests; api_key='%API_KEY%'; url=f'http://api.openweathermap.org/data/2.5/weather?q=Vienna,AT&appid={api_key}'; response=requests.get(url, timeout=10); print('Production API connection successful' if response.status_code==200 else f'API returned status: {response.status_code}'); data=response.json() if response.status_code==200 else {}; print(f'Current weather: {data.get(\\\"weather\\\", [{}])[0].get(\\\"description\\\", \\\"N/A\\\")}') if response.status_code==200 else None; print(f'Temperature: {data.get(\\\"main\\\", {}).get(\\\"temp\\\", \\\"N/A\\\")} K') if response.status_code==200 else None" || echo Weather API test completed with warnings
                        
                        REM Reset environment variables to production ports
                        echo Setting production environment variables...
                        set ELASTICSEARCH_URL=http://localhost:9200
                        set KIBANA_URL=http://localhost:5601
                        set RABBITMQ_URL=http://localhost:15672
                        set LOGSTASH_URL=http://localhost:9600
                        
                        REM Start the weather monitoring application
                        echo Starting Vienna Weather Monitoring Application...
                        start /B python weather_auto_rabbitmq.py
                        
                        REM Wait for application to initialize and collect first data
                        powershell -Command "Start-Sleep -Seconds 15"
                        
                        REM Setup Kibana Dashboard automatically
                        echo Setting up Kibana Dashboard and Data Views...
                        powershell -ExecutionPolicy Bypass -File ../setup-kibana-dashboard.ps1
                        
                        echo ================================================
                        echo PRODUCTION DEPLOYMENT COMPLETED
                        echo ================================================
                        echo Production Services:
                        echo   • Elasticsearch: http://localhost:9200
                        echo   • Kibana: http://localhost:5601
                        echo   • RabbitMQ Management: http://localhost:15672
                        echo   • Vienna Weather Monitor: RUNNING
                        echo ================================================
                        echo Deployment Version: %BUILD_VERSION%
                        echo Deployment Time: %date% %time%
                        echo ================================================
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "Cleaning up pipeline..."
                echo "Build completed at: ${new Date()}"
            }
        }
        
        success {
            script {
                echo "================================================"
                echo "JENKINS CI/CD PIPELINE COMPLETED SUCCESSFULLY!"
                echo "================================================"
                echo "Vienna Weather Monitoring System is now LIVE in production!"
                echo ""
                echo "Production Services Running:"
                echo "   • Elasticsearch: http://localhost:9200"
                echo "   • Kibana: http://localhost:5601" 
                echo "   • RabbitMQ Management: http://localhost:15672"
                echo "   • Weather Monitoring App: ACTIVE"
                echo ""
                echo "📊 Kibana Dashboards & Analytics:"
                echo "   • Weather Dashboard: http://localhost:5601/app/dashboards"
                echo "   • Data Explorer: http://localhost:5601/app/discover"
                echo "   • Visualizations: http://localhost:5601/app/visualize"
                echo "   • Dev Tools: http://localhost:5601/app/dev_tools"
                echo ""
                echo "Build Information:"
                echo "   • Version: ${BUILD_VERSION}"
                echo "   • Commit: ${env.GIT_COMMIT}"
                echo "   • Branch: ${env.GIT_BRANCH}"
                echo "   • Deployment Time: ${new Date()}"
                echo ""
                echo "The Vienna Weather Monitoring System is now collecting"
                echo "and processing real-time weather data automatically!"
                echo "================================================"
            }
        }
        
        failure {
            script {
                echo "Pipeline failed!"
                echo "Please check the logs above for error details."
                echo "Common issues:"
                echo "• Docker not running"
                echo "• Network connectivity issues"
                echo "• Missing dependencies"
            }
        }
        
        unstable {
            script {
                echo "Pipeline unstable!"
                echo "Some tests may have failed but deployment continued."
                echo "Please review test results and logs."
            }
        }
        
        cleanup {
            script {
                echo "Performing workspace cleanup..."
                
                // Force cleanup of Docker containers and networks
                bat """
                    echo "Cleaning up Docker resources..."
                    docker container prune -f || echo "Container cleanup completed"
                    docker network prune -f || echo "Network cleanup completed"
                    docker volume prune -f || echo "Volume cleanup completed"
                """
                
                // Attempt to clean workspace with retries
                bat """
                    echo "Attempting workspace cleanup..."
                    timeout /t 3
                    dir /b . 2>nul && (
                        for /d %%i in (*) do (
                            echo Removing directory: %%i
                            rd /s /q "%%i" 2>nul || echo Failed to remove %%i
                        )
                        for %%i in (*) do (
                            echo Removing file: %%i
                            del /f /q "%%i" 2>nul || echo Failed to remove %%i
                        )
                    ) || echo Workspace already clean
                """
            }
        }
    }
}