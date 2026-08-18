# Create venv if needed, install requirements, and run Flask app
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$pb = Join-Path $root 'python_backend'
Set-Location $pb

$venvPy = Join-Path $pb '.venv\Scripts\python.exe'

if (Test-Path $venvPy) {
    Write-Host "Using existing virtual environment: $venvPy" -ForegroundColor Green
    & $venvPy -m pip install -r requirements.txt --quiet
    Write-Host 'Starting Flask backend on http://localhost:4000 ...' -ForegroundColor Cyan
    Start-Process "http://localhost:4000"
    & $venvPy app.py
    exit 0
}

# Look for system Python or py launcher
$pyCmd = $null
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pyCmd = 'python'
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $pyCmd = 'py'
}

if (-not $pyCmd) {
    Write-Error 'Python not found. Please install Python 3.8+ or ensure .venv is present.'
    exit 1
}

Write-Host "Creating virtual environment using $pyCmd..."
& $pyCmd -m venv .venv
if (Test-Path $venvPy) {
    & $venvPy -m pip install -r requirements.txt
    Write-Host 'Starting Flask backend on http://localhost:4000 ...' -ForegroundColor Cyan
    Start-Process "http://localhost:4000"
    & $venvPy app.py
} else {
    Write-Error 'Failed to initialize virtual environment.'
    exit 1
}


