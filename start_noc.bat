@echo off

echo Iniciando painel NOC...
timeout /t 1 >nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0noc_ping.ps1"

pause
