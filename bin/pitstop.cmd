@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0pitstop.ps1" %*
exit /b %ERRORLEVEL%
