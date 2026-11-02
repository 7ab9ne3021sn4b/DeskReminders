@echo off
rem conhost = the classic console, which can be hidden (Windows Terminal can't)
set "PSARGS=-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File"
if not exist "%SystemRoot%\System32\conhost.exe" goto plain
start "" /min "%SystemRoot%\System32\conhost.exe" powershell.exe %PSARGS% "%~dp0DeskReminders.ps1"
goto :eof
:plain
start "" /min powershell.exe %PSARGS% "%~dp0DeskReminders.ps1"
