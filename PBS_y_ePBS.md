# PBS y ePBS (EIP-7732) — De la separación de roles a Glamsterdam

---

# Parte 1 — Entendiendo el problema y la solución

---

## 1. What is PBS?

PBS (Proposer-Builder Separation) splits block production into two distinct roles:

1. **Block Builders**
   - Search for MEV opportunities
   - Bundle transactions optimally
   - Compete to offer highest bids
   - Run specialized MEV software

2. **Block Proposers**
   - Select highest bid blocks
   - Verify block validity
   - Propose blocks to network
   - Don't need specialized MEV knowledge

### Without PBS

- Large validators dominate MEV extraction
- Need expensive infrastructure
- Complex MEV search algorithms
- Faster network connections required
- Leads to centralization

### With PBS

- More democratic MEV distribution
- Lower barrier to entry
- Specialized roles
- Market-driven efficiency
- Better for small validators

### Example Flow

```
Builder A: Finds 1 ETH MEV → Bids 0.7 ETH
Builder B: Finds 0.8 ETH MEV → Bids 0.6 ETH
Builder C: Finds 1.2 ETH MEV → Bids 0.9 ETH

Proposer: Selects Builder C's block (highest bid)
Result: More efficient MEV extraction and fairer distribution
```

---

## 2. The Real Problem — Timing Pressure

Entender ePBS requiere entender primero POR QUÉ el diseño actual de Ethereum tiene un problema de timing.

### What Happened After the Merge

The Merge combinó dos tipos de datos completamente diferentes en un solo bloque:

- **Consensus block**: attestations, deposits, exits — todo lo necesario para decidir cuál es el HEAD de la cadena.
- **Execution payload**: las transacciones y todo lo que modifica el estado de la EVM.

Ambos viajan juntos, se validan juntos, y los validadores tienen que procesar TODO en ~4 segundos. Eso es el problema.

### How a Slot Works Today (12 seconds)

**Before Slot N — Preparation:**

```
12 seconds before slot N:
├── Validator knows it's their turn to propose
├── Begins preparing the block
├── Collects transactions from mempool
├── Can use MEV-Boost to get blocks from builders
├── Signs the complete block
└── Has ~12 seconds to prepare everything
```

**Second 0 — Block Publication:**

```
Slot N starts (second 0):
├── Validator ALREADY HAS the block ready
├── Immediately broadcasts to P2P network
├── Block propagates through nodes
└── Other validators start receiving it
```

**Seconds 0-4 — The Stress Window:**

Every validator must do ALL of this before the 4-second attestation deadline:

```
0.0-0.3s  Receive the block via P2P (100-500ms depending on location)
0.3-0.4s  Validate consensus structure (signatures, committees)
0.4-3.5s  Execute ALL transactions + verify state transitions
3.5-3.8s  Validate blob data availability (DAS)
3.8-4.0s  Run fork choice, create and sign attestation
───────── 4.0s: DEADLINE — miss it = no rewards
```

**That's 3 seconds of actual work crammed between network latency and a hard deadline.** And it gets worse.

### The Timing Game Problem

Proposers are incentivized to publish their block **as late as possible** — the longer they wait, the more transactions accumulate in the mempool, the more MEV they can capture.

```
HONEST PROPOSER                    GREEDY PROPOSER
0s: Broadcasts immediately         0s: Slot starts, waits...
0.1s: Block propagates             1s: "More transactions coming?"
0.5s: Validators start working     2s: Finally broadcasts
3.5s: Most validators done         2.3s: Block propagates
4.0s: Easy attestation deadline    2.3-4.0s: Validators have ~1.7s!
                                   4.0s: Many miss the deadline
```

The greedy proposer captures more MEV but steals time from every other validator in the network. And there's nothing in the protocol to prevent this.

