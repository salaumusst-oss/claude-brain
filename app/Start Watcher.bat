@echo off
echo Starting Claude Brain Watcher...
echo This window must stay open. Minimize it, don't close it.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\watcher.ps1"
pause
