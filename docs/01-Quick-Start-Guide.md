# Quick Start Guide 🚀

> **Get up and running with NeighborNet on your desktop or field device in under 5 minutes.**

---

## 1. Running the Pre-Compiled Standalone Release (Windows x64)

NeighborNet is distributed as a self-contained portable package with zero runtime dependencies.

1. Navigate to the `dist/` directory or download `NeighborNet-v1.0.0-windows-x64.zip`.
2. Extract the archive to any folder or USB thumb drive.
3. Launch `neighbornet_app.exe`.
4. NeighborNet will immediately:
   - Generate your sovereign cryptographic identity (`identity.hex`) in the local data directory.
   - Bind to UDP port `42424` for local Wi-Fi / Ethernet broadcast discovery.
   - Start listening for peer announcements from neighboring nodes.

---

## 2. Building from Source

### Prerequisites
- [Rust Toolchain (1.75+)](https://rustup.rs/)
- [Flutter SDK (3.10+)](https://flutter.dev/)

### Build the Rust Core Library
```bash
cd neighbornet_core
cargo build --release
```
This produces `neighbornet_core.dll` (Windows), `libneighbornet_core.so` (Linux), or `libneighbornet_core.dylib` (macOS).

### Launch the Flutter App
```bash
cd ../neighbornet_app
flutter pub get
flutter run -d windows    # or linux, macos, android, ios
```

---

## 3. Initial Tactical Identity Setup

Upon first launch, open **Settings** (gear icon in the bottom left navigation rail):

1. **Display Nickname**: Set your community handle (e.g. `Alice Alpha`).
2. **Radio / Tactical Callsign**: Set your radio callsign (e.g. `KD9XYZ / Unit-4`).
3. **Sector / Grid Square**: Enter your neighborhood zone (e.g. `Oak Ridge / Grid B-4`).
4. **Mission Avatar & Skills**: Select your field role avatar (Medic, Radio, Solar, Recon, Engineer) and select your mutual aid capabilities.
5. Click **SAVE & BROADCAST SOVEREIGN IDENTITY** to announce your presence to all direct peers on the mesh.

---

## 4. Basic Operations Checklist

- **Chatting**: Click **Chat** to send encrypted broadcast messages across `#general`, `#emergency`, `#barter`, `#logistics`, `#skills`, and `#watercooler`.
- **Posting Bulletins**: Click **Bulletin** to publish timestamped advisories with `Standard`, `Urgent`, or `Critical` urgency levels.
- **Barter & Aid**: Click **Market & Barter** to post offers for food, water, medical supplies, fuel, or skills.
- **PTT Comms**: Click **Walkie-Talkie (PTT)** to transmit half-duplex voice audio over selected mesh channels.
- **Paper Backup**: In **Settings**, click **EXPORT 48-WORD PAPER KEY** and write down the mnemonic on waterproof paper.
