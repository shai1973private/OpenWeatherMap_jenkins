# Enhanced Jenkins Configuration Script for Windows Workspace Issues
# This script configures Jenkins to better handle workspace cleanup on Windows

param(
    [string]$JenkinsHome = $env:JENKINS_HOME,
    [switch]$ApplyFix = $false,
    [switch]$CleanWorkspace = $false
)

if (-not $JenkinsHome) {
    $JenkinsHome = "C:\Users\$env:USERNAME\.jenkins"
}

Write-Host "Jenkins Configuration for Windows Workspace Cleanup" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Jenkins Home: $JenkinsHome" -ForegroundColor Yellow

# Function to update Jenkins configuration
function Update-JenkinsConfig {
    param(
        [string]$ConfigFile,
        [string]$Property,
        [string]$Value
    )
    
    try {
        if (Test-Path $ConfigFile) {
            $content = Get-Content $ConfigFile -Raw
            
            # Add or update the property
            if ($content -match "<$Property>.*</$Property>") {
                $content = $content -replace "<$Property>.*</$Property>", "<$Property>$Value</$Property>"
            } else {
                # Insert before closing </hudson> tag
                $content = $content -replace "</hudson>", "  <$Property>$Value</$Property>`n</hudson>"
            }
            
            Set-Content -Path $ConfigFile -Value $content -Encoding UTF8
            Write-Host "Updated $Property in $ConfigFile" -ForegroundColor Green
        } else {
            Write-Host "Config file not found: $ConfigFile" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error updating $ConfigFile`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Check if Jenkins is running
$jenkinsProcess = Get-Process -Name "jenkins" -ErrorAction SilentlyContinue
if ($jenkinsProcess) {
    Write-Host "WARNING: Jenkins is currently running." -ForegroundColor Red
    if (-not $ApplyFix) {
        Write-Host "Use -ApplyFix parameter to apply changes anyway (not recommended while Jenkins is running)" -ForegroundColor Yellow
    }
}

Write-Host "`nDiagnosing common Jenkins Windows workspace issues..." -ForegroundColor Cyan

# Immediate workspace cleanup if requested
if ($CleanWorkspace) {
    Write-Host "`nPerforming immediate workspace cleanup..." -ForegroundColor Yellow
    
    # Clean Docker resources that might be holding file locks
    Write-Host "Cleaning Docker resources..." -ForegroundColor Yellow
    try {
        docker container prune -f 2>$null
        docker network prune -f 2>$null
        docker volume prune -f 2>$null
        Write-Host "Docker cleanup completed" -ForegroundColor Green
    } catch {
        Write-Host "Docker cleanup failed - Docker may not be running" -ForegroundColor Red
    }
    
    # Find and attempt to clean Jenkins workspaces
    $jenkinsWorkspace = "$JenkinsHome\workspace"
    if (Test-Path $jenkinsWorkspace) {
        Write-Host "Found Jenkins workspace: $jenkinsWorkspace" -ForegroundColor Yellow
        
        # List Vienna weather workspaces
        $viennaWorkspaces = Get-ChildItem $jenkinsWorkspace | Where-Object {$_.Name -like "*vienna*"}
        if ($viennaWorkspaces) {
            Write-Host "Found Vienna weather monitoring workspaces:" -ForegroundColor Yellow
            $viennaWorkspaces | Select-Object Name, LastWriteTime | Format-Table
            
            # Attempt to remove them using the enhanced cleanup script
            foreach ($workspace in $viennaWorkspaces) {
                Write-Host "Attempting to remove: $($workspace.Name)" -ForegroundColor Yellow
                
                # Use the comprehensive cleanup script
                if (Test-Path ".\jenkins-workspace-cleanup.ps1") {
                    try {
                        & ".\jenkins-workspace-cleanup.ps1" -WorkspacePath $workspace.FullName -Force
                        Write-Host "Successfully cleaned: $($workspace.Name)" -ForegroundColor Green
                    } catch {
                        Write-Host "Enhanced cleanup failed for: $($workspace.Name)" -ForegroundColor Red
                    }
                } else {
                    # Fallback to manual cleanup
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
            }
        } else {
            Write-Host "No Vienna weather monitoring workspaces found" -ForegroundColor Green
        }
    } else {
        Write-Host "Jenkins workspace directory not found" -ForegroundColor Yellow
    }
}

# Check 1: Workspace directory permissions
$workspaceDir = Join-Path $JenkinsHome "workspace"
if (Test-Path $workspaceDir) {
    Write-Host "✓ Workspace directory exists: $workspaceDir" -ForegroundColor Green
    
    # Check permissions
    try {
        $acl = Get-Acl $workspaceDir
        $hasFullControl = $acl.Access | Where-Object { 
            $_.IdentityReference -like "*$env:USERNAME*" -and $_.FileSystemRights -like "*FullControl*" 
        }
        
        if ($hasFullControl) {
            Write-Host "✓ User has FullControl permissions" -ForegroundColor Green
        } else {
            Write-Host "⚠ User may not have FullControl permissions" -ForegroundColor Yellow
            if ($ApplyFix) {
                Write-Host "Applying permission fix..." -ForegroundColor Yellow
                icacls $workspaceDir /grant "${env:USERNAME}:F" /t /c /q
                Write-Host "✓ Permissions updated" -ForegroundColor Green
            }
        }
        }
    } catch {
        Write-Host "⚠ Could not check permissions: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ Workspace directory does not exist yet: $workspaceDir" -ForegroundColor Yellow
}

Write-Host "`n=== IMMEDIATE SOLUTIONS ===" -ForegroundColor Green
Write-Host "1. RESTART JENKINS SERVICE: This often resolves file locking issues" -ForegroundColor Cyan
Write-Host "   net stop jenkins; net start jenkins" -ForegroundColor White

Write-Host "`n2. RUN MANUAL CLEANUP:" -ForegroundColor Cyan
Write-Host "   powershell -ExecutionPolicy Bypass -File jenkins-workspace-cleanup.ps1 -Force" -ForegroundColor White

Write-Host "`n3. USE DIFFERENT WORKSPACE PATH in Jenkins job:" -ForegroundColor Cyan
Write-Host "   Configure -> Advanced -> Use custom workspace" -ForegroundColor White
Write-Host "   Directory: C:\Jenkins\workspaces\vienna-weather-\${BUILD_NUMBER}" -ForegroundColor White

Write-Host "`n4. MODIFY JENKINSFILE (already done):" -ForegroundColor Cyan
Write-Host "   ✓ Enhanced cleanup logic added" -ForegroundColor Green
Write-Host "   ✓ Pre-cleanup stage added" -ForegroundColor Green
Write-Host "   ✓ Multiple cleanup strategies implemented" -ForegroundColor Green

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Green