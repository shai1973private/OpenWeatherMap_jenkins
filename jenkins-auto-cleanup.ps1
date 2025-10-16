# Jenkins Workspace Auto-Cleanup Script
# This script automatically handles workspace cleanup issues

Write-Host "=== Jenkins Workspace Auto-Cleanup ===" -ForegroundColor Green

# Function to force delete Jenkins workspaces
function Remove-JenkinsWorkspace {
    param([string]$WorkspacePath)
    
    if (Test-Path $WorkspacePath) {
        Write-Host "Attempting to remove: $WorkspacePath" -ForegroundColor Yellow
        
        # Method 1: Standard PowerShell removal
        try {
            Remove-Item $WorkspacePath -Recurse -Force -ErrorAction Stop
            Write-Host "✓ Successfully removed with PowerShell" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "PowerShell method failed, trying alternative..." -ForegroundColor Yellow
        }
        
        # Method 2: CMD with takeown
        try {
            takeown /f $WorkspacePath /r /d y 2>$null | Out-Null
            icacls $WorkspacePath /grant administrators:F /t 2>$null | Out-Null
            cmd /c "rd /s /q `"$WorkspacePath`"" 2>$null
            
            if (-not (Test-Path $WorkspacePath)) {
                Write-Host "✓ Successfully removed with takeown" -ForegroundColor Green
                return $true
            }
        } catch {
            Write-Host "Takeown method failed, trying robocopy..." -ForegroundColor Yellow
        }
        
        # Method 3: Robocopy purge
        try {
            $emptyDir = "$env:TEMP\empty_$(Get-Random)"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
            robocopy $emptyDir $WorkspacePath /purge /e 2>$null | Out-Null
            Remove-Item $emptyDir -Force -ErrorAction SilentlyContinue
            Remove-Item $WorkspacePath -Recurse -Force -ErrorAction SilentlyContinue
            
            if (-not (Test-Path $WorkspacePath)) {
                Write-Host "✓ Successfully removed with robocopy" -ForegroundColor Green
                return $true
            }
        } catch {
            Write-Host "All automated methods failed" -ForegroundColor Red
        }
    }
    return $false
}

# Clean Vienna weather monitoring workspaces
$workspaceRoot = "$env:USERPROFILE\.jenkins\workspace"
if (Test-Path $workspaceRoot) {
    $viennaWorkspaces = Get-ChildItem $workspaceRoot | Where-Object {$_.Name -like "*vienna*"}
    
    if ($viennaWorkspaces) {
        Write-Host "Found Vienna workspaces to clean:" -ForegroundColor Cyan
        foreach ($workspace in $viennaWorkspaces) {
            Write-Host "  - $($workspace.Name)" -ForegroundColor White
            Remove-JenkinsWorkspace -WorkspacePath $workspace.FullName
        }
    } else {
        Write-Host "No Vienna workspaces found to clean" -ForegroundColor Green
    }
} else {
    Write-Host "Jenkins workspace directory not found" -ForegroundColor Yellow
}

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Green