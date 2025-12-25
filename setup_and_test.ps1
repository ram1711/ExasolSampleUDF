# Function to check Docker logs for specific text
function Wait-ForDockerLog {
    param(
        [string]$ContainerName,
        [string]$SearchText,
        [int]$MaxWaitMinutes = 5
    )
    
    Write-Host "Exasol Container in running waiting for stability..." -ForegroundColor Yellow
    
    $endTime = (Get-Date).AddMinutes($MaxWaitMinutes)
    $attempt = 0
    
    while ((Get-Date) -lt $endTime) {
        $attempt++
        Write-Host "Attempt $attempt - Checking stability..." -ForegroundColor Cyan
        
        # Get last 100 lines of Docker logs
        $logs = docker logs $ContainerName --tail 100 2>&1
        
        # Check if search text exists
        if ($logs -match $SearchText) {
            Write-Host "Exasol is stable!" -ForegroundColor Green
            return $true
        }
        
        Write-Host "Not ready yet. waiting 30 seconds..." -ForegroundColor Yellow
        
        for ($totalSec = 30; $totalSec -gt 0; $totalSec--) {
          $min = [math]::Floor($totalSec / 60)
          $sec = $totalSec % 60
          Write-Host "`rNext check in: $($min.ToString('00')):$($sec.ToString('00'))   " -ForegroundColor Yellow -NoNewline
          Start-Sleep 1
        }
        Write-Host "`rNext check in: 00:00   " -ForegroundColor Yellow -NoNewline
        Write-Host ""
    }
    
    Write-Host "Timeout: '$SearchText' not found after $MaxWaitMinutes minutes" -ForegroundColor Red
    return $false
}

Write-Host "Starting Exasol UDF Test Script..." -ForegroundColor Green

Write-Host "Stopping and removing any existing Exasol container..." -ForegroundColor Yellow
docker stop exasol-github-test 2>$null
docker rm exasol-github-test 2>$null

Write-Host "Starting Exasol container..." -ForegroundColor Yellow
docker run -d --name exasol-github-test `
  --platform linux/amd64 `
  --privileged `
  --shm-size 2g `
  --cap-add SYS_ADMIN `
  -p 8563:8563 -p 8560:8560 `
  -e EXASOL_WEB_PORT=8560 `
  -e EXASOL_DOCKER_NAMESERVER=1.1.1.1 `
  exasol/docker-db:latest

if (Wait-ForDockerLog -ContainerName "exasol-github-test" -SearchText "stage6: All stages finished." -MaxWaitMinutes 20) 
{
  Write-Host "Creating virtual environment..." -ForegroundColor Yellow

  rm -r -force ".venv"

  python -m venv .venv
  
  Write-Host "Activating virtual environment..." -ForegroundColor Yellow

  .\.venv\Scripts\Activate.ps1

  Write-Host "Upgrading pip..." -ForegroundColor Yellow

   .\.venv\Scripts\python.exe -m pip install --upgrade pip

  Write-Host "Installing dependencies..." -ForegroundColor Yellow

  .\.venv\Scripts\python.exe -m pip install -r requirements.txt

  
  # Run tests
  Write-Host "Testing UDF..." -ForegroundColor Yellow
  python run.py

  Write-Host "Deactivating virtual environment..." -ForegroundColor Yellow
  deactivate

  Write-Host "Stopping and removing Exasol container..." -ForegroundColor Yellow

  docker stop exasol-github-test
  docker rm exasol-github-test
} else {
    Write-Host "Exasol failed to start in time. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Script Execution Complete!" -ForegroundColor Green
