<#
.SYNOPSIS
    NeighborNet - Tactical Windows Installer
.DESCRIPTION
    Installs NeighborNet desktop app, headless node daemon, and native core DLLs
    into %LOCALAPPDATA%\Programs\NeighborNet, registers desktop & start menu shortcuts,
    and sets up Windows Defender Firewall allowances.
#>

param(
    [string]$InstallPath = "$env:LOCALAPPDATA\Programs\NeighborNet",
    [switch]$NoFirewall,
    [switch]$LaunchAfterInstall
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   NeighborNet - Tactical Sovereign Mesh Installation     " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# Locate source files: either current dir, ..\dist\NeighborNet_v0.1.0_Windows_x64, or adjacent release folder
$SourceCandidates = @(
    "$ScriptDir\..\dist\NeighborNet_v0.1.0_Windows_x64",
    "$ScriptDir\NeighborNet_v0.1.0_Windows_x64",
    "$ScriptDir\release",
    "$ScriptDir"
)

$SourceDir = $null
foreach ($cand in $SourceCandidates) {
    if (Test-Path "$cand\neighbornet_app.exe") {
        $SourceDir = (Resolve-Path $cand).Path
        break
    }
}

if (-not $SourceDir) {
    Write-Error "Could not find release bundle files containing 'neighbornet_app.exe'. Please ensure dist bundle is generated."
    exit 1
}

Write-Host "[1/5] Source folder located: $SourceDir" -ForegroundColor Green
Write-Host "[2/5] Target installation directory: $InstallPath" -ForegroundColor Green

if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

Write-Host "[3/5] Copying application binaries and assets..." -ForegroundColor Yellow
Copy-Item -Path "$SourceDir\*" -Destination $InstallPath -Recurse -Force

Write-Host "[4/5] Creating Desktop & Start Menu shortcuts..." -ForegroundColor Yellow
$WshShell = New-Object -ComObject WScript.Shell

# Desktop Shortcut
$DesktopFolder = [System.Environment]::GetFolderPath('Desktop')
$DesktopShortcut = $WshShell.CreateShortcut("$DesktopFolder\NeighborNet.lnk")
$DesktopShortcut.TargetPath = "$InstallPath\neighbornet_app.exe"
$DesktopShortcut.WorkingDirectory = $InstallPath
$DesktopShortcut.Description = "NeighborNet - Tactical Mesh Communicator"
$DesktopShortcut.Save()

# Start Menu Shortcut
$StartMenuPrograms = [System.Environment]::GetFolderPath('Programs')
$AppStartDir = "$StartMenuPrograms\NeighborNet"
if (-not (Test-Path $AppStartDir)) {
    New-Item -ItemType Directory -Path $AppStartDir -Force | Out-Null
}

$StartMenuShortcut = $WshShell.CreateShortcut("$AppStartDir\NeighborNet.lnk")
$StartMenuShortcut.TargetPath = "$InstallPath\neighbornet_app.exe"
$StartMenuShortcut.WorkingDirectory = $InstallPath
$StartMenuShortcut.Description = "NeighborNet - Tactical Mesh Communicator"
$StartMenuShortcut.Save()

# Daemon Shortcut
$DaemonShortcut = $WshShell.CreateShortcut("$AppStartDir\NeighborNet Headless Relay Server.lnk")
$DaemonShortcut.TargetPath = "$InstallPath\neighbornet_node.exe"
$DaemonShortcut.Arguments = "-p 42424 -t -w 8080 -z 53"
$DaemonShortcut.WorkingDirectory = $InstallPath
$DaemonShortcut.Description = "NeighborNet Headless Emergency Relay Daemon"
$DaemonShortcut.Save()

# Create Uninstaller Script
$UninstallScript = @"
@echo off
echo ============================================================
echo   Uninstalling NeighborNet Sovereign Mesh...
echo ============================================================
taskkill /F /IM neighbornet_app.exe 2>nul
taskkill /F /IM neighbornet_node.exe 2>nul

del /F /Q "$DesktopFolder\NeighborNet.lnk" 2>nul
rmdir /S /Q "$AppStartDir" 2>nul

netsh advfirewall firewall delete rule name="NeighborNet Mesh Discovery (UDP 42424)" 2>nul
netsh advfirewall firewall delete rule name="NeighborNet Web Gateway (TCP 8080)" 2>nul
netsh advfirewall firewall delete rule name="NeighborNet Captive DNS (UDP 53)" 2>nul

echo Removing application files...
rmdir /S /Q "$InstallPath"

echo NeighborNet has been successfully uninstalled.
pause
"@

Set-Content -Path "$InstallPath\Uninstall_NeighborNet.bat" -Value $UninstallScript

$UninstallShortcut = $WshShell.CreateShortcut("$AppStartDir\Uninstall NeighborNet.lnk")
$UninstallShortcut.TargetPath = "$InstallPath\Uninstall_NeighborNet.bat"
$UninstallShortcut.WorkingDirectory = $InstallPath
$UninstallShortcut.Save()

Write-Host "[5/5] Configuring Windows Defender Firewall rules..." -ForegroundColor Yellow
if (-not $NoFirewall) {
    try {
        Start-Process netsh -ArgumentList 'advfirewall firewall add rule name="NeighborNet Mesh Discovery (UDP 42424)" dir=in action=allow protocol=UDP localport=42424' -Verb RunAs -Wait -ErrorAction SilentlyContinue
        Start-Process netsh -ArgumentList 'advfirewall firewall add rule name="NeighborNet Web Gateway (TCP 8080)" dir=in action=allow protocol=TCP localport=8080' -Verb RunAs -Wait -ErrorAction SilentlyContinue
        Start-Process netsh -ArgumentList 'advfirewall firewall add rule name="NeighborNet Captive DNS (UDP 53)" dir=in action=allow protocol=UDP localport=53' -Verb RunAs -Wait -ErrorAction SilentlyContinue
        Write-Host "  Firewall rules added successfully (UDP 42424, TCP 8080, UDP 53)." -ForegroundColor Green
    } catch {
        Write-Warning "Could not automatically elevate firewall rules. Run netsh as administrator if mesh discovery is blocked."
    }
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   INSTALLATION COMPLETE!                                 " -ForegroundColor Green
Write-Host "   NeighborNet is ready at: $InstallPath" -ForegroundColor White
Write-Host "   Desktop shortcut: $DesktopFolder\NeighborNet.lnk" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green

if ($LaunchAfterInstall) {
    Start-Process "$InstallPath\neighbornet_app.exe"
}
