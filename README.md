# NeighborNet 🌐📡

> **A resilient, local-first community communications and information network that operates without internet or central servers, built on the Reticulum Network Stack.**

NeighborNet is designed for neighborhoods, local communities, and emergency response teams to stay connected when conventional telecom and internet infrastructure fails. It combines an ultra-efficient native cryptographic networking engine written in Rust with a clean, intuitive cross-platform Flutter application.

---

## 🏛 Architecture Overview

NeighborNet operates on an asymmetric, hierarchical topology:

```text
                  ISP / MUNICIPAL NODE (Optional Backbone)
                             │
                    ┌────────┴────────┐
                    │                 │
              Community Pi      Community Pi (Always-on Transport Nodes)
                 /    \             /    \
               PC     Phone        PC    Phone (Edge / Leaf Nodes)
```

- **Asymmetric Roles**: Mobile devices (iOS & Android) operate strictly as **Edge / Leaf nodes** with opportunistic store-and-forward sync to respect OS background suspension and battery limits. Raspberry Pis, home servers, and PCs act as backbone transport/storage relays.
- **Underlying Protocol**: Reticulum Network Stack (RNS) cryptographic substrate (Ed25519 identity, X25519 link encryption, 128-bit destination hashes).
- **Application Layer**: Signed Directed Acyclic Graph (DAG) for conflict-free, partition-tolerant store-and-forward replication of messages, bulletin posts, and emergency alerts.
- **Zero Simulation**: No fake or simulated peers. All nodes on the network are real cryptographic entities verified with asymmetric signatures.

---

## 📁 Repository Structure

- [`neighbornet_core/`](neighbornet_core/): Native Rust crate providing:
  - Reticulum cryptography and identity management (`reticulum-rs`).
  - Automatic UDP broadcast discovery (`0.0.0.0:42424`).
  - Store-and-forward DAG sync engine.
  - C FFI dynamic library export (`neighbornet_core.dll` / `.so` / `.dylib`).
  - Standalone headless node daemon (`neighbornet_node`) for Raspberry Pis and headless servers.
- [`neighbornet_app/`](neighbornet_app/): Cross-platform Flutter desktop & mobile application:
  - Real-time reactive Dart FFI bridge.
  - 6 community chat channels (General, Emergency, Neighborhood, Help, Buy/Sell, Technical).
  - Persistent Community Bulletin with urgent/emergency alerts and local filtering.
  - Cryptographic People & Nodes directory.
  - Offline Emergency & Disaster Survival Guides with one-tap SOS broadcast.

---

## 🚀 Getting Started

### Prerequisites

- [Rust](https://rustup.rs/) (1.75+ or newer recommended)
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.10+ or newer)

### 1. Build the Rust Core Library & Daemon

```bash
cd neighbornet_core
cargo build --release
```

To run a headless community relay node (e.g. on a Raspberry Pi or server):

```bash
# cargo run --release --bin neighbornet_node -- [port] [node_name] [--transport]
cargo run --release --bin neighbornet_node -- 42424 "Community_Pi_Relay" --transport
```

### 2. Run the Flutter App

Copy or link the compiled dynamic library into the app directory or system path, then run:

```bash
cd neighbornet_app
flutter pub get
flutter run -d windows    # or macos, linux, android, ios
```

---

## 🧪 Verification & Automated Tests

All core cryptographic operations, FFI bindings, and store-and-forward network partition sync behaviors are validated by comprehensive automated test suites:

```bash
# Run Rust unit, FFI, and partition recovery tests
cd neighbornet_core
cargo test

# Run Flutter FFI bridge and UI tests
cd ../neighbornet_app
flutter test
```
---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

## Care To Donate?
<a href="https://buy.stripe.com/eVq8wQcma4RCctIgsf2Ji04" target="_blank">
  <img width="541" height="181" alt="Donate-Button" src="https://github.com/user-attachments/assets/653907f6-d82e-4c0c-82e1-dc8d1e508fe3" />
</a>
