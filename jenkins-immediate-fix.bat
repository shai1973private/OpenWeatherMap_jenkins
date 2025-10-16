@echo off
echo ============================================
echo Jenkins Workspace Cleanup - Immediate Fix
echo ============================================
echo.

echo Stopping any background processes that might lock files...
taskkill /f /im python.exe 2>nul || echo No Python processes to stop
taskkill /f /im node.exe 2>nul || echo No Node processes to stop
taskkill /f /im java.exe 2>nul || echo No Java processes to stop
taskkill /f /im git.exe 2>nul || echo No Git processes to stop

echo.
echo Cleaning Docker resources...
docker stop $(docker ps -q) 2>nul || echo No containers to stop
docker rm -f $(docker ps -a -q) 2>nul || echo No containers to remove
docker system prune -f 2>nul || echo Docker cleanup completed

echo.
echo Attempting to clean Jenkins workspace...
set JENKINS_WORKSPACE=%USERPROFILE%\.jenkins\workspace\vienna-weather-monitoring-cicd

if exist "%JENKINS_WORKSPACE%" (
    echo Found workspace: %JENKINS_WORKSPACE%
    echo Removing read-only attributes...
    attrib -r -s -h "%JENKINS_WORKSPACE%\*.*" /s /d 2>nul
    
    echo Taking ownership...
    takeown /f "%JENKINS_WORKSPACE%" /r /d y 2>nul
    icacls "%JENKINS_WORKSPACE%" /grant administrators:F /t /c /q 2>nul
    
    echo Attempting to remove workspace...
    rd /s /q "%JENKINS_WORKSPACE%" 2>nul
    
    if exist "%JENKINS_WORKSPACE%" (
        echo Standard removal failed, trying robocopy method...
        mkdir "%TEMP%\empty_dir" 2>nul
        robocopy "%TEMP%\empty_dir" "%JENKINS_WORKSPACE%" /mir /nfl /ndl /njh /njs 2>nul
        rd /s /q "%JENKINS_WORKSPACE%" 2>nul
        rd /s /q "%TEMP%\empty_dir" 2>nul
    )
    
    if exist "%JENKINS_WORKSPACE%" (
        echo Workspace still exists, but may be partially cleaned
    ) else (
        echo Workspace successfully removed!
    )
) else (
    echo Workspace does not exist or already cleaned
)

echo.
echo ============================================
echo IMMEDIATE SOLUTIONS:
echo ============================================
echo 1. Restart Jenkins Service:
echo    net stop jenkins
echo    timeout /t 5
echo    net start jenkins
echo.
echo 2. If Jenkins is not a service, restart it manually
echo.
echo 3. Try running this script as Administrator
echo.
echo 4. Use a different workspace path in Jenkins job:
echo    Configure ^> Advanced ^> Use custom workspace
echo    Directory: C:\Jenkins\workspaces\vienna-weather-%%BUILD_NUMBER%%
echo ============================================
echo.
pause