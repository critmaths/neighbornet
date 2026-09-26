# Encrypted Group Vault & Chunked File Sharing 🔐📁

> **Transfer large survival manuals, drone maps, and field guides over bandwidth-limited mesh networks using 8 KB content-addressed chunks and authenticated symmetric vaults.**

---

## 1. 8 KB Content-Addressed Chunking

Mesh networks (especially Wi-Fi hops and radio links) suffer from intermittent packet drops. Transferring large monolithic files causes frequent failures and restarts.

NeighborNet solves this by slicing every shared file into **8,192-byte (8 KB) content-addressed chunks**:

```text
[Large PDF / Drone Map (2.4 MB)]
         │
         ├──> Chunk 000 (8 KB) ──> SHA-256 Checksum: e3b0c442...
         ├──> Chunk 001 (8 KB) ──> SHA-256 Checksum: 8f49a21b...
         ├──> Chunk ...
         └──> Chunk 300 (8 KB) ──> SHA-256 Checksum: 1a94bc72...
```

- **Resilient Resume**: If a transmission drops at 85%, only the missing chunks are re-requested.
- **Multi-Source Fetching**: Chunks can be retrieved simultaneously from multiple neighboring nodes.
- **Bit-Rot Protection**: Each chunk is verified against its SHA-256 hash before disk assembly.

---

## 2. Encrypted Group Vaults

When sharing sensitive tactical intelligence (e.g. secure retreat coordinates, weapons rosters, or private medical records):

1. **Passphrase Protection**: The publisher checks **Encrypt with Passphrase**.
2. **Key Derivation**: NeighborNet generates a random 16-byte cryptographic salt and derives a 256-bit encryption key using `Sha256(Salt || Passphrase || "NNET_VAULT_KEY")`.
3. **Authenticated Encryption**: The file payload is XOR-stream encrypted with a counter-mode keystream, and an authenticated HMAC-SHA256 signature tag is attached.
4. **Encrypted Distribution**: The encrypted file is distributed across the mesh. Intermediate nodes store and relay chunks without ever learning the file contents.
5. **Decryption**: Only peers who enter the correct passphrase can decrypt and unpack the file to disk.

---

## 3. File Vault Categories

Files are organized into search filters:
- `manuals` — Field survival guides, radio frequency lists, medical handbooks.
- `maps` — Drone ortho-mosaics, topographical offline maps, street grids.
- `audio` — Voice memos, recorded sitreps, dispatch logs.
- `general` — Firmware updates, images, data backups.
