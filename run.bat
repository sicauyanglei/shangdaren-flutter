@echo off
title Shangdaren Game Server
cd /d E:\AI-PRJ\shangdaren-game\web
echo Starting game server...
echo Server running at: http://localhost:8080
echo Press Ctrl+C to stop
start "" http://localhost:8080
python -m http.server 8080
