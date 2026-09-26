#!/usr/bin/env bash
set -euo pipefail

# NeighborNet - Android APK Build & Native Core Packaging Script
VERSION="0.1.0"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_DIR="$REPO_ROOT/neighbornet_core"
APP_DIR="$REPO_ROOT/neighbornet_app"
JNI_LIBS_DIR="$APP_DIR/android/app/src/main/jniLibs"
DIST_DIR="$REPO_ROOT/dist"

echo "=========================================================="
echo "   NeighborNet Android APK Packaging Pipeline v$VERSION   "
echo "=========================================================="

mkdir -p "$JNI_LIBS_DIR" "$DIST_DIR"

ABIS=("arm64-v8a" "armeabi-v7a" "x86_64")

echo "[1/3] Cross-compiling Rust core libraries for Android ABIs..."
if command -v cargo-ndk &> /dev/null; then
    for abi in "${ABIS[@]}"; do
        echo "  Building ABI: $abi..."
        (cd "$CORE_DIR" && cargo ndk -t "$abi" -o "$JNI_LIBS_DIR" build --release)
    done
else
    echo "cargo-ndk not found. Installing cargo-ndk..."
    cargo install cargo-ndk
    for abi in "${ABIS[@]}"; do
        echo "  Building ABI: $abi..."
        (cd "$CORE_DIR" && cargo ndk -t "$abi" -o "$JNI_LIBS_DIR" build --release)
    done
fi

echo "[2/3] Building Flutter Release APK..."
(cd "$APP_DIR" && flutter build apk --release)

echo "[3/3] Staging output APKs into dist/..."
cp "$APP_DIR/build/app/outputs/flutter-apk/app-release.apk" "$DIST_DIR/NeighborNet-v${VERSION}-Android-Universal.apk"

echo "=========================================================="
echo "   ANDROID BUILD COMPLETE: $DIST_DIR/NeighborNet-v${VERSION}-Android-Universal.apk"
echo "=========================================================="
