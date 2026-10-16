@echo off
pwsh -NoProfile -File "%~dp0godin.ps1" %*
exit /b %ERRORLEVEL%
