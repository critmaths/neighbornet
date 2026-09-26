# Raspberry Pi & Autonomous Relay Node Deployment 🍓🔋

> **Deploy a 24/7 headless transport node, persistent storage cache, and community mesh backbone powered by a Raspberry Pi, solar panel, or home server.**

---

## 1. Why Deploy a Dedicated Transport Node?

Mobile phones and battery-constrained laptops operate as **Leaf / Edge Nodes** that go into low-power sleep mode when their screens turn off. 

A dedicated **Transport Node** (e.g. Raspberry Pi 4/5 or Pi Zero 2 W):
- Stays powered 24/7 on a 12V solar battery system or UPS.
- Automatically caches all incoming bulletins, barter listings, files, and chat messages into SQLite.
- Relays packets across multiple network interfaces (Wi-Fi, Ethernet, and LoRa radio).
- Serves the **Zero-Install Web Gateway** to anyone connecting to its local Wi-Fi hotspot.

---

## 2. Compiling the Headless Daemon (`neighbornet_node`)

On your Raspberry Pi running Raspberry Pi OS (Debian 64-bit):

```bash
# 1. Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# 2. Clone repository & build headless binary
git clone https://github.com/critmaths/neighbornet.git
cd neighbornet/neighbornet_core
cargo build --release --bin neighbornet_node
```

The compiled binary will be located at `target/release/neighbornet_node`.

---

## 3. Running the Transport Node

```bash
# Syntax: neighbornet_node [listen_port] [nickname] [--transport]
./target/release/neighbornet_node 42424 "Pi_Relay_NorthSector" --transport
```

### CLI Arguments:
- `42424`: UDP port to bind for Reticulum broadcast discovery on LAN/WLAN.
- `"Pi_Relay_NorthSector"`: Human-readable display nickname broadcast to peers.
- `--transport`: Enables full packet routing and store-and-forward replication for downstream leaf nodes.

---

## 4. Configuring `systemd` for Auto-Start on Boot

To ensure the relay restarts automatically after power outages or reboots:

1. Create a service file:
```bash
sudo nano /etc/systemd/system/neighbornet.service
```

2. Add the following configuration:
```ini
[Unit]
Description=NeighborNet Headless Reticulum Transport Node
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/neighbornet/neighbornet_core
ExecStart=/home/pi/neighbornet/neighbornet_core/target/release/neighbornet_node 42424 "Pi_Hub_Central" --transport
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

3. Enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable neighbornet
sudo systemctl start neighbornet
sudo systemctl status neighbornet
```

---

## 5. Solar & Battery Sizing Recommendations

| Component | Specification |
|---|---|
| **SBC** | Raspberry Pi Zero 2 W or Raspberry Pi 4 (Underclocked) |
| **Power Draw** | ~1.5W – 3.5W continuous |
| **Solar Panel** | 30W – 50W Monocrystalline 12V Panel |
| **Charge Controller** | 10A MPPT or PWM Solar Charge Controller |
| **Battery Storage** | 12V 10Ah – 20Ah LiFePO4 (Provides 3-5 days autonomy in cloudy weather) |
| **Enclosure** | IP66/IP67 Weatherproof Junction Box with vent gore |
