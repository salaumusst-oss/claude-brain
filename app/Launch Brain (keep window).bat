@echo off
echo Starting Claude Brain...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0brain.ps1"
pause
