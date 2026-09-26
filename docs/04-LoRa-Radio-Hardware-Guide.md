# Hardware LoRa Radio & Antenna Guide 📟📻

> **Interface sub-GHz long-range LoRa radios with NeighborNet via USB-UART serial and the KISS protocol.**

---

## 1. Supported Hardware Transceivers

NeighborNet supports standard LoRa development boards and transceivers running standard serial firmware or RNode firmware:

| Device Model | Typical Frequency | Interface | Recommended Role |
|---|---|---|---|
| **Heltec WiFi LoRa 32 (V2/V3)** | 915 MHz / 868 MHz / 433 MHz | USB-C (CP2102/CH9102) | Handheld / Portable Gateway |
| **LilyGO TTGO T-Beam (SX1262 / SX1276)** | 915 MHz / 868 MHz / 433 MHz | Micro-USB / USB-C | GPS Mobile Node / Tracker |
| **LilyGO T-Echo (nRF52840 + SX1262)** | 915 MHz / 868 MHz | USB-C / BLE | Ultra-Low-Power Base Station |
| **Custom RNode Hardware** | Any ISM Band | USB-UART / Serial | Dedicated Regional Repeater |

---

## 2. LoRa Radio Protocol (KISS Framing)

NeighborNet interfaces with serial radios using the standard **KISS Protocol** (`neighbornet_core/src/kiss.rs`):

- **FEND (`0xC0`)**: Frame End delimiter.
- **FESC (`0xDB`)**: Frame Escape marker.
- **TFEND (`0xDC`)**: Transposed Frame End.
- **TFESC (`0xDD`)**: Transposed Frame Escape.

This ensures transparent byte-streaming of raw Reticulum wire envelopes over 115,200 baud serial connections.

---

## 3. Configuring LoRa in the NeighborNet App

1. Connect your LoRa device to your PC or Raspberry Pi via USB.
2. In the NeighborNet desktop app, go to **Settings** -> **LoRa Tactical Radio (KISS / RNode)**.
3. Click **Scan Ports** to detect available serial ports (e.g. `COM3` on Windows or `/dev/ttyUSB0` on Linux).
4. Select your parameters:
   - **Baud Rate**: `115200`
   - **Frequency**:
     - **US / Americas**: `915.0 MHz`
     - **Europe / Africa**: `868.0 MHz`
     - **Asia / Amateur**: `433.0 MHz`
   - **Bandwidth**: `125 kHz` (Standard) or `250 kHz` (High Throughput)
   - **Spreading Factor**: `SF10` (Balanced range/speed), `SF7` (Fast/Short), or `SF12` (Maximum Extreme Range)
   - **Coding Rate**: `4/5` (5) or `4/8` (8)
5. Click **Connect Radio**.
6. The status badge will change to **RADIO ONLINE**, and the TX/RX packet counters and live RSSI / SNR signal readouts will begin reporting.

---

## 4. Antenna Recommendations & Range Tuning

| Antenna Type | Gain | Range (Line-of-Sight) | Best Use Case |
|---|---|---|---|
| **Stock Rubber Ducky** | ~2 dBi | 1 – 3 km | Tactical indoor / close quarters |
| **Tuned 1/2 Wave Dipole** | 2.15 dBi | 5 – 10 km | General neighborhood coverage |
| **Fiberglass Omnidirectional Base** | 5.8 – 8 dBi | 15 – 30 km | Rooftop / Tower repeater hubs |
| **Yagi Directional Antenna** | 10 – 14 dBi | 30 – 60+ km | Point-to-point cross-valley links |

> [!TIP]
> Keep coaxial cable runs as short as possible. Use low-loss cable (LMR-400 or RG-213) for mast installations to prevent RF signal attenuation.
