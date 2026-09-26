# Duress Protocol & Emergency Panic Wipe 🚨💥

> **Cryptographic data sanitization, multi-pass file shredder, database vacuum purging, and hostile inspection device surrender protocol.**

---

## 1. Threat Model & Purpose

In disaster, civil unrest, or occupied territory scenarios, operators may face:
- Hostile physical checkpoint inspection.
- Device seizure or surrender under duress.
- Compromised physical security of a relay station.

The **Panic Wipe Protocol** allows an operator to instantly and irrevocably destroy all private cryptographic keys, contact books, barter records, and chat transcripts in under 500 milliseconds.

---

## 2. Multi-Pass Shredding Sequence

When the Panic Wipe is triggered (`neighbornet_panic_wipe()`):

1. **Private Key Shredding (`identity.hex`)**:
   - Overwritten with `0x00` null bytes.
   - Overwritten with `0xFF` inverted bits.
   - Overwritten with cryptographically secure random bytes from `OsRng`.
   - Flushed to physical disk (`fsync`), then unlinked and deleted.
2. **Database Purge (`neighbornet.db`)**:
   - `DROP TABLE messages`, `DROP TABLE bulletins`, `DROP TABLE shared_files`, `DROP TABLE barter_listings`, `DROP TABLE form_entries`, `DROP TABLE tactical_markers`.
   - `VACUUM` executed to zero out unallocated SQLite pages.
   - Database connection closed and file removed from filesystem.
3. **Cache & Vault Shredding**:
   - Deletes all stored files in `<data_dir>/files/`.
   - Deletes all room metadata in `<data_dir>/rooms/`.
   - Deletes all governance logs in `<data_dir>/governance/`.
4. **Memory Cleanse & Ephemeral Regeneration**:
   - In-memory keys and buffers are overwritten and cleared.
   - The node generates a new ephemeral identity so the app appears as a completely blank, newly initialized device.

---

## 3. How to Trigger Panic Wipe

### From the Flutter UI:
1. Go to **Settings**.
2. Scroll to the red **Duress Protocol / Panic Wipe** card.
3. Click **EXECUTE PANIC WIPE**.
4. Confirm the warning dialog.

### From the Headless CLI Daemon:
Send the `SIGUSR2` signal or delete the `identity.hex` file.
