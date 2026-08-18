@echo off
REM Start backend (Windows batch)
cd /d "%~dp0backend"
where npm >nul 2>nul
if %errorlevel% neq 0 (
  echo npm not found. Install Node.js and npm first.
  pause
  exit /b 1
)
echo Installing dependencies...
npm install
echo Starting backend in new powershell window...
start powershell -NoExit -Command "cd '%~dp0backend'; npm start"
