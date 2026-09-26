# Zero-Install Web Gateway & Captive Portal Mode 🌐📱

> **Host an embedded tactical web portal that allows any neighbor, first responder, or refugee to communicate using standard phone or laptop browsers with zero installation.**

---

## 1. Overview

In disaster situations, most people will not have the NeighborNet native desktop or mobile app installed beforehand. 

The **Zero-Install Web Gateway** solves this by embedding a multi-threaded, zero-dependency HTTP server directly inside the Rust core (`neighbornet_core/src/web_gateway.rs`).

When combined with an open Wi-Fi access point (e.g. `NeighborNet-Open`), client devices that connect will automatically trigger OS captive portal detection, instantly launching the tactical web portal in their default browser.

---

## 2. Supported Captive Portal Probes

The Web Gateway detects and intercepts standard OS captive portal connectivity checks:

| Operating System | Probed URI | Interception Behavior |
|---|---|---|
| **Android / ChromeOS** | `/generate_204`, `/gen_204` | Serves `200 OK` with `PORTAL_HTML` SPA |
| **Apple iOS / macOS** | `/hotspot-detect.html` | Opens Captive Network Assistant with Web Portal |
| **Apple Safari** | `/library/test/success.html` | Serves `200 OK` with `PORTAL_HTML` SPA |
| **Microsoft Windows** | `/ncsi.txt`, `/connecttest.txt` | Triggers Action Center browser launch |

---

## 3. Launching from the Flutter Desktop UI

1. Open **Settings** in the NeighborNet app.
2. Scroll to the **Zero-Install Web Gateway & Captive Portal** card.
3. Configure the HTTP Port (default: `8080`).
4. Click **Start Web Gateway**.
5. Once active:
   - Click **Copy Portal URL** to share the local link (e.g. `http://192.168.1.50:8080`).
   - Click **Show QR Code** to display a large high-contrast QR code on your screen for smartphones to scan.
   - Click **Open in Browser** to test the web interface locally.
6. Under **Hotspot Captive DNS Auto-Redirect**:
   - Set the UDP DNS Port (default: `53`).
   - Click **Start DNS Redirect** to automatically resolve all client domain requests to the node IP.

---

## 4. Configuring a Dedicated Wi-Fi Hotspot on Linux / Raspberry Pi

To turn a Raspberry Pi into an automated captive portal hotspot (SSID: `NeighborNet-Open`):

### 1. Install `hostapd` and `dnsmasq`
```bash
sudo apt update && sudo apt install -y hostapd dnsmasq iptables
```

### 2. Configure Static IP on `wlan0` in `/etc/dhcpcd.conf`
```ini
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
```

### 3. Configure `dnsmasq` in `/etc/dnsmasq.conf`
Redirect all DNS queries (`#`) to the gateway IP `192.168.4.1`:
```ini
interface=wlan0
dhcp-range=192.168.4.10,192.168.4.200,255.255.255.0,24h
address=/#/192.168.4.1
```

> **Tip (Zero-Config Alternative)**: NeighborNet includes a built-in RFC 1035 UDP DNS server. If using `dhcpcd` or an external DHCP server without `dnsmasq`, you can launch the relay with `-z 53` (`--dns-redirect 53`) and it will automatically answer all domain queries with the node's IP address.

### 4. Configure `hostapd` in `/etc/hostapd/hostapd.conf`
```ini
interface=wlan0
driver=nl80211
ssid=NeighborNet-Open
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
```

### 5. Launch Node with Built-in Web Gateway & DNS Server
```bash
# Run headless node with Web Gateway on port 8080 and DNS redirect on UDP 53
sudo ./target/release/neighbornet_node -t -w 8080 -z 53
```

### 6. Redirect HTTP Traffic (Port 80 to 8080) with `iptables`
```bash
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
```

---

## 5. Web Portal Capabilities

The embedded Tactical Single-Page App (`PORTAL_HTML`) provides:
- **💬 Tactical Chat**: Live real-time messaging on `#general`.
- **📢 Bulletins**: View and post critical emergency notices.
- **📦 Barter Marketplace**: Post trade offers and request emergency supplies.
- **📖 Survival Manual**: Instant access to water purification ratios, START triage rules, and VHF/UHF calling channels.
- **🚨 SOS Beacon**: One-tap emergency broadcast across the entire mesh.
- **📡 Node Health**: Real-time connected peer count, active bulletins, and uptime.
