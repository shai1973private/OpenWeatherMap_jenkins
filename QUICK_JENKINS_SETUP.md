# Quick Jenkins Setup Guide for Your System

## ✅ Prerequisites Check
- ✅ Java 11 installed
- ✅ Git installed  
- ❓ Docker (need to verify/install)

## 🚀 Quick Setup Steps

### 1. Install Docker Desktop (if not installed)
Download and install from: https://www.docker.com/products/docker-desktop/

### 2. Download and Start Jenkins
```powershell
# Create Jenkins directory
mkdir C:\Jenkins
cd C:\Jenkins

# Download Jenkins WAR file
Invoke-WebRequest -Uri "https://get.jenkins.io/war-stable/latest/jenkins.war" -OutFile "jenkins.war"

# Start Jenkins
java -jar jenkins.war --httpPort=8080
```

### 3. Initial Jenkins Setup
1. Open browser: http://localhost:8080
2. Get initial password from console output or:
   ```powershell
   Get-Content "C:\Users\$env:USERNAME\.jenkins\secrets\initialAdminPassword"
   ```
3. Install suggested plugins + these additional ones:
   - Pipeline: Job
   - Pipeline: Stage View  
   - Git
   - Docker Pipeline
   - Blue Ocean
   - JUnit
   - Coverage

### 4. Create Admin User
- Username: admin
- Password: [your choice]
- Full name: [your name]
- Email: [your email]

### 5. Import Your Pipeline
1. New Item → Pipeline
2. Name: `vienna-weather-monitoring-cicd`
3. Pipeline Definition: Pipeline script from SCM
4. SCM: Git
5. Repository URL: `https://github.com/shai1973private/OpenWeatherMap_jenkins.git`
6. Branch: `*/main`
7. Script Path: `Jenkinsfile`

### 6. Configure Credentials
Go to Manage Jenkins → Credentials → Global:

1. **GitHub Credentials**
   - Kind: Username with password
   - Username: shai1973private
   - Password: [GitHub token]
   - ID: `github-credentials`

2. **OpenWeatherMap API Key**
   - Kind: Secret text
   - Secret: `7ea63a60ef095d75baf077171165c148`
   - ID: `openweathermap-api-key`

### 7. Run Your First Build
1. Go to your pipeline job
2. Click "Build Now"
3. Watch the magic happen! 🎉

## 🔧 Troubleshooting
- If Jenkins doesn't start: Check if port 8080 is free
- If Docker issues: Make sure Docker Desktop is running
- If Git issues: Verify GitHub access

Ready to start? 🚀