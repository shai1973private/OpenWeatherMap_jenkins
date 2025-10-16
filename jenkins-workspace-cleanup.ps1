# Enhanced Jenkins Workspace Cleanup Script for Windows
# This script handles common Windows file locking and permission issues

param(
    [string]$WorkspacePath = $null,
    [switch]$Force = $false,
    [switch]$Verbose = $false
)

# Function to write colored output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Info($message) {
    Write-ColorOutput Cyan "INFO: $message"
}

function Write-Warning($message) {
    Write-ColorOutput Yellow "WARNING: $message"
}

function Write-Error($message) {
    Write-ColorOutput Red "ERROR: $message"
}

function Write-Success($message) {
    Write-ColorOutput Green "SUCCESS: $message"
}

# Set workspace path if not provided
if (-not $WorkspacePath) {
    $WorkspacePath = $env:WORKSPACE
    if (-not $WorkspacePath) {
        $WorkspacePath = Get-Location
    }
}

Write-Info "Starting enhanced workspace cleanup for: $WorkspacePath"

# Step 1: Stop all Docker containers and clean up Docker resources
Write-Info "Step 1: Cleaning up Docker resources..."
try {
    # Stop all running containers
    $containers = docker ps -q
    if ($containers) {
        Write-Info "Stopping running Docker containers..."
        docker stop $containers 2>$null
        Start-Sleep -Seconds 5
    }
    
    # Remove all containers
    $allContainers = docker ps -a -q
    if ($allContainers) {
        Write-Info "Removing all Docker containers..."
        docker rm -f $allContainers 2>$null
    }
    
    # Clean up Docker resources
    Write-Info "Cleaning up Docker networks, volumes, and images..."
    docker system prune -f --volumes 2>$null
    docker network prune -f 2>$null
    
    Write-Success "Docker cleanup completed"
} catch {
    Write-Warning "Docker cleanup had issues: $($_.Exception.Message)"
}

