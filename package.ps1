# Package the project into smart-warehouse.zip (Windows PowerShell)
# Usage: run from workspace root
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $root
$dest = Join-Path $root 'smart-warehouse.zip'

$tempDir = Join-Path $env:TEMP "smart_warehouse_pkg_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$items = @(
  'frontend',
  'backend',
  'python_backend',
  'README.md',
  'demo.ps1',
  'demo.sh',
  'Dockerfile',
  'docker-compose.yml',
  'run-backend.ps1',
  'run-python.ps1',
  'run-all.ps1',
  'start-backend.bat'
)

foreach ($item in $items) {
  $src = Join-Path $root $item
  if (Test-Path $src) {
    if (Test-Path $src -PathType Container) {
      $target = Join-Path $tempDir $item
      Copy-Item -Path $src -Destination $tempDir -Recurse
      Get-ChildItem -Path $target -Recurse -Directory -Include @('.venv', 'node_modules', '__pycache__') | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
      Get-ChildItem -Path $target -Recurse -File -Include @('*.pyc', '*.pyo') | Remove-Item -Force -ErrorAction SilentlyContinue
    } else {
      Copy-Item -Path $src -Destination $tempDir
    }
  }
}

Write-Host "Creating $dest ..."
if (Test-Path $dest) { Remove-Item $dest -Force }
Compress-Archive -Path "$tempDir\*" -DestinationPath $dest -Force
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Package created: $dest"