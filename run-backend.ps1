# Run backend (PowerShell)
# Usage: Right-click -> Run with PowerShell or execute in PowerShell
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$backend = Join-Path $root 'backend'
$frontend = Join-Path $root 'frontend'

Set-Location $backend
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Error 'npm not found. Install Node.js (which includes npm) and try again.'
  exit 1
}
Write-Host 'Installing dependencies...'
npm install
Write-Host 'Starting backend in a new PowerShell window...'
Start-Process powershell -ArgumentList "-NoExit","-Command","cd '$backend'; npm start" -WorkingDirectory $backend
Start-Sleep -Seconds 2
Write-Host 'Opening frontend in default browser...'
Start-Process (Join-Path $frontend 'index.html')
