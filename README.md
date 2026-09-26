# NeighborNet 🌐📡

> **A resilient, sovereign, local-first community mesh communications and survival network that operates 100% offline without internet, cloud dependencies, or central servers — built on the Reticulum Network Stack.**

NeighborNet is engineered for neighborhoods, rural communities, preppers, and disaster response teams (CERT / First Responders) to maintain vital communication, mutual aid trade, crisis coordination, medical triage, and situational awareness when telecom towers, power grids, and internet backbones collapse.

It unites an ultra-high-performance native cryptographic mesh engine written in **Rust** (`neighbornet_core`) with an intuitive, field-ready cross-platform **Flutter** application (`neighbornet_app`), plus a built-in **Zero-Install Web Gateway** that serves any smartphone or laptop with zero app installation.

---

## 🏛 Architecture Overview

NeighborNet operates on an asymmetric, partition-tolerant mesh topology:

```text
                  OFF-GRID REGIONAL BACKBONE (LoRa / Radio / Optical)
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
         Community Hub / Relay             Community Hub / Relay
       (Always-on Raspberry Pi / PC)     (Always-on Raspberry Pi / PC)
           /        │        \               /        │        \
      Leaf Node  Web Portal Leaf Node   Leaf Node  Web Portal Leaf Node
     (Laptop)    (Phone)    (App)      (Laptop)    (Phone)    (App)
```

- **Asymmetric Node Roles**: Laptops and smartphones can operate as **Edge / Leaf Nodes** with opportunistic store-and-forward syncing to preserve battery life, while dedicated home servers and Raspberry Pis act as backbone **Transport Relays**.
- **Cryptographic Substrate**: Reticulum Network Stack (RNS) primitives — Ed25519 asymmetric identity keys, X25519 link encryption, and 128-bit truncated SHA-256 destination hashes.
- **Signed DAG Synchronization**: Directed Acyclic Graph (DAG) partition-tolerant replication ensures messages, bulletins, barter listings, and map markers sync seamlessly when nodes reconnect after extended network splits.
- **True Zero Simulation**: Every node, packet, and cryptographic proof on the network is real and cryptographically signed.

---

## ⚡ Key Capabilities & Tactical Modules

### 🌐 1. Zero-Install Web Gateway & Captive Portal Mode
- **Zero-Dependency Rust Web Server**: Hosts an embedded tactical single-page web app directly from any running node.
- **Captive Portal Probe Interception**: Intercepts iOS, Android, and Windows connectivity checks (`/generate_204`, `/gen_204`, `/hotspot-detect.html`, `/ncsi.txt`, `/connecttest.txt`), automatically displaying the NeighborNet portal when users join a local Wi-Fi hotspot (`NeighborNet-Open`).
- **Browser-Based Access**: Anyone with a smartphone, tablet, or browser can access Chat, Bulletins, Barter Marketplace, Survival Manuals, and SOS Beacon without installing an app.
- **QR Code Onboarding**: Generate instant QR codes for rapid field connection.

### 📦 2. Mutual Aid, Barter & Skills Marketplace
- **Decentralized Trade Ledger**: Post categorized trade listings for food, potable water, medical supplies, fuel, tools, shelter, solar power, and tactical skills.
- **Peer-to-Peer Counter-Proposals**: Negotiate trade offers and counter-offers over the mesh with cryptographic signatures.
- **Trust & Reputation Matrix**: Submit and inspect 1-to-5 star community reputation vouches and verified peer feedback to eliminate bad actors.

### 🗺️ 3. Multi-Hop Visual Mesh Traceroute & Diagnostics
- **Hop-by-Hop Route Discovery**: Trace multi-hop network paths through intermediate transport nodes.
- **Tactical Vector Radar**: Visual interactive canvas depicting network hops, vector coordinates, and signal propagation.
- **Waterfall Latency Diagnostics**: RTT response waterfall breakdown for identifying mesh bottlenecks and packet losses.

### 📍 4. Tactical Mesh Map & Community Marker Plotter
- **Local Spatial Grid**: Plot and track emergency markers, water supply points, first aid stations, road blockages, and hazards.
- **Vector Spatial Filtering**: Filter markers by emergency severity and category with real-time mesh propagation and tombstones.

### 📻 5. Tactical Walkie-Talkie (PTT) & Voice Comms
- **Simplex Half-Duplex Push-to-Talk**: Voice streaming over local Wi-Fi and LAN mesh channels with audio chunk compression.
- **Floor Arbitration & Priority Override**: Token-based floor control with automatic timeout and emergency distress override.
- **P2P Audio/Video Calling**: WebRTC-based voice and video streams with local mesh signaling.

### 🔐 6. Encrypted Group Vault & Chunked File Sharing
- **Content-Addressed File Transfer**: Large files (maps, field manuals, drone imagery) are split into 8 KB content-addressed chunks with authenticated SHA-256 verification.
- **Encrypted Group Vaults**: Password-derived authenticated symmetric encryption (AES/Sha-256) for sharing sensitive disaster intelligence securely.

### 🗳️ 7. Democratic Room Governance & Stewardship
- **Decentralized Democratic Rooms**: Cryptographically vote on room moderators, admission policies, and rule changes.
- **Quorum & Majority Evaluation**: Automatic consensus evaluation with signed audit logs.

### 📋 8. Field Disaster & Medical Triage Forms
- **Rapid Disaster Assessment**: Standardized digital forms for START mass casualty triage, shelter wellness census, and supply distribution.
- **Custom Form Schema Builder**: Design, broadcast, and collect custom data collection schemas across the mesh.

### 📟 9. Hardware LoRa Radio Support (KISS / RNode)
- **Long-Range Off-Grid Comms**: Connect LoRa serial transceivers (ESP32, Heltec, TTGO, RNode) via USB-UART.
- **KISS Framing & Streaming**: Pure-Rust KISS packet encoder/decoder for long-distance sub-GHz radio links (915 MHz / 868 MHz / 433 MHz).

### 🔑 10. Sovereign Identity & Duress Protocol
- **48-Word BIP-39 Paper Key**: Export and restore entire cryptographic identity and destination keys via paper backup seeds.
- **Emergency Panic Wipe**: Securely shreds private keys (`identity.hex`), drops and vacuums local SQLite databases, clears caches, and resets the node instantly during hostile inspection or device surrender.

### 🖥️ 11. Desktop System Tray & Tactical Themes
- **System Tray Background Service**: Minimize to tray or close to tray so Reticulum mesh routing stays active in the background.
- **Tactical Display Profiles**: Switch instantly between **Cyber Amber** (Default Dark), **Night Vision Red** (Aviation OLED Black), and **Sunlight Glare** (High-Contrast Outdoor Daylight).

---

## 📁 Repository Structure

```text
Neighbornet/
├── neighbornet_core/             # Native Rust Reticulum & Mesh Engine
│   ├── src/
│   │   ├── lib.rs                # Core Reticulum node, SQLite persistence, FFI exports
│   │   ├── web_gateway.rs        # Embedded HTTP server, captive portal, REST API, SPA
│   │   ├── kiss.rs               # KISS protocol framing & stream decoder
│   │   ├── lora.rs               # Hardware LoRa serial port manager
│   │   └── bin/
│   │       └── node.rs           # Headless daemon binary for Raspberry Pis & servers
│   └── tests/                    # 15 comprehensive Rust integration test suites
│
├── neighbornet_app/              # Cross-Platform Flutter Tactical Application
│   ├── lib/
│   │   ├── models/               # Data structures (Chat, Barter, Forms, Markers, Traces)
│   │   ├── services/             # FFI Bridge, PTT, Voice Chat, System Tray, Notifications
│   │   ├── state/                # Reactive ChangeNotifier mesh state management
│   │   ├── views/                # Tactical UI views (Chat, Barter, Map, Traceroute, Settings)
│   │   └── widgets/              # Reusable tactical UI components and dialogs
│   └── test/                     # 71 Flutter unit, bridge, and widget tests
│
├── dist/                         # Compiled standalone portable release packages
└── COLLAPSE_SURVIVAL_MANUAL.md   # Built-in offline field survival manual & protocols
```

---

## 🚀 Getting Started

### Prerequisites

- [Rust Toolchain](https://rustup.rs/) (1.75+ or newer recommended)
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.10+ or newer)

---

### 1. Build the Rust Core Library & Daemon

```bash
cd neighbornet_core
cargo build --release
```

To run a headless community relay node (e.g. on a Raspberry Pi or server):

```bash
# Run headless transport relay on port 42424
cargo run --release --bin neighbornet_node -- 42424 "Community_Pi_Relay" --transport
```

---

### 2. Run the Flutter Tactical App

```bash
cd neighbornet_app
flutter pub get
flutter run -d windows    # or linux, macos, android, ios
```

To build a standalone production Windows release:

```bash
flutter build windows --release
```

---

## 🧪 Verification & Test Suites

NeighborNet maintains a 100% automated test pass rate across both Rust and Dart codebases:

```bash
# 1. Run all 15 Rust core integration test suites
cd neighbornet_core
cargo test

# 2. Run static analysis on Flutter application (0 issues)
cd ../neighbornet_app
dart analyze lib test

# 3. Run all 71 Flutter unit, FFI bridge, and widget tests
flutter test
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

## 🤝 Community & Support

<a href="https://buy.stripe.com/eVq8wQcma4RCctIgsf2Ji04" target="_blank">
  <img width="180" height="60" alt="Donate-Button" src="https://github.com/user-attachments/assets/653907f6-d82e-4c0c-82e1-dc8d1e508fe3" />
</a>