> *Potuz explains this exact problem clearly in his [Devconnect Bangkok talk](https://www.youtube.com/watch?v=w-VwYHq1FA4) (minutes 3:18-4:50).*

---

## 3. Current PBS (MEV-Boost) — Separation Without Protocol Support

MEV-Boost implements PBS today, but outside the protocol. It uses trusted **relays** as intermediaries:

```
Builder → creates profitable block
   ↓ sends bid to Relay
Relay → receives bids from multiple builders, picks best
   ↓ sends header to Proposer (without revealing transactions)
Proposer → signs header blindly (can't see the txs)
   ↓ returns signature to Relay
Relay → reveals full block to the network
```

~90% of Ethereum blocks are built this way.

### Trust Assumptions

| Who trusts whom | What they trust | What if broken |
|---|---|---|
| Builder → Relay | Won't steal MEV strategies | Builder loses profits |
| Proposer → Relay | Bid is valid, payment will arrive | Proposer gets nothing |
| Proposer → Relay | Block is legitimate | Proposer signs invalid block |
| Network → Relay | Will reveal the block | Slot is missed |

### Why This is Dangerous

1. **Centralization** — Very few relays operate (Flashbots dominates)
2. **No penalties** — If a relay misbehaves, no stake is slashed — the protocol doesn't know relays exist
3. **Censorship** — A relay can refuse to pass blocks with certain transactions (OFAC compliance)
4. **Single point of failure** — If relays go down, most block production breaks

### MEV-Boost Didn't Fix the Timing Problem

PBS with relays changes WHO builds the block, but NOT HOW it's transmitted or validated. The proposer still broadcasts consensus + execution + blobs all at once at second 0, and validators still have to process everything by second 4.

```
SECOND 0: Proposer broadcasts 3 things simultaneously:

  Consensus P2P:                  Execution P2P:               Blob P2P:
  ├── Beacon block (~few KB)      ├── Full execution payload    ├── Blob data (up to 4.5MB)
  ├── Execution payload header    ├── All transaction data      ├── Blob sidecars
  ├── Blob KZG commitments        └── State transition proof    └── KZG proofs
  └── Proposer signature

SECONDS 0-4: Validators must process ALL of it:

  0.0-0.3s  Receive ALL pieces via P2P
  0.3-0.4s  Consensus validation (structure, signatures, committees)
  0.4-3.5s  Execute ALL transactions + verify state transitions
  3.5-3.8s  Blob validation (DAS — sample random pieces, verify KZG proofs)
  3.8-4.0s  Fork choice + sign attestation
  ──────── 4.0s: DEADLINE — miss = no rewards

  The timing squeeze is IDENTICAL to the no-PBS case.
```

**The fundamental problem isn't who builds the block — it's that consensus and execution are coupled in time.**

---

## 4. ePBS — The Solution (EIP-7732)

ePBS (Enshrined Proposer-Builder Separation) takes PBS and **puts it inside the protocol**. But the real insight isn't just "remove relays" — it's **decouple consensus validation from execution validation in time**.

**Scheduled for:** Glamsterdam hard fork (EIP-7773)

### The Core Idea

Instead of broadcasting everything at once:

1. **Second 0:** Proposer publishes a small consensus block with the builder's **commitment** (not the full payload)
2. **Seconds 0-4:** Validators attest to the consensus block only — no execution needed, trivially fast
3. **Second 4:** Builder reveals the full execution payload
4. **Seconds 4-12:** Everyone validates the execution payload — **8 seconds** instead of 3

The consensus phase and the execution phase happen **sequentially, not simultaneously**.

### ePBS Key Changes

1. **Builders become protocol entities**
   - Staked on the Beacon Chain (minimum 1 ETH deposit)
   - Have an on-chain balance that can be debited
   - Protocol knows they exist and can penalize them

2. **Relays are eliminated**
   - No off-chain intermediaries
   - Builder commits directly on-chain
   - Payment enforced by consensus rules

3. **Commit-reveal mechanism**
   - Builder signs a bid: block hash + payment amount
   - Proposer includes that bid in the beacon block
   - Builder reveals later in the slot
   - If builder doesn't reveal → loses payment anyway (unconditional)

4. **Payload Timeliness Committee (PTC)**
   - 512 validators verify the builder revealed on time
   - Replaces the relay's "honest witness" role
   - Decentralized, randomly selected, protocol-enforced

---

## 5. ePBS Slot — Second by Second

### Slot N-1: Builder Preparation (No Time Pressure)

```
Builders work in the background:
├── Analyze mempool for MEV opportunities
├── Optimize transaction ordering
├── Construct execution payloads
├── Create cryptographic commitments (block hash)
├── Submit bids (header + payment amount)
└── 12+ seconds available — quality over speed
```

### Slot N, Second 0: Proposer Commits Instantly

```
Proposer acts IMMEDIATELY:
├── Selects winning builder (highest bid)
├── Creates beacon block containing builder's signed commitment
├── Signs and broadcasts

Beacon block contains:
├── Builder's signed bid (commitment + payment)  ~few KB
├── Attestations from previous slot
├── Slashings, deposits, exits
└── NO execution payload, NO transactions, NO blobs

Propagation: 50-100ms (tiny block, consensus network only)
```

### Slot N, Seconds 0-4: Consensus Validation (Simple and Fast)

```
Every validator:
  0.0-0.1s  Receive beacon block (small, fast)
  0.1-0.5s  Validate consensus structure
  0.5-1.0s  Verify signatures (proposer + builder commitment)
  1.0-2.0s  Check committee assignments
  2.0-3.0s  Validate commitment format + builder balance
  3.0-4.0s  Run fork choice, create and sign attestation
  ──────── 4.0s: Attestation deadline — EASY to meet

  What they DON'T do:
  ├── NO transaction execution
  ├── NO state transition processing
  ├── NO blob data verification
  └── Just consensus — trivially fast
```

**Compare: today validators must execute all transactions in this window. With ePBS they just check a commitment. The 4-second deadline becomes trivial.**

### Slot N, Second 4: Builder Reveals

```
Builder obligations:
├── MUST reveal full ExecutionPayloadEnvelope
├── MUST provide all blob data
├── Payload MUST match committed block hash
└── Broadcasts via execution + blob P2P networks

If builder doesn't reveal:
├── Payment already debited (unconditional)
├── PTC will vote MISSING
├── Slot becomes "empty" (consensus exists, no execution)
└── Builder loses money — griefing has cost
```

### Slot N, Seconds 4-9: PTC Votes

```
Payload Timeliness Committee (512 randomly selected validators):
├── Check: did the builder reveal the payload?
├── Check: does the block hash match the commitment?
├── Do NOT need to execute the transactions
├── Vote: PRESENT, MISSING, or WITHHELD
└── Broadcast PayloadAttestations

PTC does NOT validate execution correctness — only timeliness.
```

### Slot N, Seconds 4-12: Execution Validation (8 Full Seconds)

```
All validators (including next proposer):
  4.0-5.0s   Receive execution payload + blob data
  5.0-7.0s   Execute ALL transactions
  7.0-9.0s   Verify state roots + merkle proofs
  9.0-11.0s  Process blob data (DAS, KZG proofs)
  11.0-12.0s Complete validation, prepare for next slot
  ──────── NO hard deadline — validation completes before slot N+1

  Next proposer specifically:
  ├── Has 6 seconds (seconds 6-12) to validate + build next block
  └── Today they have ~2-3 seconds

  If fraud detected:
  ├── Generate fraud proofs
  ├── Emergency broadcast to network
  └── Chain reorganization in next slot
```

### Timing Comparison — The Real Win

```
TODAY (PBS with MEV-Boost):
0s                           4s                          12s
├────── ALL validation ───────┤──── idle ──────────────────┤
        consensus              (wasted time)
        + execution
        + blobs
        ~3s of work, 4s deadline

ePBS:
0s            4s                                          12s
├── consensus ─┤───── execution + blobs ───────────────────┤
    simple       8 seconds of comfortable work
    ~2s work     no hard deadline
    4s deadline
    (easy)
```

---

## 6. The Payload Timeliness Committee (PTC)

The PTC is the key new mechanism that replaces relays.

### What it Does

- 512 validators are randomly selected each slot
- They vote on whether the builder revealed the payload on time
- Three possible votes: PRESENT (saw it), MISSING (didn't arrive), WITHHELD (builder explicitly withheld)
- Their votes are included in the NEXT slot's beacon block as `PayloadAttestations`

### Why 512 Validators?

Large enough to be statistically secure against manipulation, small enough to not add significant network overhead. Randomly selected from the full validator set — an attacker would need to control a huge fraction of all validators to corrupt the PTC.

### PTC Validates ALL Builder Bids

The PTC doesn't just validate the winning builder. It verifies that ALL builders who submitted bids provided honest commitments. The bid only declares the payment amount (`bid_amount`), not the MEV source. After reveal, the PTC compares the actual payload against the committed hash for all bidders.

This prevents builders from submitting fake high bids to win the auction and then delivering a worthless block.

### Conflict of Interest: Proposer on the PTC

If the proposer of slot N were also a PTC member for slot N, they'd have a conflict of interest — as proposer they want the builder to pay and the block to be included, but as PTC member they should vote objectively on timeliness. The specification assigns PTC members from the beacon committee, which is separate from the proposer selection.

> *Further reading: [Payload Timeliness Committee — potuz (ethresear.ch)](https://ethresear.ch/t/payload-timeliness-committee-ptc-an-epbs-design/16054)*

---

## 7. Three Possible Slot Outcomes

```
┌─────────────────────────────────────────────────────────────────────┐
│ FULL BLOCK                                                          │
│ Proposer published ✓  Builder revealed ✓  PTC voted PRESENT         │
│ → Complete block with execution, state advances                     │
│ → Builder pays proposer (already debited)                           │
│ → Builder receives block reward                                     │
├─────────────────────────────────────────────────────────────────────┤
│ EMPTY BLOCK                                                         │
│ Proposer published ✓  Builder did NOT reveal ✗  PTC voted MISSING   │
│ → Consensus block counts but no execution payload                   │
│ → Builder STILL pays proposer (unconditional payment)               │
│ → Builder loses payment + no block reward                           │
├─────────────────────────────────────────────────────────────────────┤
│ MISSED BLOCK                                                        │
│ Proposer did NOT publish ✗                                          │
│ → Empty slot, same as today's missed blocks                         │
│ → No payment to anyone                                              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Example: Complete ePBS Flow

```
Builder A: Finds 1 ETH MEV → Bids 0.7 ETH, commits hash 0xabc...
Builder B: Finds 0.8 ETH MEV → Bids 0.6 ETH, commits hash 0xdef...
Builder C: Finds 1.2 ETH MEV → Bids 0.9 ETH, commits hash 0x123...

SECOND 0:
  Proposer selects Builder C's bid (highest: 0.9 ETH)
  Includes SignedExecutionPayloadHeader in BeaconBlock
  Builder C's 0.9 ETH is debited immediately from on-chain balance
  Proposer receives 0.9 ETH immediately
  Broadcasts beacon block (~10KB, propagates in 50-100ms)

SECONDS 0-4:
  Validators receive small beacon block
  Validate consensus (easy, no execution)
  Attest to beacon block HEAD by second 4 (trivial)

SECOND 4:
  Builder C reveals ExecutionPayloadEnvelope
  Full block with all transactions, matching hash 0x123...
  Blob data broadcast in parallel

SECONDS 4-9:
  PTC (512 validators) checks: payload arrived, hash matches
  Votes PRESENT
  PayloadAttestations broadcast

SECONDS 4-12:
  All validators execute transactions, verify state, process blobs
  8 full seconds to do what today must be done in 3

SECOND 12:
  Slot N+1 begins
  Next proposer builds on the validated chain
  Cycle repeats
```

---

## 9. PBS vs ePBS — Side by Side

| | PBS (MEV-Boost) | ePBS (EIP-7732) |
|---|---|---|
| Where it lives | Off-chain middleware | In the protocol |
| Trust model | Trust relays | Trust-free (consensus enforced) |
| Builder staking | None | 1 ETH minimum, on-chain balance |
| Payment guarantee | Relay promises | Protocol enforces (unconditional) |
| Censorship resistance | Relay can censor | Builder commits directly |
| Relay needed | Yes (Flashbots etc.) | No |
| Penalty for misbehavior | None (off-chain) | Lose bid payment (on-chain) |
| Validation timing | ~3s (all in hot path) | 8s (execution decoupled) |
| Timing games | Proposer can delay | Proposer commits at second 0 |
| Scalability | Limited by 4s deadline | More time → bigger blocks possible |
| Slot outcomes | Block or missed | Full, empty, or missed |
| PTC | Doesn't exist | 512 validators verify timeliness |

---

## 10. Security Considerations

### Builder Griefing

- Builder commits, pays, then doesn't reveal → slot is empty
- **Cost:** builder loses the bid payment
- **Impact:** one empty slot (no worse than a missed block today)
- **Defense:** griefing costs money, not sustainable

### Timing Games (Solved)

- Today: proposer delays to capture more MEV → steals time from validators
- With ePBS: proposer must commit at second 0 (the bid is pre-built). Builder reveals at second 4. The timing game moves from the consensus hot path to the execution window where it doesn't affect attestation deadlines.

### PTC Corruption

- If >50% of PTC is malicious, they can lie about payload presence
- **Defense:** 512 members randomly selected each slot. Attacking requires controlling a massive fraction of all validators (~900,000 active validators on mainnet).

### Proposer Equivocation

- Proposer publishes two beacon blocks with different builder bids
- **Defense:** existing slashing rules — proposer loses 32 ETH

---
---

# Parte 2 — EIP-7732: La Especificación Técnica

---

## New Data Structures

### Changes to BeaconBlockBody

```
Today:                                ePBS:
──────                                ─────
attestations                          attestations
slashings                             slashings
deposits                              deposits
voluntary_exits                       voluntary_exits
sync_aggregate                        sync_aggregate
execution_payload       ← REMOVED     signed_execution_payload_header  ← NEW
                                      payload_attestations             ← NEW
```

### SignedExecutionPayloadHeader (Builder's Bid)

| Field | Type | Description |
|---|---|---|
| `parent_block_hash` | `Hash32` | Hash of the parent execution block |
| `parent_block_root` | `Root` | Root of the parent beacon state |
| `block_hash` | `Hash32` | Hash the builder commits to reveal |
| `gas_limit` | `uint64` | Gas limit of the execution block |
| `builder_index` | `ValidatorIndex` | Builder's index in Beacon Chain |
| `slot` | `Slot` | Target slot |
| `value` | `Gwei` | Payment to the proposer |
| `blob_kzg_commitments_root` | `Root` | Root of blob KZG commitments |

### ExecutionPayloadEnvelope (Builder's Reveal)

| Field | Type | Description |
|---|---|---|
| `execution_payload` | `ExecutionPayload` | Full block with all transactions |
| `builder_index` | `ValidatorIndex` | Who built it |
| `beacon_block_root` | `Root` | Reference to the consensus block |
| `blob_kzg_commitments` | `List[KZGCommitment]` | Blob commitments for DA |
| `state_root` | `Root` | State root after payload execution |

### PayloadAttestation (PTC Vote)

| Field | Type | Description |
|---|---|---|
| `validator_index` | `ValidatorIndex` | PTC member voting |
| `data.slot` | `Slot` | Slot being attested |
| `data.beacon_block_root` | `Root` | Block being attested |
| `payload_status` | `uint8` | 0=PRESENT, 1=MISSING, 2=WITHHELD |

---

## Changes to BeaconState

New fields added:

| Field | Type | Description |
|---|---|---|
| `latest_block_hash` | `Hash32` | Hash of the last revealed execution block |
| `latest_full_slot` | `Slot` | Last slot where a full payload was revealed |
| `latest_withdrawals_root` | `Root` | Root of latest withdrawals (now processed asynchronously) |

---

## Builders as Staked Entities

| Property | Validators | Builders |
|---|---|---|
| Minimum deposit | 32 ETH | 1 ETH |
| Role | Attest + propose | Build execution payloads |
| Penalty for misbehavior | Slashing (lose 1+ ETH of stake) | Lose bid payment from balance |
| On-chain balance | Yes | Yes (new!) |
| Registered in | Validator registry | Builder registry (new!) |
| Protocol-aware | Yes | Yes (new!) |

Builders have an on-chain balance on the Consensus Layer. When a proposer includes their bid, the `value` is debited immediately — before the builder reveals. This is the **unconditional payment** that makes the system trust-free.

---

## Slot Timing Constants

| Constant | Value | Description |
|---|---|---|
| `SECONDS_PER_SLOT` | 12 | Total slot duration |
| `INTERVALS_PER_SLOT` | 4 | Number of intervals per slot |
| Interval duration | 3s | 12 / 4 |
| Consensus attestation deadline | 4s (end of interval 1) | Same as today |
| Builder reveal deadline | 6s (end of interval 2) | New |
| PTC attestation deadline | 9s (end of interval 3) | New |
| Execution validation window | 6-12s (proposer) / 4-12s (validators) | New |

---

## Fork Choice Changes

The fork choice rule must now handle three states per slot:

| State | Condition | Chain advances? |
|---|---|---|
| Full | Beacon block + payload revealed + PTC majority PRESENT | Yes (consensus + execution) |
| Empty | Beacon block + no payload + PTC majority MISSING | Partially (consensus only) |
| Missed | No beacon block | No |

The fork choice uses PTC votes to determine whether a slot is full or empty. This is a fundamental change from today's binary (block/no-block) model.

---

## Withdrawal Processing Change

Today: withdrawals are included in the execution payload and processed synchronously.

With ePBS: withdrawals are decoupled because the execution payload arrives later than the consensus block. The `latest_withdrawals_root` in `BeaconState` tracks the asynchronous processing.

---

## Network Layer Changes

New P2P gossip topics:

| Topic | Content | When |
|---|---|---|
| `beacon_block` | BeaconBlock with builder commitment | Second 0 (interval 0) |
| `execution_payload` | ExecutionPayloadEnvelope | Second 4 (interval 2) |
| `payload_attestation` | PTC votes | Second 6-9 (interval 3) |

The `beacon_block` topic now carries a much smaller message (no execution payload), improving propagation speed.

---

## References

- [EIP-7732: Enshrined Proposer-Builder Separation](https://eips.ethereum.org/EIPS/eip-7732)
- [EIP-7773: Hardfork Meta — Glamsterdam](https://eips.ethereum.org/EIPS/eip-7773)
- [ePBS Implementation in Prysm — EPF Cohort 5](https://github.com/eth-protocol-fellows/cohort-five/blob/main/projects/epbs-implementation-in-prysm.md)
- [Builders and Relays in ePBS — Titan Builder](https://titanbuilder.substack.com/p/builders-and-relays-in-epbs)
- [The case for EIP-7732 — potuz](https://hackmd.io/@potuz/Bkcwd5hG1x)
- [Payload Timeliness Committee — potuz (ethresear.ch)](https://ethresear.ch/t/payload-timeliness-committee-ptc-an-epbs-design/16054)
- [SoK: Current State of Ethereum's Enshrined PBS](https://arxiv.org/html/2506.18189)
- [Potuz — Devconnect Bangkok talk on timing games](https://www.youtube.com/watch?v=w-VwYHq1FA4)
- [ePBS overview meet](https://www.youtube.com/watch?v=igR6IGmgH2g&list=PLJqWcTqh_zKHoz9dnQFGrWI_s1-8RwMhX)
