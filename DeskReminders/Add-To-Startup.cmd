@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DeskReminders.ps1" -InstallStartup
pause
