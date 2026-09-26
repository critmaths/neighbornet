# Tactical Walkie-Talkie (PTT) & Voice Comms 📻🎙️

> **Simplex half-duplex digital voice communications with floor arbitration, squelch control, VOX, and emergency break-in override.**

---

## 1. Operating Architecture

The **Walkie-Talkie (PTT)** subsystem provides low-latency half-duplex voice communication across the local Reticulum mesh.

```text
[Operator A (Talk)] ──(PTT Floor Lock)──> [Mesh Channel (e.g. #ops-1)]
         │                                            │
         └───(Audio Chunks: 8KB Base64 / 300ms)─────> ├──> [Operator B (Speaker)]
                                                      └──> [Operator C (Speaker)]
```

---

## 2. Floor Arbitration & Token State Machine

To prevent packet collisions and chaos on shared mesh channels, NeighborNet enforces a digital floor arbitration state machine (`neighbornet_app/lib/services/ptt_service.dart`):

| Floor State | Meaning | Action Allowed |
|---|---|---|
| **IDLE / STANDBY** | Channel is clear. | Any operator can press PTT to seize the channel. |
| **TRANSMITTING** | Local node holds the floor. | Audio is captured, chunked, and broadcast. |
| **RECEIVING** | Remote station holds the floor. | Audio chunks stream into speaker buffer; PTT is locked. |
| **FLOOR OCCUPIED** | Another peer is talking. | Standard PTT attempts are rejected with a busy tone. |

### Emergency Distress Break-In Override:
When an operator sets **Priority: Emergency / Distress**, the transmission automatically breaks through and revokes any active standard floor hold, broadcasting the urgent transmission to all listeners immediately.

---

## 3. Hardware & Audio Controls

In the **Walkie-Talkie (PTT)** view:

1. **PTT Button**: Hold down the large central push-to-talk button or press the keyboard shortcut (`Spacebar` / `F12`) to transmit.
2. **Channel Selector**: Select active tactical net (`TAC-1 / Command`, `TAC-2 / Medical`, `TAC-3 / Logistics`, `EMERGENCY / Distress`, `WATERCOOLER / Local`).
3. **Squelch Control**: Adjust digital squelch threshold to eliminate background noise.
4. **VOX (Voice Activated Transmission)**: Enable hands-free transmission triggered by microphone input thresholds.
5. **Roger Beep**: Generates an audible tone burst at the end of each transmission to signal channel release.

---

## 4. Tactical Radio Protocol & Etiquette

When transmitting over emergency mesh channels, observe standard radio discipline:

- **Identify**: State your tactical callsign and destination (e.g., `Unit-4 to Base, radio check`).
- **Be Concise**: Keep voice bursts under 15 seconds to allow other stations access.
- **Acknowledge**: End transmissions with `Over` (inviting reply) or `Out` (ending conversation).
- **Distress Precedence**: Instantly yield the floor if an emergency distress banner or alarm is detected.
