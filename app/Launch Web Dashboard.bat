@echo off
echo Starting Claude Brain Web Dashboard...
echo Opening http://localhost:7337
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0brain-web.ps1"
