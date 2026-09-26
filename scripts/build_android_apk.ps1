<#
.SYNOPSIS
    NeighborNet - Android APK Build & Native Core Packaging Script
.DESCRIPTION
    1. Detects Android NDK and SDK.
    2. Builds libneighbornet_core.so for Android ABIs (arm64-v8a, armeabi-v7a, x86_64).
    3. Stages .so libraries into neighbornet_app/android/app/src/main/jniLibs/<abi>/
    4. Runs `flutter build apk --release` (or `--split-per-abi`).
    5. Copies output APKs into dist/.
#>

param(
    [string]$Version = "0.1.0",
    [string[]]$Abis = @("arm64-v8a", "armeabi-v7a", "x86_64"),
    [switch]$SplitPerAbi,
    [switch]$SkipRustBuild
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$CoreDir = "$RepoRoot\neighbornet_core"
$AppDir = "$RepoRoot\neighbornet_app"
$JniLibsDir = "$AppDir\android\app\src\main\jniLibs"
$DistDir = "$RepoRoot\dist"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   NeighborNet Android APK Packaging Pipeline v$Version   " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check for NDK / SDK
$NdkPath = $env:ANDROID_NDK_HOME
if (-not $NdkPath) { $NdkPath = $env:NDK_HOME }
if (-not $NdkPath -and $env:ANDROID_HOME) {
    $NdkDir = "$env:ANDROID_HOME\ndk"
    if (Test-Path $NdkDir) {
        $LatestNdk = Get-ChildItem -Path $NdkDir | Sort-Object Name -Descending | Select-Object -First 1
        if ($LatestNdk) { $NdkPath = $LatestNdk.FullName }
    }
}

if (-not $SkipRustBuild) {
    if (-not $NdkPath) {
        Write-Warning "Android NDK not detected in ANDROID_NDK_HOME or ANDROID_HOME\ndk."
        Write-Warning "If you have already built libneighbornet_core.so in jniLibs, use -SkipRustBuild."
        Write-Warning "Otherwise, install Android NDK or use GitHub Actions CI/CD to build the APK."
        throw "Android NDK required to cross-compile Rust core library for Android"
    }

    Write-Host "`n[1/4] Found Android NDK at: $NdkPath" -ForegroundColor Green

    # Map ABIs to Rust target triples
    $AbiTargetMap = @{
        "arm64-v8a"   = "aarch64-linux-android"
        "armeabi-v7a" = "armv7-linux-androideabi"
        "x86_64"      = "x86_64-linux-android"
    }

    foreach ($abi in $Abis) {
        $target = $AbiTargetMap[$abi]
        if (-not $target) { continue }

        Write-Host "`n[2/4] Cross-compiling Rust core for $abi ($target)..." -ForegroundColor Yellow
        Push-Location $CoreDir
        try {
            if (Get-Command cargo-ndk -ErrorAction SilentlyContinue) {
                cargo ndk -t $abi -o "$JniLibsDir" build --release
            } else {
                rustup target add $target
                cargo build --release --target $target
                $DestDir = "$JniLibsDir\$abi"
                if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir -Force | Out-Null }
                Copy-Item -Path "target\$target\release\libneighbornet_core.so" -Destination "$DestDir\libneighbornet_core.so" -Force
            }
        } finally {
            Pop-Location
        }
    }
}

# 3. Build Flutter APK
Write-Host "`n[3/4] Building Flutter Release APK..." -ForegroundColor Yellow
Push-Location $AppDir
try {
    $BuildArgs = @("build", "apk", "--release")
    if ($SplitPerAbi) {
        $BuildArgs += "--split-per-abi"
    }
    flutter @BuildArgs
    if ($LASTEXITCODE -ne 0) { throw "Flutter build apk failed" }
} finally {
    Pop-Location
}

# 4. Copy to dist/
Write-Host "`n[4/4] Staging APKs into dist/..." -ForegroundColor Yellow
if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir -Force | Out-Null }

$ApkSourceDir = "$AppDir\build\app\outputs\flutter-apk"
$Apks = Get-ChildItem -Path $ApkSourceDir -Filter "*.apk"
foreach ($apk in $Apks) {
    $DestApk = "$DistDir\NeighborNet-v${Version}-$($apk.Name)"
    Copy-Item -Path $apk.FullName -Destination $DestApk -Force
    $SizeMB = [math]::Round((Get-Item $DestApk).Length / 1MB, 2)
    $Hash = (Get-FileHash -Path $DestApk -Algorithm SHA256).Hash
    Write-Host "  -> Generated: $DestApk ($SizeMB MB)" -ForegroundColor Green
    Write-Host "     SHA-256:   $Hash" -ForegroundColor Cyan
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   ANDROID APK BUILD COMPLETE!                            " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
