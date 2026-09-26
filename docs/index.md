---
layout: default
title: NeighborNet Documentation & Tactical Field Wiki
---

# NeighborNet 🌐📡
### Tactical Field Wiki & Operator Documentation

> **A resilient, sovereign, local-first community mesh communications and survival network that operates 100% offline without internet, cloud dependencies, or central servers — built on the Reticulum Network Stack.**

---

## 🗺️ Master Directory

### 🚀 Field Deployment & Hardware Setup
- [**01. Quick Start Guide**](01-Quick-Start-Guide) — 5-minute setup on Windows, Linux, and macOS.
- [**02. Raspberry Pi & Server Relays**](02-Raspberry-Pi-Relay-Node) — 24/7 autonomous transport hubs, `systemd` service, and 12V solar sizing.
- [**03. Zero-Install Web Gateway & Captive Portal**](03-Captive-Portal-Hotspot) — Captive portal probe interception (`/generate_204`, `/hotspot-detect.html`), `hostapd`/`dnsmasq` setup, and QR codes.
- [**04. Hardware LoRa Radio & Antenna Guide**](04-LoRa-Radio-Hardware-Guide) — Heltec, TTGO, and RNode USB-UART setup, KISS framing, ISM frequencies (915/868/433 MHz), and antennas.

---

### 🛡️ Tactical Operations & Survival Protocols
- [**05. Tactical Walkie-Talkie (PTT) & Voice Comms**](05-Walkie-Talkie-PTT-Comms) — Half-duplex floor arbitration, squelch control, VOX, callsigns, and emergency break-in override.
- [**06. Mutual Aid, Barter & Skills Marketplace**](06-Mutual-Aid-Barter-Market) — Categorized trade listings, peer counter-proposals, and 1-to-5 star cryptographic reputation vouches.
- [**07. Disaster Medical Triage & Census Forms**](07-Disaster-Medical-Triage) — START mass-casualty triage, shelter wellness census, and custom JSON dynamic form builders.
- [**08. Tactical Mesh Map & Marker Plotter**](08-Tactical-Map-Plotter) — Offline coordinate grid, emergency markers (water, medical, hazard), tombstones, and real-time spatial filtering.
- [**09. Encrypted Group Vault & File Sharing**](09-Encrypted-Vault-Sharing) — 8 KB content-addressed chunk DAG, authenticated symmetric encryption (AES/SHA-256), and multi-source fetching.

---

### 🔒 Security, Cryptography & Duress
- [**10. Reticulum Mesh Cryptography & Routing**](10-Reticulum-Mesh-Crypto) — Ed25519 identity keys, X25519 ECDH link encryption, 128-bit hashes, and partition DAG reconciliation.
- [**11. Duress Protocol & Emergency Panic Wipe**](11-Duress-Protocol-Panic-Wipe) — Hostile inspection duress wipe, multi-pass cryptographic key shredding, and SQLite page vacuuming.
- [**12. 48-Word BIP-39 Paper Key Mnemonic**](12-48-Word-Paper-Key-Mnemonic) — 512-bit BIP-39 mnemonic seed generation, cold-storage paper backup, and disaster address restoration.

---

### 💻 Governance & Developer Reference
- [**13. Democratic Room Stewardship & Governance**](13-Democratic-Governance) — Democratic room stewardship, voting ballots, mathematical majority/quorum evaluation, and signed audit logs.
- [**14. Rust Core Architecture & C FFI Reference**](14-Rust-Core-FFI-Architecture) — Native Rust crate internals, Dart FFI bindings (`neighbornet_bridge.dart`), and Web Gateway REST API schema.

---

## 🏛 Core Architectural Principles

1. **Zero Cloud Dependencies**: No DNS, no STUN/TURN servers, no central databases, and no mandatory internet uplinks.
2. **Cryptographic Sovereignty**: Identities are asymmetric keypairs (Ed25519). Addresses are truncated 128-bit cryptographic hashes.
3. **Partition Tolerance (CAP Theorem)**: When network partitions occur, local nodes continue operating with full capabilities. When sub-meshes merge, state converges automatically via signed DAG reconciliation.
4. **True Zero Simulation**: NeighborNet contains no simulated peers, mock nodes, or fake traffic. All packets represent real physical hardware nodes.
5. **Universal Accessibility**: Native Flutter desktop/mobile apps for power users, combined with an embedded zero-install Web Gateway for any device with a standard browser.
