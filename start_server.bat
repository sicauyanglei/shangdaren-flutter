@echo off
echo Starting game server...
cd /d E:\AI-PRJ\shangdaren-game\web
start "" python -m http.server 8080
timeout /t 2 >nul
start "" http://localhost:8080
echo Game server started at http://localhost:8080
pause
