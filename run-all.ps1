# Run Smart Warehouse backend and open frontend in browser
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$backendNode = Join-Path $root 'backend'
$pb = Join-Path $root 'python_backend'
$venvPy = Join-Path $pb '.venv\Scripts\python.exe'

# Check if Node is available
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host 'Starting Node.js / Express backend...' -ForegroundColor Green
    Set-Location $backendNode
    npm install
    Start-Process powershell -ArgumentList "-NoExit","-Command","cd '$backendNode'; npm start" -WorkingDirectory $backendNode
    Start-Sleep -Seconds 2
    Write-Host 'Opening Smart Warehouse in browser...' -ForegroundColor Cyan
    Start-Process "http://localhost:4000"
    exit 0
}

# Fallback to Python backend
if (Test-Path $venvPy) {
    Write-Host 'Starting Python / Flask backend...' -ForegroundColor Green
    Start-Process powershell -ArgumentList "-NoExit","-Command","cd '$pb'; & '$venvPy' app.py" -WorkingDirectory $pb
    Start-Sleep -Seconds 2
    Write-Host 'Opening Smart Warehouse in browser...' -ForegroundColor Cyan
    Start-Process "http://localhost:4000"
    exit 0
}

if (Get-Command python -ErrorAction SilentlyContinue -or Get-Command py -ErrorAction SilentlyContinue) {
    Write-Host 'Setting up and starting Python backend...' -ForegroundColor Green
    Start-Process powershell -ArgumentList "-NoExit","-Command","cd '$root'; & '.\run-python.ps1'" -WorkingDirectory $root
    Start-Sleep -Seconds 3
    Start-Process "http://localhost:4000"
    exit 0
}

Write-Error 'Neither Node.js (npm) nor Python was found. Please install Node.js 18+ or Python 3.8+.'

