<#
.SYNOPSIS
    NeighborNet - Windows Desktop & Daemon Release Packaging Pipeline
.DESCRIPTION
    1. Compiles Rust core library (neighbornet_core.dll) and headless daemon (neighbornet_node.exe) in release mode.
    2. Compiles Flutter Windows Desktop app (neighbornet_app.exe) in release mode.
    3. Stages all binaries, DLLs, and runtime assets into dist/NeighborNet_v0.1.0_Windows_x64/.
    4. Packages a standalone portable ZIP archive (dist/NeighborNet_v0.1.0_Windows_x64.zip).
    5. Bundles one-click installer scripts and generates Inno Setup installer if ISCC.exe is available.
#>

param(
    [string]$Version = "0.1.0",
    [switch]$SkipRustBuild,
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$CoreDir = "$RepoRoot\neighbornet_core"
$AppDir = "$RepoRoot\neighbornet_app"
$DistDir = "$RepoRoot\dist"
$StagingName = "NeighborNet_v${Version}_Windows_x64"
$StagingDir = "$DistDir\$StagingName"
$ZipFile = "$DistDir\${StagingName}.zip"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   NeighborNet Windows Release Packaging Pipeline v$Version" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Build Rust Release Binaries
if (-not $SkipRustBuild) {
    Write-Host "`n[1/5] Compiling Rust Core Engine & Daemon (Release Mode)..." -ForegroundColor Yellow
    Push-Location $CoreDir
    try {
        cargo build --release
        if ($LASTEXITCODE -ne 0) { throw "Cargo build release failed" }
    } finally {
        Pop-Location
    }
}

$CoreDll = "$CoreDir\target\release\neighbornet_core.dll"
$NodeExe = "$CoreDir\target\release\neighbornet_node.exe"

if (-not (Test-Path $CoreDll)) { throw "Missing compiled Rust DLL: $CoreDll" }
if (-not (Test-Path $NodeExe)) { throw "Missing compiled Rust daemon binary: $NodeExe" }

# 2. Build Flutter Windows Release
if (-not $SkipFlutterBuild) {
    Write-Host "`n[2/5] Compiling Flutter Windows Desktop Application (Release Mode)..." -ForegroundColor Yellow
    Push-Location $AppDir
    try {
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "Flutter build windows release failed" }
    } finally {
        Pop-Location
    }
}

$FlutterReleaseDir = "$AppDir\build\windows\x64\runner\Release"
if (-not (Test-Path "$FlutterReleaseDir\neighbornet_app.exe")) {
    throw "Missing compiled Flutter executable at: $FlutterReleaseDir\neighbornet_app.exe"
}

# 3. Prepare Staging Directory
Write-Host "`n[3/5] Assembling Staging Release Bundle..." -ForegroundColor Yellow
if (Test-Path $StagingDir) {
    Remove-Item -Recurse -Force $StagingDir
}
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null

# Copy Flutter release files (EXE, engine DLL, plugin DLLs, data/ folder)
Copy-Item -Path "$FlutterReleaseDir\*" -Destination $StagingDir -Recurse -Force

# Copy Native Core DLL and Node Daemon directly into application root
Copy-Item -Path $CoreDll -Destination $StagingDir -Force
Copy-Item -Path $NodeExe -Destination $StagingDir -Force

# Create convenient Launcher Scripts
$GuiBatchContent = @"
@echo off
start "" "%~dp0neighbornet_app.exe"
"@
Set-Content -Path "$StagingDir\Run_NeighborNet_GUI.bat" -Value $GuiBatchContent

$DaemonBatchContent = @"
@echo off
echo ==========================================================
echo    NeighborNet Headless Relay Server & Captive Web Portal
echo    Mesh Port: 42424 | Web Gateway: 8080 | DNS: 53
echo ==========================================================
"%~dp0neighbornet_node.exe" -p 42424 -t -w 8080 -z 53
pause
"@
Set-Content -Path "$StagingDir\Run_Headless_Relay_Daemon.bat" -Value $DaemonBatchContent

# Create Operator Quickstart Guide
$ReadmeContent = @"
================================================================================
   NEIGHBORNET - TACTICAL SOVEREIGN MESH NETWORK (v$Version)
   Off-Grid, Decentralized, Zero-Cloud Emergency Mesh Communicator
================================================================================

OVERVIEW:
NeighborNet is a resilient, peer-to-peer, cryptographic mesh communication system
designed for local disaster response, community sovereignty, and off-grid coordination.

