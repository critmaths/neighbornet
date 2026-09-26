# NeighborNet Knowledge Base & Operator Wiki 🌐📖

> **Welcome to the official documentation and tactical operations manual for NeighborNet.**

NeighborNet is a sovereign, local-first mesh communication and disaster resilience platform built on the **Reticulum Network Stack (RNS)**. It operates 100% offline without the internet, cellular towers, or central cloud infrastructure.

---

## 🗺️ Documentation Directory

### 🚀 1. Field Deployment & Hardware Setup
- [**01. Quick Start Guide**](01-Quick-Start-Guide.md) — 5-minute setup for desktop and mobile operators.
- [**02. Raspberry Pi & Server Relays**](02-Raspberry-Pi-Relay-Node.md) — 24/7 autonomous transport node and solar deployment.
- [**03. Zero-Install Web Gateway & Captive Portal**](03-Captive-Portal-Hotspot.md) — Broadcasting browser-accessible portals over Wi-Fi hotspots.
- [**04. Hardware LoRa Radio & Antenna Guide**](04-LoRa-Radio-Hardware-Guide.md) — Connecting ESP32, Heltec, TTGO, and RNodes over KISS/serial.

### 🛡️ 2. Tactical Operations & Survival Protocols
- [**05. Tactical Walkie-Talkie (PTT) & Voice Comms**](05-Walkie-Talkie-PTT-Comms.md) — Half-duplex floor arbitration, VOX, and callsigns.
- [**06. Mutual Aid, Barter & Skills Marketplace**](06-Mutual-Aid-Barter-Market.md) — Decentralized trading, counter-offers, and reputation vouches.
- [**07. Disaster Medical Triage & Census Forms**](07-Disaster-Medical-Triage.md) — START mass-casualty triage and rapid shelter census.
- [**08. Tactical Mesh Map & Marker Plotter**](08-Tactical-Map-Plotter.md) — Local vector grid, water points, triage camps, and road hazards.
- [**09. Encrypted Group Vault & File Sharing**](09-Encrypted-Vault-Sharing.md) — Content-addressed 8KB chunk DAG and authenticated vaults.

### 🔒 3. Security, Cryptography & Duress
- [**10. Reticulum Mesh Cryptography & Routing**](10-Reticulum-Mesh-Crypto.md) — Ed25519 identity, X25519 encryption, 128-bit hashes, and DAG sync.
- [**11. Duress Protocol & Emergency Panic Wipe**](11-Duress-Protocol-Panic-Wipe.md) — Multi-pass cryptographic key shredding and hostile surrender.
- [**12. 48-Word BIP-39 Paper Key Mnemonic**](12-48-Word-Paper-Key-Mnemonic.md) — Cold-storage paper seed backups and disaster recovery.

### 💻 4. Governance & Developer Reference
- [**13. Democratic Room Stewardship & Governance**](13-Democratic-Governance.md) — Cryptographic room proposals, quorum evaluation, and audit logs.
- [**14. Rust Core Architecture & C FFI Reference**](14-Rust-Core-FFI-Architecture.md) — `neighbornet_core` internals, Dart FFI bridge, and REST API schema.

---

## 🏛 Core Architectural Principles

1. **Zero Cloud Dependencies**: No DNS, no STUN/TURN servers, no central databases, and no mandatory internet uplinks.
2. **Cryptographic Sovereignty**: Identities are asymmetric keypairs (Ed25519). Addresses are truncated 128-bit cryptographic hashes.
3. **Partition Tolerance (CAP Theorem)**: When network partitions occur, local nodes continue operating with full capabilities. When sub-meshes merge, state converges automatically via signed DAG reconciliation.
4. **True Zero Simulation**: NeighborNet contains no simulated peers, mock nodes, or fake traffic. All packets represent real physical hardware nodes.
5. **Universal Accessibility**: Native Flutter desktop/mobile apps for power users, combined with an embedded zero-install Web Gateway for any device with a standard browser.
