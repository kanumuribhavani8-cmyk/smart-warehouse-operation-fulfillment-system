# Push OmniStock Central to GitHub
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $root

$gitCmd = "C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Git\cmd\git.exe"
if (-not (Test-Path $gitCmd)) {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitCmd = "git"
    } else {
        Write-Error "Git was not found on your system."
        exit 1
    }
}

Write-Host "Configuring repository and pushing to GitHub..." -ForegroundColor Cyan
& $gitCmd remote set-url origin https://github.com/kanumuribhavani8-cmyk/smart-warehouse-operation-fulfillment-system.git
& $gitCmd branch -M main
& $gitCmd push -u origin main
