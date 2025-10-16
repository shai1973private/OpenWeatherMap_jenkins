# Quick Jenkins Restart Script
# Run this if you continue to have workspace issues

Write-Host "Jenkins Restart Helper" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan

# Check if Jenkins is running as a service
$service = Get-Service -Name "Jenkins" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "Found Jenkins service, restarting..." -ForegroundColor Yellow
    Stop-Service -Name "Jenkins" -Force
    Start-Sleep -Seconds 10
    Start-Service -Name "Jenkins"
    Write-Host "Jenkins service restarted" -ForegroundColor Green
} else {
    Write-Host "Jenkins is not running as a service" -ForegroundColor Yellow
    Write-Host "Please manually restart your Jenkins instance" -ForegroundColor Yellow
    
    # Try to find Jenkins processes
    $javaProcesses = Get-Process -Name "java" -ErrorAction SilentlyContinue
    if ($javaProcesses) {
        Write-Host "Found Java processes (may include Jenkins):" -ForegroundColor Yellow
        $javaProcesses | ForEach-Object {
            Write-Host "  PID: $($_.Id) - $($_.ProcessName)" -ForegroundColor Gray
        }
        Write-Host "You may need to manually stop and restart Jenkins" -ForegroundColor Yellow
    }
}

Write-Host "`nAlternatively, your updated Jenkinsfile should avoid workspace issues" -ForegroundColor Green
Write-Host "by using a unique workspace path for each build." -ForegroundColor Green