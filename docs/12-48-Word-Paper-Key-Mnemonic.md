# 48-Word BIP-39 Paper Key Mnemonic 🔑📝

> **Secure cold-storage identity backup, disaster recovery, and paper seed restoration.**

---

## 1. Why a 48-Word Seed Phrase?

Reticulum private identities are 64 bytes (512 bits) of raw cryptographic entropy containing both the Ed25519 signing private key and the X25519 ECDH private key.

To allow operators to store their entire cryptographic identity on physical paper (or metal plates) without digital media, NeighborNet encodes this 512-bit key into a standard **48-Word BIP-39 Mnemonic Seed Phrase**:

```text
[512-bit Reticulum Private Identity]
               │
               v (BIP-39 Wordlist Mapping)
[ 48 English Words (11 bits entropy per word) ]
```

---

## 2. Exporting Your Paper Key

1. In the NeighborNet app, open **Settings**.
2. Click **EXPORT 48-WORD PAPER KEY**.
3. Write down all 48 numbered words on waterproof paper or stamp them into stainless steel/titanium plates.
4. **Never save this phrase in unencrypted cloud storage or take a digital photo.**

---

## 3. Restoring Identity on a New Device

If your original device is destroyed, confiscated, or submerged in water:

1. Install NeighborNet on a replacement laptop or phone.
2. In **Settings**, select **Restore Identity from Mnemonic**.
3. Enter your 48 words in exact sequential order.
4. NeighborNet will reconstruct your exact 512-bit private key.
5. Your node address hash (`dest_hash`), digital signature verification, and room access will be restored immediately.
