# Democratic Room Governance & Stewardship 🗳️🏛️

> **Decentralized community moderation, steward election proposals, quorum evaluation, and signed immutable audit trails.**

---

## 1. Overview

NeighborNet rejects centralized authoritarian channel management. In long-term disaster survival or mutual aid communities, leadership and moderation must be democratic, accountable, and transparent.

---

## 2. Stewardship Voting Lifecycle

```text
[Operator Proposes Vote: "Promote Bob to Sector Steward"]
                      │
                      ├──> Broadcasts `VoteProposal` to Room Members
                      │
                      ├──> Members Cast Cryptographic Ballots (`VoteBallot`)
                      │
                      └──> Quorum Evaluator Calculates Majority
                                   │
                    ┌──────────────┴──────────────┐
                    v                             v
           [Quorum Met: PASSED]          [Quorum Failed: REJECTED]
                    │
                    └──> Modifies Room Stewards List + Signs Audit Log
```

---

## 3. Quorum & Consensus Rules

Consensus rules are calculated based on active room participants:

- **Single Node / Creator**: 1 vote required.
- **2 Participants**: Unanimous 2/2 consensus required.
- **3+ Participants**: Strict democratic majority `(N / 2) + 1` required.

---

## 4. Immutable Audit Logs

Every governance action (proposal creation, ballot cast, promotion, demotion, policy update) is appended to the room's **Signed Governance Audit Log**:
- Contains the voter's destination hash and timestamp.
- Cryptographically verified across all nodes.
- Prevents silent administrative tampering or rogue channel takeovers.
