@echo off
set "APP_DIR=%~dp0"
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%APP_DIR%AshkanLocalhost.ps1"
