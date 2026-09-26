# Reticulum Mesh Cryptography & Routing 🔒⚡

> **In-depth technical breakdown of Ed25519 identity, X25519 ECDH link encryption, 128-bit destination hashes, and partition-tolerant DAG synchronization.**

---

## 1. Sovereign Cryptographic Identity

NeighborNet uses the **Reticulum Network Stack (RNS)** cryptographic design:

```text
[Private Key (32-byte Ed25519 Seed)] ──> [Public Signing Key] + [Public ECDH Key (X25519)]
                                                        │
                                                        └──> SHA-256 Hash ──> [128-bit Destination Hash]
                                                                              (e.g., 4a9f3b18c0e27189)
```

- **No Phone Numbers or Emails**: Identity is rooted purely in local asymmetric keys stored in `<data_dir>/identity.hex`.
- **Address Generation**: A node's 16-character hex address (128 bits) is the truncated cryptographic hash of its public keys.
- **Unforgeable Signatures**: Every message, bulletin, and barter transaction includes an Ed25519 digital signature.

---

## 2. Store-and-Forward DAG Synchronization

NeighborNet models all persistent state as a **Signed Directed Acyclic Graph (DAG)**:

```text
[Partition A: West Ridge]                [Partition B: East Valley]
Messages: [M1, M2, M3]                   Messages: [M1, M4, M5]
           │                                      │
           └────────────(Nodes Reconnect)─────────┘
                                │
                                v
               [Converged Mesh: M1, M2, M3, M4, M5]
```

### Sync Protocol Sequence:
1. **Periodic Announces**: Nodes broadcast periodic `Announce` envelopes containing their destination hash, role, and collection counts.
2. **Sync Request**: When a peer is discovered, a `SyncRequest` is exchanged containing known IDs.
3. **Reconciliation**: Missing items are fetched and verified against cryptographic signatures before being committed to local SQLite storage.
4. **Partition Tolerance**: Mesh splits can last days or weeks. When connectivity resumes, full history converges automatically without duplicate entries.
