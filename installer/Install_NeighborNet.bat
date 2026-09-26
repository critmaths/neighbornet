@echo off
setlocal
echo ==========================================================
echo    NeighborNet Windows One-Click Installer
echo ==========================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install_NeighborNet.ps1" -LaunchAfterInstall
pause
