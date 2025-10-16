# Jenkins Setup Script for Vienna Weather Monitoring System
# Run this script as Administrator

Write-Host "🚀 Setting up Jenkins for Vienna Weather Monitoring System" -ForegroundColor Green

# Configuration
$JENKINS_HOME = "C:\Jenkins"
$JENKINS_PORT = 8080
$JAVA_VERSION = "11"

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Running as Administrator" -ForegroundColor Green

# Check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    refreshenv
} else {
    Write-Host "✅ Chocolatey already installed" -ForegroundColor Green
}

# Install Java (OpenJDK 11)
Write-Host "☕ Installing Java..." -ForegroundColor Yellow
try {
    choco install openjdk11 -y
    Write-Host "✅ Java installed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install Java: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Install Git (if not already installed)
Write-Host "📝 Installing Git..." -ForegroundColor Yellow
try {
    choco install git -y
    Write-Host "✅ Git installed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install Git: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Install Docker Desktop (if not already installed)
Write-Host "🐳 Installing Docker Desktop..." -ForegroundColor Yellow
try {
    choco install docker-desktop -y
    Write-Host "✅ Docker Desktop installed successfully" -ForegroundColor Green
    Write-Host "⚠️  Please restart your computer and start Docker Desktop manually" -ForegroundColor Yellow
} catch {
    Write-Host "❌ Failed to install Docker Desktop: $($_.Exception.Message)" -ForegroundColor Red
}

# Create Jenkins directory
Write-Host "📁 Creating Jenkins directory..." -ForegroundColor Yellow
if (-not (Test-Path $JENKINS_HOME)) {
    New-Item -ItemType Directory -Path $JENKINS_HOME -Force
    Write-Host "✅ Jenkins directory created: $JENKINS_HOME" -ForegroundColor Green
} else {
    Write-Host "✅ Jenkins directory already exists: $JENKINS_HOME" -ForegroundColor Green
}

# Download Jenkins WAR file
Write-Host "📥 Downloading Jenkins..." -ForegroundColor Yellow
$JENKINS_WAR = "$JENKINS_HOME\jenkins.war"
$JENKINS_URL = "https://get.jenkins.io/war-stable/latest/jenkins.war"

try {
    Invoke-WebRequest -Uri $JENKINS_URL -OutFile $JENKINS_WAR -UseBasicParsing
    Write-Host "✅ Jenkins downloaded successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to download Jenkins: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create Jenkins service script
Write-Host "🔧 Creating Jenkins service script..." -ForegroundColor Yellow
$serviceScript = @"
@echo off
cd /d $JENKINS_HOME
java -jar jenkins.war --httpPort=$JENKINS_PORT
"@

$serviceScript | Out-File -FilePath "$JENKINS_HOME\start-jenkins.bat" -Encoding ASCII
Write-Host "✅ Jenkins service script created" -ForegroundColor Green

# Create Jenkins configuration directory
$configDir = "$JENKINS_HOME\jenkins_config"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force
}

# Copy plugins list
Write-Host "📋 Creating plugins list..." -ForegroundColor Yellow
$pluginsList = @"
pipeline-stage-view
workflow-aggregator
git
docker-workflow
blueocean
junit
coverage
warnings-ng
timestamper
build-timeout
credentials-binding
ws-cleanup
ansible
"@

$pluginsList | Out-File -FilePath "$configDir\plugins.txt" -Encoding ASCII

# Create Jenkins initialization script
Write-Host "🔧 Creating initialization script..." -ForegroundColor Yellow
$initScript = @"
# Jenkins Initialization Script
# Run this after Jenkins first startup

# Install plugins
java -jar jenkins-cli.jar -s http://localhost:$JENKINS_PORT/ install-plugin \
    pipeline-stage-view \
    workflow-aggregator \
    git \
    docker-workflow \
    blueocean \
    junit \
    coverage \
    warnings-ng \
    timestamper \
    build-timeout \
    credentials-binding \
    ws-cleanup

# Restart Jenkins
java -jar jenkins-cli.jar -s http://localhost:$JENKINS_PORT/ restart
"@

$initScript | Out-File -FilePath "$configDir\install-plugins.sh" -Encoding ASCII

# Create Windows service (optional)
Write-Host "🔧 Setting up Jenkins as Windows Service (optional)..." -ForegroundColor Yellow
$serviceExists = Get-Service -Name "Jenkins" -ErrorAction SilentlyContinue

if (-not $serviceExists) {
    try {
        # Using NSSM (Non-Sucking Service Manager) for better service management
        choco install nssm -y
        
        # Install Jenkins as service
        & nssm install Jenkins java
        & nssm set Jenkins Arguments "-jar `"$JENKINS_WAR`" --httpPort=$JENKINS_PORT"
        & nssm set Jenkins AppDirectory "$JENKINS_HOME"
        & nssm set Jenkins DisplayName "Jenkins CI/CD Server"
        & nssm set Jenkins Description "Jenkins CI/CD Server for Vienna Weather Monitoring"
        & nssm set Jenkins Start SERVICE_AUTO_START
        
        Write-Host "✅ Jenkins service installed successfully" -ForegroundColor Green
        Write-Host "   Service name: Jenkins" -ForegroundColor Cyan
        Write-Host "   Start command: net start Jenkins" -ForegroundColor Cyan
        Write-Host "   Stop command: net stop Jenkins" -ForegroundColor Cyan
    } catch {
        Write-Host "⚠️  Failed to install Jenkins service: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   You can start Jenkins manually using: $JENKINS_HOME\start-jenkins.bat" -ForegroundColor Cyan
    }
} else {
    Write-Host "✅ Jenkins service already exists" -ForegroundColor Green
}

# Create desktop shortcut
Write-Host "🔗 Creating desktop shortcut..." -ForegroundColor Yellow
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Jenkins.lnk")
$Shortcut.TargetPath = "http://localhost:$JENKINS_PORT"
$Shortcut.Save()

# Firewall rule for Jenkins
Write-Host "🔥 Configuring Windows Firewall..." -ForegroundColor Yellow
try {
    New-NetFirewallRule -DisplayName "Jenkins HTTP" -Direction Inbound -Protocol TCP -LocalPort $JENKINS_PORT -Action Allow
    Write-Host "✅ Firewall rule created for port $JENKINS_PORT" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Failed to create firewall rule: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Final instructions
Write-Host "`n🎉 Jenkins setup completed!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue

Write-Host "`n📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Start Docker Desktop (if not already running)" -ForegroundColor White
Write-Host "2. Start Jenkins using one of these methods:" -ForegroundColor White
Write-Host "   • Service: net start Jenkins" -ForegroundColor Cyan
Write-Host "   • Manual: Double-click $JENKINS_HOME\start-jenkins.bat" -ForegroundColor Cyan
Write-Host "   • Desktop shortcut: Jenkins.lnk" -ForegroundColor Cyan
Write-Host "`n3. Access Jenkins at: http://localhost:$JENKINS_PORT" -ForegroundColor White
Write-Host "4. Get initial admin password from: $JENKINS_HOME\secrets\initialAdminPassword" -ForegroundColor White
Write-Host "5. Install suggested plugins + additional plugins from: $configDir\plugins.txt" -ForegroundColor White
Write-Host "6. Create admin user and complete setup wizard" -ForegroundColor White
Write-Host "7. Import job configuration from: jenkins-config.xml" -ForegroundColor White

Write-Host "`n🔧 Configuration Files:" -ForegroundColor Yellow
Write-Host "• Jenkins Home: $JENKINS_HOME" -ForegroundColor Cyan
Write-Host "• Start script: $JENKINS_HOME\start-jenkins.bat" -ForegroundColor Cyan
Write-Host "• Plugins list: $configDir\plugins.txt" -ForegroundColor Cyan
Write-Host "• Job config: jenkins-config.xml (in project root)" -ForegroundColor Cyan

Write-Host "`n📚 Documentation:" -ForegroundColor Yellow
Write-Host "• Project README: README_JENKINS.md" -ForegroundColor Cyan
Write-Host "• Jenkins URL: http://localhost:$JENKINS_PORT" -ForegroundColor Cyan
Write-Host "• Pipeline will be available at: http://localhost:$JENKINS_PORT/job/vienna-weather-monitoring-cicd/" -ForegroundColor Cyan

Write-Host "`n🚀 Ready to start your Jenkins CI/CD journey!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue