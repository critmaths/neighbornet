# NeighborNet 🌐📡

> **A resilient, sovereign, local-first community mesh communications and survival network that operates 100% offline without internet, cloud dependencies, or central servers — built on the Reticulum Network Stack.**

NeighborNet is engineered for neighborhoods, rural communities, preppers, and disaster response teams (CERT / First Responders) to maintain vital communication, mutual aid trade, crisis coordination, medical triage, and situational awareness when telecom towers, power grids, and internet backbones collapse.

It unites an ultra-high-performance native cryptographic mesh engine written in **Rust** (`neighbornet_core`) with an intuitive, field-ready cross-platform **Flutter** application (`neighbornet_app`), plus a built-in **Zero-Install Web Gateway** that serves any smartphone or laptop with zero app installation.

---

## 📚 Operator Wiki & Documentation

Comprehensive field operator manuals, deployment walkthroughs, and developer references are available in the [**NeighborNet Wiki (docs/)**](docs/Home.md):

- [**01. Quick Start Guide**](docs/01-Quick-Start-Guide.md) — 5-minute setup on Windows, Linux, and macOS.
- [**02. Raspberry Pi & Server Relays**](docs/02-Raspberry-Pi-Relay-Node.md) — 24/7 autonomous transport hubs and solar power sizing.
- [**03. Zero-Install Web Gateway & Captive Portal**](docs/03-Captive-Portal-Hotspot.md) — Intercepting OS probes and broadcasting portals over Wi-Fi.
- [**04. Hardware LoRa Radio & Antenna Guide**](docs/04-LoRa-Radio-Hardware-Guide.md) — Connecting ESP32, Heltec, TTGO, and RNodes over KISS serial.
- [**05. Tactical Walkie-Talkie (PTT) & Voice Comms**](docs/05-Walkie-Talkie-PTT-Comms.md) — Half-duplex floor arbitration, squelch, and VOX.
- [**06. Mutual Aid, Barter & Skills Marketplace**](docs/06-Mutual-Aid-Barter-Market.md) — Trade listings, counter-offers, and cryptographic vouches.
- [**07. Disaster Medical Triage & Census Forms**](docs/07-Disaster-Medical-Triage.md) — START mass-casualty triage and shelter wellness census.
- [**08. Tactical Mesh Map & Marker Plotter**](docs/08-Tactical-Map-Plotter.md) — Vector spatial grid, water points, triage centers, and hazards.
- [**09. Encrypted Group Vault & File Sharing**](docs/09-Encrypted-Vault-Sharing.md) — 8 KB content-addressed chunk DAG and authenticated vaults.
- [**10. Reticulum Mesh Cryptography & Routing**](docs/10-Reticulum-Mesh-Crypto.md) — Ed25519 identity, X25519 ECDH, 128-bit hashes, and DAG sync.
- [**11. Duress Protocol & Emergency Panic Wipe**](docs/11-Duress-Protocol-Panic-Wipe.md) — Multi-pass key shredding and hostile device surrender.
- [**12. 48-Word BIP-39 Paper Key Mnemonic**](docs/12-48-Word-Paper-Key-Mnemonic.md) — Offline paper seed backup and address recovery.
- [**13. Democratic Room Stewardship & Governance**](docs/13-Democratic-Governance.md) — Quorum evaluation, steward elections, and audit logs.
- [**14. Rust Core Architecture & C FFI Reference**](docs/14-Rust-Core-FFI-Architecture.md) — `neighbornet_core` internals and REST API endpoints.

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

- **Asymmetric Node Roles**: Laptops and smartphones operate as **Edge / Leaf Nodes** with opportunistic store-and-forward syncing to preserve battery life, while dedicated home servers and Raspberry Pis act as backbone **Transport Relays**.
- **Cryptographic Substrate**: Reticulum Network Stack (RNS) primitives — Ed25519 asymmetric identity keys, X25519 link encryption, and 128-bit truncated SHA-256 destination hashes.
- **Signed DAG Synchronization**: Directed Acyclic Graph (DAG) partition-tolerant replication ensures messages, bulletins, barter listings, and map markers sync seamlessly when nodes reconnect after extended network splits.
- **True Zero Simulation**: Every node, packet, and cryptographic proof on the network is real and cryptographically signed.

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
├── docs/                         # Master Documentation & Operator Wiki (14 chapters)
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
