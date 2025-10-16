# Jenkins Workspace Cleanup Fix Script
# This script helps resolve Windows workspace deletion issues

Write-Host "=== Jenkins Workspace Cleanup Fix ===" -ForegroundColor Green

# Stop any running Jenkins processes that might be locking files
Write-Host "Checking for Jenkins processes..." -ForegroundColor Yellow
$jenkinsProcesses = Get-Process | Where-Object {$_.ProcessName -match "jenkins|java.*jenkins"}
if ($jenkinsProcesses) {
    Write-Host "Found Jenkins processes - consider stopping Jenkins service if issues persist" -ForegroundColor Yellow
    $jenkinsProcesses | Select-Object ProcessName, Id | Format-Table
} else {
    Write-Host "No Jenkins processes found" -ForegroundColor Green
}

# Clean Docker resources that might be holding file locks
Write-Host "`nCleaning Docker resources..." -ForegroundColor Yellow
try {
    docker container prune -f
    docker network prune -f
    docker volume prune -f
    Write-Host "Docker cleanup completed" -ForegroundColor Green
} catch {
    Write-Host "Docker cleanup failed - Docker may not be running" -ForegroundColor Red
}

# Find and attempt to clean Jenkins workspaces
$jenkinsWorkspace = "$env:USERPROFILE\.jenkins\workspace"
if (Test-Path $jenkinsWorkspace) {
    Write-Host "`nFound Jenkins workspace: $jenkinsWorkspace" -ForegroundColor Yellow
    
    # List Vienna weather workspaces
    $viennaWorkspaces = Get-ChildItem $jenkinsWorkspace | Where-Object {$_.Name -like "*vienna*"}
    if ($viennaWorkspaces) {
        Write-Host "Found Vienna weather monitoring workspaces:" -ForegroundColor Yellow
        $viennaWorkspaces | Select-Object Name, LastWriteTime | Format-Table
        
        # Attempt to remove them
        foreach ($workspace in $viennaWorkspaces) {
            Write-Host "Attempting to remove: $($workspace.Name)" -ForegroundColor Yellow
            try {
                Remove-Item $workspace.FullName -Recurse -Force -ErrorAction Stop
                Write-Host "Successfully removed: $($workspace.Name)" -ForegroundColor Green
            } catch {
                Write-Host "Failed to remove: $($workspace.Name) - $($_.Exception.Message)" -ForegroundColor Red
                
                # Try alternative method using cmd
                Write-Host "Trying alternative removal method..." -ForegroundColor Yellow
                try {
                    cmd /c "rd /s /q `"$($workspace.FullName)`""
                    Write-Host "Alternative removal successful for: $($workspace.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "Alternative removal also failed for: $($workspace.Name)" -ForegroundColor Red
                }
            }
        }
    } else {
        Write-Host "No Vienna weather monitoring workspaces found" -ForegroundColor Green
    }
} else {
    Write-Host "Jenkins workspace directory not found" -ForegroundColor Yellow
}

Write-Host "`n=== Solutions for Workspace Deletion Issues ===" -ForegroundColor Green
Write-Host "1. RESTART JENKINS SERVICE: This often resolves file locking issues" -ForegroundColor Cyan
Write-Host "   - Stop Jenkins service in Services.msc" -ForegroundColor White
Write-Host "   - Wait 10 seconds" -ForegroundColor White
Write-Host "   - Start Jenkins service" -ForegroundColor White

Write-Host "`n2. UPDATE JENKINS CONFIGURATION:" -ForegroundColor Cyan
Write-Host "   - Go to Jenkins -> Manage Jenkins -> Configure System" -ForegroundColor White
Write-Host "   - Find 'Workspace Cleanup Plugin' settings" -ForegroundColor White
Write-Host "   - Enable 'Delete workspace when build is done'" -ForegroundColor White

Write-Host "`n3. USE UPDATED JENKINSFILE:" -ForegroundColor Cyan
Write-Host "   - The Jenkinsfile has been updated with better cleanup handling" -ForegroundColor White
Write-Host "   - Includes retry logic and manual cleanup fallbacks" -ForegroundColor White

Write-Host "`n4. ALTERNATIVE: Use different Jenkins workspace directory" -ForegroundColor Cyan
Write-Host "   - Configure Jenkins to use a different workspace root" -ForegroundColor White
Write-Host "   - Manage Jenkins -> Configure System -> Workspace Root Directory" -ForegroundColor White

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Green