# Mutual Aid, Barter & Skills Marketplace 📦🤝

> **Decentralized offline trading ledger, resource exchange, peer counter-proposals, and cryptographic reputation matrix.**

---

## 1. Overview

When banking networks, electronic point-of-sale systems, and fiat currencies are unavailable, local communities rely on **Mutual Aid & Direct Barter**.

NeighborNet provides a serverless, cryptographic trade ledger that replicates across the mesh without any central auction house or administrator.

---

## 2. Listing Types & Categories

### Listing Types:
- **Offering Item / Resource (`offer`)**: Tangible physical goods available for exchange (e.g. 5 Gal Diesel Fuel, Water Filtration Cartridges).
- **Requesting / ISO (`request`)**: Critical supplies needed by a household or clinic (e.g. Pediatric Antibiotics, Generator Spare Parts).
- **Offering Skill / Mutual Aid (`skill`)**: Labor, technical skills, or equipment operation (e.g. Chainsaw Clearing, Solar Inverter Repair, Ham Radio Relay).

### Trade Categories:
- `fuel` — Gasoline, Diesel, Propane, Firewood, Lamp Oil.
- `food_water` — MREs, Bulk Grains, Water Gallons, Purification Tablets.
- `medical` — Trauma Kits, Antibiotics, Suture Kits, Pain Relievers.
- `tools` — Generators, Hand Tools, Solar Panels, Water Pumps.
- `shelter` — Tents, Tarps, Sleeping Bags, Space Blankets.
- `skills` — CERT, Medic, Carpentry, Welding, Radio Operator.
- `comms` — Radios, Antennas, Battery Banks, Cables.
- `general` — Miscellaneous survival gear and household goods.

---

## 3. The Counter-Proposal Workflow

```text
[Alice] Posts Listing: "10 Gal Potable Water (Seeking: 2x 100W Solar Panels)"
   │
   ├──> [Bob] Submits Proposal: "Offers: 1x 150W Solar Panel + 12V Charge Controller"
   │       │
   │       └──> [Alice] Reviews Counter-Offer ──> [Accepts Proposal]
   │                                                    │
   └───(Both Nodes Mark Listing "Completed") <──────────┘
```

1. **Submitting an Offer**: Any peer can click **Make Trade Proposal** on an active listing, specifying what items they offer and a counter-proposal message.
2. **Reviewing Offers**: The listing author sees all incoming proposals, their sender's callsign, and reputation rating.
3. **Acceptance**: Accepting an offer marks the listing as `pending` or `completed`, notifying the peer over the mesh.

---

## 4. Trust & Reputation Matrix (Community Vouches)

To prevent scammers or bad actors from exploiting an emergency:

- Every node maintains a cryptographic vouch history (`CommunityVouch`).
- Peers can rate transaction partners (1 to 5 Stars) and provide signed text reviews.
- Vouches are cryptographically signed with the voucher's Ed25519 private key.
- The average rating and total vouch count are displayed next to every listing author's name.
