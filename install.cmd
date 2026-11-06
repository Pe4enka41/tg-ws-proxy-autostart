@echo off
chcp 65001 >nul
title TgWsProxy Auto - Install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
