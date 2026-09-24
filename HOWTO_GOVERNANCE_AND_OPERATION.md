# NeighborNet: How-To, Governance & Operational Manual 🌐📖

> **A Comprehensive Technical and Logical Reference for Decentralized Local Mesh Operation, Democratic Governance, Room Stewardship, and Partition Reconciliation.**

---

## Table of Contents
1. [Core Product Philosophy & Architecture](#1-core-product-philosophy--architecture)
2. [Identity & Networking Substrate (Reticulum)](#2-identity--networking-substrate-reticulum)
3. [Dynamic Room Creation & Life Cycle](#3-dynamic-room-creation--life-cycle)
4. [Democratic Stewardship & Voting Mechanics](#4-democratic-stewardship--voting-mechanics)
5. [Anti-Coup & Anti-Sybil Defense (Time-Weighted Tenure)](#5-anti-coup--anti-sybil-defense-time-weighted-tenure)
6. [Impeachment, Demotion & The Public Audit Trail](#6-impeachment-demotion--the-public-audit-trail)
7. [Network Splits, Forks & The "Peace Treaty" Reconciliation Protocol](#7-network-splits-forks--the-peace-treaty-reconciliation-protocol)
8. [Decentralized Content-Addressed File Sharing](#8-decentralized-content-addressed-file-sharing)
9. [Audio & Video Transport Capabilities & Error Handling](#9-audio--video-transport-capabilities--error-handling)
10. [Technical Troubleshooting & Operational Scenarios](#10-technical-troubleshooting--operational-scenarios)

---

## 1. Core Product Philosophy & Architecture

### 1.1 The Non-Centralized Imperative
Traditional internet communications depend entirely on centralized server farms, ISP routing tables, DNS registries, and corporate trust-and-safety moderators. In a grid collapse, hurricane, earthquake, or severe telecom outage, these centralized pillars collapse instantly.

NeighborNet is designed with a fundamental rule: **No Single Point of Failure, Zero Central Servers.**
Every device running NeighborNet is a sovereign node containing its own cryptographic keys, local database, and mesh routing capabilities.

### 1.2 The "Organizer, Not Dictator" Stewardship Philosophy
In traditional apps, "moderators" and "admins" wield autocratic power: they can ban, censor, and delete arbitrarily. In an emergency community network, autocratic power invites abuse and infighting. 

NeighborNet re-frames moderation into **Community Stewardship**:
- The goal is **not punitive censorship**, but **coordination and organization**.
- Stewardship is **crowd-determined, transparent, and revocable**.
- Every decision has a public cryptographic audit trail.

---

## 2. Identity & Networking Substrate (Reticulum)

### 2.1 Cryptographic Identity
- Every NeighborNet instance generates an asymmetric cryptographic keypair upon first launch using **Ed25519** for signing and **X25519** for ECDH key exchange.
- The user's **Reticulum Destination Hash** is a truncated 128-bit SHA-256 digest (32 hexadecimal characters).
- Users do **not** register with phone numbers, emails, or government IDs. Identity is mathematically tied to the local cryptographic private key stored in `<data_dir>/identity.hex`.

### 2.2 Wire Transport
NeighborNet broadcasts UDP discovery packets on port `42424` across `255.255.255.255` and local interfaces. When packets are received, nodes establish direct peer links, exchange manifests, and synchronize missing data over an append-only Signed Directed Acyclic Graph (DAG).

---

## 3. Dynamic Room Creation & Life Cycle

### 3.1 Room Creation
Users can dynamically instantiate topic-specific rooms (e.g. `#water-distribution`, `#medical-triage`, `#ham-radio-operators`).
- **Genesis Steward**: The individual node that generates the room becomes its initial founding Steward.
- **Room Metadata Envelope**:
  ```json
  {
    "id": "room_a1b2c3d4...",
    "name": "water-distribution",
    "description": "Clean water tanker schedule and purification points",
    "creator_hash": "e4f8a910...",
    "created_sec": 1727145000,
    "is_private": false,
    "stewards": ["e4f8a910..."]
  }
  ```
- Rooms are automatically announced across the local mesh. Connected peers replicate the room entry in their local catalog.

---

## 4. Democratic Stewardship & Voting Mechanics

Stewardship is governed democratically using signed cryptographic ballot envelopes (`VoteProposal` and `VoteBallot`).

```text
               GOVERNANCE PROGRESSION RULES
 
      1 Member (Genesis)      --> Room creator is initial Steward
      2 Members (Consensus)    --> Co-steward requires 100% agreement
      3+ Members (Quorum)     --> Democratic Majority (>50%) required
```

### 4.1 Progression & Quorum Thresholds

1. **Genesis (1 Member)**:
   - When only the creator is present in the room, they hold Steward privileges to organize channels, set descriptions, and pin notices.
2. **Consensus Mode (2 Members)**:
   - When a second member joins, the room enters **Consensus Mode**.
   - Promoting the second member requires unanimous agreement between both nodes.
   - If either disagrees, the room awaits a third member to achieve an odd-numbered quorum.
3. **Majority Quorum Mode (3+ Members)**:
   - When 3 or more tenured members are present, all governance proposals require a **simple majority (>50%)** of active tenured participants:
     $$\text{Required Votes} = \left\lfloor \frac{N_{\text{tenured}}}{2} \right\rfloor + 1$$
   - Example: In a 5-member council, 3 affirmative votes pass a promotion or demotion.

### 4.2 The Ballot Envelope Lifecycle
1. **Proposal**: Any tenured member can propose a vote (`PROMOTE_STEWARD` or `DEMOTE_STEWARD`).
2. **Voting Window**: The ballot remains active for 24 hours (or until a definitive majority is mathematically achieved).
3. **Execution**: Once affirmative votes reach the threshold, the proposal status transitions to `PASSED`. The target node's public hash is added to or removed from `stewards` in the room manifest.

---

## 5. Anti-Coup & Anti-Sybil Defense (Time-Weighted Tenure)

### 5.1 The Threat: Flash-Mob / Sybil Takeovers
In a pure peer-to-peer network without identity cards, an attacker could launch 10 virtual nodes on a laptop and instantly vote out the real neighborhood coordinator.

### 5.2 The Defense: Time-Weighted Tenure
NeighborNet implements a cryptographic **Proof-of-Tenure** mechanism:
- **Tenure Requirement**: A node's vote is only counted if that node has been continuously observed on the local mesh for at least **1 hour** (in Emergency Mode) or **24 hours** (in Standard Mode).
- **Proportional Threshold Scaling**: The older and larger a room becomes, the higher the minimum tenure required to participate in steward demotions:
  $$\text{Min Tenure} = \min(72 \text{ hours}, \text{Room Age} \times 0.25)$$
- **Effect**: A flash mob of newly created virtual devices cannot seize control of an established neighborhood room.

---

## 6. Impeachment, Demotion & The Public Audit Trail

### 6.1 Demotion Grounds & Categorization
When proposing the demotion of a steward, the proposer MUST provide a standardized reason category and specific details:
- **Inactivity**: Steward has been offline or unreachable during a critical coordination window.
- **Spam / Disruption**: Flooding channels or broadcasting malicious links.
- **Misinformation**: Posting unverified or hazardous survival directives.
- **Abuse of Power**: Attempting unauthorized silencing of participants.
- **Other**: Free-form reason specified by the proposer.

### 6.2 The Public Audit Trail Banner
Demotions can **never** happen in secret. When a demotion passes:
1. An immutable `GovernanceEvent` is signed and broadcast to the DAG.
2. The UI renders a clean, transparent historical banner in the room:
   > ⚖️ *Steward Bob was demoted by Alice & Charlie on Sept 23 (Reason: Inactivity - Absent during evacuation).*
3. Any user can tap the banner to inspect the cryptographic signatures of the voters and the full text explanation.

---

## 7. Network Splits, Forks & The "Peace Treaty" Reconciliation Protocol

### 7.1 What Happens When Groups Disagree (Forking)
If an individual or sub-group is dissatisfied with a room's democratic vote, they have the sovereign right to **Fork**:
- They leave the room and generate a new room branch with their own stewards.
- Unlike centralized platforms that ban users into silence, NeighborNet allows communities to divide gracefully if consensus fails.

### 7.2 The "Peace Treaty" Reconciliation Protocol
In disaster scenarios, two physically separated neighborhoods (e.g., North Hill and South Valley) may have operated independently for days or weeks. When physical roads clear or radio links reconnect, their nodes collide.

NeighborNet implements an automated **Reconciliation Protocol**:
1. **Collision Detection**: The stack detects that two rooms share the same original name and genesis root.
2. **Cooperation Score Analysis**: The nodes exchange uptime milestones and message density metrics.
3. **Reconciliation Prompt**: Both communities receive an interactive prompt:
   > 🤝 *"Neighboring community 'water-distribution' (18 nodes) is now in range. Would you like to vote to merge councils?"*
4. **Union Vote**: If both communities approve by majority vote, the steward lists are merged into a unified coalition council, and chat histories are combined chronologically!

---

## 8. Decentralized Content-Addressed File Sharing

### 8.1 Chunking & Hash Addressing
- Files are partitioned into **8 KB chunks** (`FILE_CHUNK_SIZE = 8192`).
- Each file is referenced globally by the SHA-256 hash of its entire content.
- Chunks are stored on disk in `<data_dir>/files/chunks/<file_hash>/<chunk_index>`.
- Reassembled files are verified against the SHA-256 manifest before being marked `is_complete = true`.

### 8.2 Opportunistic Replication
- Users do not need to download files manually. Nodes can mark critical resources (e.g. `Emergency_Triage.pdf`) for **Automatic Replication**, ensuring survival guides propagate across every device in the neighborhood.

---

## 9. Audio & Video Transport Capabilities & Error Handling

### 9.1 Adaptive Transport Ladder
NeighborNet dynamically assesses link bandwidth and MTU to prevent packet congestion:
1. **High Bandwidth (Local Wi-Fi / Community Ethernet Mesh > 250 kbps)**:
   - Unlocks real-time **WebRTC P2P Video** and **Opus Push-to-Talk Voice**.
2. **Narrowband Mesh (LoRa / VHF Packet Radio < 10 kbps)**:
   - **Video is strictly disabled** with an explicit user notification: *"Video unavailable: Narrowband mesh link active."*
   - Audio switches to ultra-compact **Codec2** (700–3200 bps) or asynchronous chunked voice memos.

### 9.2 Error & Drop Handling
If packet loss exceeds 25%, the audio engine automatically down-samples bitrate or shifts to asynchronous store-and-forward voice notes to prevent network starvation.

---

## 10. Technical Troubleshooting & Operational Scenarios

| Scenario | Cause | Solution |
| :--- | :--- | :--- |
| **No nearby peers detected** | Wi-Fi client isolation or firewall blocking UDP `42424` | Ensure local devices are on the same Wi-Fi/hotspot or connect an Ethernet switch; allow UDP 42424 in Windows Firewall. |
| **File download stuck at 80%** | The peer holding the remaining chunk disconnected | The request remains queued; chunk transfer automatically resumes as soon as any peer carrying that chunk comes into radio range. |
| **Vote not counting** | Node tenure on mesh is below minimum threshold | Wait until node tenure exceeds the required time window (anti-Sybil security policy). |
| **Split network partitions** | Physical barrier or radio range limit | Connect a portable Raspberry Pi transport node midway between both groups to bridge packets. |
| **Corrupted downloaded file** | Packet bitflip or truncated transfer | NeighborNet automatically discards non-matching SHA-256 reassemblies and re-requests corrupted chunks. |

---
*NeighborNet Documentation — Sovereign, Local-First, Resilient Communications.*