PACKAGE CONTENTS:
  * neighbornet_app.exe          - Full Graphical Desktop Communicator
  * neighbornet_core.dll         - High-performance Rust cryptographic & routing engine
  * neighbornet_node.exe         - Headless sovereign relay daemon & Captive Web Gateway
  * Run_NeighborNet_GUI.bat      - Launch the desktop GUI app
  * Run_Headless_Relay_Daemon.bat - Launch dedicated headless server node
  * data/                        - Bundled offline maps, tactical soundboards & assets

OPERATIONAL INSTRUCTIONS:

1. RUNNING THE COMMUNICATOR (GUI):
   Double-click 'Run_NeighborNet_GUI.bat' or 'neighbornet_app.exe'.
   NeighborNet automatically binds UDP port 42424 and discovers nearby peers on your
   local Wi-Fi, Ethernet, or Ad-Hoc mesh without needing any internet connection.

2. RUNNING A HEADLESS RELAY HUB:
   Run 'Run_Headless_Relay_Daemon.bat' to operate a 24/7 solar-powered or base-station
   relay. This automatically launches:
     - Mesh routing on UDP port 42424
     - Zero-Install Web Gateway on http://localhost:8080 (or http://<LAN-IP>:8080)
     - RFC 1035 UDP Captive DNS redirection on port 53 (redirects hotspot users)

3. LORA USB HARDWARE INTEGRATION:
   Plug any standard KISS-compatible USB LoRa module (Heltec, TTGO, RNode, or custom
   SX1262/SX1276 serial bridge) into your computer.
   In NeighborNet Settings -> LoRa Radio, select your COM port and set frequency
   (default: 915.0 MHz for US / 868.0 MHz for EU).

4. EMERGENCY PANIC WIPE:
   Press the Panic Wipe button in Settings or use emergency shredder to immediately
   overwrite and cryptographically sanitize all databases, keys, and cached history.

================================================================================
"@
Set-Content -Path "$StagingDir\README_WINDOWS.txt" -Value $ReadmeContent

# Copy Installer helper scripts into Staging/Installer
$InstallerDir = "$RepoRoot\installer"
if (Test-Path "$InstallerDir\Install_NeighborNet.ps1") {
    Copy-Item -Path "$InstallerDir\Install_NeighborNet.ps1" -Destination $StagingDir -Force
    Copy-Item -Path "$InstallerDir\Install_NeighborNet.bat" -Destination $StagingDir -Force
}

# 4. Generate ZIP Archive
Write-Host "`n[4/5] Creating Portable ZIP Release Archive..." -ForegroundColor Yellow
if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir -Force | Out-Null }
if (Test-Path $ZipFile) { Remove-Item -Force $ZipFile }
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ZipFile -CompressionLevel Optimal

# 5. Build Inno Setup Executable Installer (if ISCC is installed)
Write-Host "`n[5/5] Checking for Inno Setup Compiler (ISCC)..." -ForegroundColor Yellow
$IsccCandidates = @(
    "ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
)

$IsccPath = $null
foreach ($cand in $IsccCandidates) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) {
        $IsccPath = $cand
        break
    }
    if (Test-Path $cand) {
        $IsccPath = $cand
        break
    }
}

if ($IsccPath -and (Test-Path "$InstallerDir\neighbornet_installer.iss")) {
    Write-Host "  Found Inno Setup at: $IsccPath" -ForegroundColor Green
    Write-Host "  Compiling standalone Setup EXE..." -ForegroundColor Yellow
    & $IsccPath "$InstallerDir\neighbornet_installer.iss"
    Write-Host "  Installer generated in: $DistDir\NeighborNet_Setup_v${Version}_x64.exe" -ForegroundColor Green
} else {
    Write-Host "  ISCC not detected in PATH. To generate the single-file setup EXE, install Inno Setup 6 and run:" -ForegroundColor Gray
    Write-Host "  ISCC.exe `"$InstallerDir\neighbornet_installer.iss`"" -ForegroundColor Gray
}

# Summary
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   RELEASE PACKAGING COMPLETE!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Staging Directory: $StagingDir" -ForegroundColor White
$ZipItem = Get-Item $ZipFile
$ZipSizeMB = [math]::Round($ZipItem.Length / 1MB, 2)
Write-Host "Portable ZIP:      $ZipFile ($ZipSizeMB MB)" -ForegroundColor White

$Hash = (Get-FileHash -Path $ZipFile -Algorithm SHA256).Hash
Write-Host "SHA-256 Hash:      $Hash" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