# Step 2: Kill processes that might be locking files
Write-Info "Step 2: Terminating processes that might lock workspace files..."
try {
    # Kill common processes that might lock files
    $processesToKill = @("python", "node", "java", "python.exe", "node.exe", "java.exe", "git", "git.exe")
    
    foreach ($processName in $processesToKill) {
        $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($processes) {
            Write-Info "Terminating $($processes.Count) instances of $processName"
            $processes | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Wait for processes to terminate
    Start-Sleep -Seconds 3
    Write-Success "Process cleanup completed"
} catch {
    Write-Warning "Process cleanup had issues: $($_.Exception.Message)"
}

# Step 3: Handle git repository cleanup
Write-Info "Step 3: Git repository cleanup..."
try {
    if (Test-Path "$WorkspacePath\.git") {
        Write-Info "Removing git index locks..."
        Remove-Item "$WorkspacePath\.git\index.lock" -Force -ErrorAction SilentlyContinue
        Remove-Item "$WorkspacePath\.git\*.lock" -Force -ErrorAction SilentlyContinue
        
        # Reset git repository state
        Push-Location $WorkspacePath
        git reset --hard HEAD 2>$null
        git clean -fdx 2>$null
        Pop-Location
    }
    Write-Success "Git cleanup completed"
} catch {
    Write-Warning "Git cleanup had issues: $($_.Exception.Message)"
}

# Step 4: Remove read-only attributes recursively
Write-Info "Step 4: Removing read-only attributes..."
try {
    if (Test-Path $WorkspacePath) {
        # Remove read-only attributes from all files and directories
        Get-ChildItem -Path $WorkspacePath -Recurse -Force -ErrorAction SilentlyContinue | 
        ForEach-Object {
            try {
                $_.Attributes = $_.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
            } catch {
                # Ignore individual file errors
            }
        }
    }
    Write-Success "Read-only attribute removal completed"
} catch {
    Write-Warning "Read-only attribute removal had issues: $($_.Exception.Message)"
}

# Step 5: Take ownership of files and directories
Write-Info "Step 5: Taking ownership of workspace files..."
try {
    if (Test-Path $WorkspacePath) {
        # Take ownership using takeown command
        $takeownResult = & takeown /f "$WorkspacePath" /r /d y 2>&1
        if ($Verbose) {
            Write-Info "Takeown result: $takeownResult"
        }
        
        # Grant full control to administrators
        $icaclsResult = & icacls "$WorkspacePath" /grant "Administrators:F" /t /c /q 2>&1
        if ($Verbose) {
            Write-Info "Icacls result: $icaclsResult"
        }
    }
    Write-Success "Ownership change completed"
} catch {
    Write-Warning "Ownership change had issues: $($_.Exception.Message)"
}

# Step 6: Enhanced file deletion with multiple strategies
Write-Info "Step 6: Enhanced file deletion..."
try {
    if (Test-Path $WorkspacePath) {
        # Strategy 1: PowerShell Remove-Item with force
        Write-Info "Strategy 1: PowerShell force removal..."
        Get-ChildItem -Path $WorkspacePath -Force -ErrorAction SilentlyContinue | 
        ForEach-Object {
            try {
                Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                if ($Verbose) {
                    Write-Warning "Could not remove with PowerShell: $($_.FullName)"
                }
            }
        }
        
        # Strategy 2: CMD deletion
        Write-Info "Strategy 2: CMD deletion..."
        if (Test-Path $WorkspacePath) {
            & cmd /c "cd /d `"$WorkspacePath`" && for /d %i in (*) do rd /s /q `"%i`" 2>nul"
            & cmd /c "cd /d `"$WorkspacePath`" && del /f /s /q * 2>nul"
        }
        
        # Strategy 3: Robocopy method (very effective for stubborn files)
        Write-Info "Strategy 3: Robocopy cleanup..."
        if (Test-Path $WorkspacePath) {
            $emptyDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_.FullName; $_.FullName }
            & robocopy "$emptyDir" "$WorkspacePath" /mir /nfl /ndl /njh /njs 2>$null
            Remove-Item $emptyDir -Force -ErrorAction SilentlyContinue
        }
        
        # Strategy 4: Alternative PowerShell approach
        Write-Info "Strategy 4: Alternative PowerShell cleanup..."
        if (Test-Path $WorkspacePath) {
            Get-ChildItem -Path $WorkspacePath -Force | 
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Success "Enhanced file deletion completed"
} catch {
    Write-Warning "Enhanced file deletion had issues: $($_.Exception.Message)"
}

# Step 7: Final verification and directory removal
Write-Info "Step 7: Final verification and cleanup..."
try {
    if (Test-Path $WorkspacePath) {
        $remainingItems = Get-ChildItem -Path $WorkspacePath -Force -ErrorAction SilentlyContinue
        if ($remainingItems) {
            Write-Warning "Some items remain in workspace:"
            $remainingItems | ForEach-Object { Write-Warning "  - $($_.Name)" }
            
            # Try one more time with different approach
            $remainingItems | ForEach-Object {
                try {
                    if ($_.PSIsContainer) {
                        & cmd /c "rd /s /q `"$($_.FullName)`" 2>nul"
                    } else {
                        & cmd /c "del /f /q `"$($_.FullName)`" 2>nul"
                    }
                } catch {
                    Write-Warning "Final removal failed for: $($_.Name)"
                }
            }
        } else {
            Write-Success "Workspace is now clean!"
        }
    } else {
        Write-Success "Workspace directory does not exist - cleanup not needed"
    }
} catch {
    Write-Warning "Final verification had issues: $($_.Exception.Message)"
}

Write-Info "Enhanced workspace cleanup completed!"

# Return status
$finalCheck = Get-ChildItem -Path $WorkspacePath -Force -ErrorAction SilentlyContinue
if (-not $finalCheck) {
    Write-Success "Workspace cleanup was successful!"
    exit 0
} else {
    Write-Warning "Workspace cleanup was partially successful. $($finalCheck.Count) items remain."
    if ($Force) {
        Write-Info "Force flag was set, continuing anyway..."
        exit 0
    } else {
        exit 1
    }
}