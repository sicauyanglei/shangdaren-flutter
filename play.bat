@echo off
title Shangdaren Game Server
cd /d E:\AI-PRJ\shangdaren-game\web

echo Starting server on port 8080...
echo Open http://localhost:8080 in your browser
echo Press Ctrl+C to stop the server
echo.

start "" http://localhost:8080
python -m http.server 8080
