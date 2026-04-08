


Pablo Andres Deymonnaz, [8 abr 2026, 4:17:47 p. m.]:
i want to migrate as much as possible from the total, but only if it's useful. tell me

⏺️ Looking at this more concretely — the question is whether rewriting parts in Lean 4 and extracting to running code (or
  using as verified reference) actually buys you something over the current Rust + spec-test approach.

  Worth formalizing in Lean 4

  These are pure, mathematical, and where a bug means consensus failure across the network:

  state_transition/src/lib.rs (~525 lines)
  - slot_is_justifiable_after — number theory, easy to get wrong with overflow edge cases
  - is_valid_vote — 6 conditions that gate all consensus progress
  - process_attestations — supermajority counting, justification trigger
  - try_finalize — finalization advancement, the hardest thing to test exhaustively because the state space (gap patterns
  between source/target) is combinatorial
  - serialize_justifications — deterministic ordering matters for cross-client consensus

  state_transition/src/justified_slots_ops.rs (~67 lines)
  - Window arithmetic with off-by-one risk on every operation
  - shift_window data loss would silently break finalization

  fork_choice/src/lib.rs (~82 lines)
  - compute_block_weights + compute_lmd_ghost_head
  - Termination, correct tie-breaking, weight monotonicity

  Total: ~674 lines of Rust. All pure functions, no I/O, no async. This is the entire consensus-critical core.

  NOT worth formalizing

  blockchain/src/store.rs — Orchestration glue. Calls the pure functions above, manages storage, handles tick scheduling.
  Bugs here are bad but are caught by integration tests and devnets. Formalizing it means modeling the storage trait,
  actor messages, time — huge effort, low marginal value over testing.

  blockchain/src/lib.rs (actor) — Concurrency, message dispatch, pending block queues. Same problem: you'd need to model
  async channels and timing. Better covered by the devnet runner.

  blockchain/src/key_manager.rs — Key loading/signing orchestration. Not consensus logic.

  common/crypto/ — Wraps leansig/leanVM. The crypto primitives themselves would need their own verification (separate
  project-scale effort). The wrapper is thin glue.

  common/types/ — SSZ struct definitions. These are data, not logic. Lean types would mirror them but there's nothing to
  prove.

  storage/ — RocksDB/in-memory backends. Infrastructure.

  net/ (p2p + rpc) — Networking, HTTP. No consensus semantics.

  bin/ethlambda/ — CLI, wiring. No logic.

  Verdict

  The only code worth formalizing is the ~674 lines across 3 files that form the pure consensus core. Everything else is
  either infrastructure, I/O-bound, or thin glue where testing is the right tool.

  The payoff is real though: those 674 lines are where a subtle bug (off-by-one in justifiable slot check, wrong
  finalization gap condition, incorrect weight accumulation) would cause a consensus split across all ethlambda nodes.
  Spec tests cover known scenarios; Lean proofs cover all of them.

  Want me to start building the Lean 4 formalization of these 3 files?

❯ nothing else?

⏺️ Good push. Let me look harder at what I might have dismissed too quickly.

⏺️ Explore(Find more pure logic in codebase)
  ⎿  Done (37 tool uses · 82.6k tokens · 1m 35s)
  (ctrl+o to expand)

⏺️ You're right, I was too narrow. Here's the full picture:

  Everything worth formalizing

  Consensus core (already identified)

  - State transition — state_transition/src/lib.rs (~525 lines): justification FSM, finalization, vote validation,
  supermajority threshold, attestation processing
  - Justified slots ops — state_transition/src/justified_slots_ops.rs (~67 lines): window arithmetic, relative indexing
  - Fork choice — fork_choice/src/lib.rs (~82 lines): LMD GHOST weight computation and head selection

  Pure logic in store.rs I dismissed too quickly

  ...Attestation validation (lines ~197–262): 5 topology/time rules before accepting gossip attestations. Different from
  is_valid_vote in the STF — this is the network-facing gate. Wrong here = corrupt fork choice.
  - Attestation target calculation (lines ~611–681): walkback from head, justifiability clamping, safe-target bound. Wrong
   here = validators vote for bad targets, split votes, finalization stalls.
  - Greedy proof selection (lines ~909–965): maximizes validator coverage per proof in block building. Wrong here = wasted
   block space, missed finalization.
  - Block building loop (lines ~967–1076): sorted attestation selection, iterative justification advancement. Must be
  deterministic — non-deterministic ordering = different blocks across nodes = consensus split.
  - Reorg detection (lines ~1187–1231): bounded ancestry walk. Less critical but the bounded walk termination is provable
  and the depth calculation matters for metrics correctness.

  Protocol-level pure functions

  - Varint encode/decode (req_resp/encoding.rs, lines ~70–105): 7-bit encoding with continuation flag. Divergence from
  other clients = protocol incompatibility. Classic roundtrip property: decode(encode(x)) == x.
  - Message ID computation (p2p/src/lib.rs, lines ~619–638): domain + topic + data hashing, truncated to 20 bytes. If this
   diverges between clients, gossipsub deduplication breaks — message storms.
  - Snappy decompression bomb check (gossipsub/encoding.rs, lines ~26–51): size-before-allocate guard. Provable bound on
  memory allocation.

  Crypto guards

  - Signature aggregation input validation (crypto/src/lib.rs, lines ~79–118): length mismatch, empty input, size bounds.
  Not the crypto itself, but the precondition checks that gate it.

  What this adds up to

  ┌─────────────────────────────────────────────────────────────────────────────┬───────┬─────────────────────────────┐
  │                                    Area                                     │ Lines │        Why formalize        │
  ├─────────────────────────────────────────────────────────────────────────────┼───────┼─────────────────────────────┤
  │ State transition + justified slots                                          │ ~592  │ Consensus safety            │
  ├─────────────────────────────────────────────────────────────────────────────┼───────┼─────────────────────────────┤
  │ Fork choice                                                                 │ ~82   │ Head selection correctness  │
  ├─────────────────────────────────────────────────────────────────────────────┼───────┼─────────────────────────────┤
  │ Store pure logic (attestation validation, target calc, proof selection,     │ ~300  │ Determinism, validator      │
  │ block building)                                                             │       │ safety                      │
  ├─────────────────────────────────────────────────────────────────────────────┼───────┼─────────────────────────────┤
  │ Varint codec                                                                │ ~35   │ Roundtrip correctness,      │
  │                                                                             │       │ interop                     │
  ├─────────────────────────────────────────────────────────────────────────────┼───────┼─────────────────────────────┤
  │ Message ID                                                                  │ ~20   │ Cross-client consistency    │
  ├─────────────────────────────────────────────────────────────────────────────┼───────┼─────────────────────────────┤
  │ Snappy bounds check                                                         │ ~25   │ DoS safety                  │
  ├─────────────────────────────────────────────────────────────────────────────┼───────┼─────────────────────────────┤
  │ Crypto preconditions                                                        │ ~40   │ Input validation            │
  └─────────────────────────────────────────────────────────────────────────────┴───────┴─────────────────────────────┘


Total: ~1,094 lines of pure logic across the codebase. Everything else is genuinely I/O, concurrency, or glue.

  The store.rs pieces are the ones I was wrong to skip — they're pure computations that happen to live in a file full of
  I/O code. They'd need to be extracted into pure functions to formalize cleanly, but the logic itself is self-contained.

  Want me to start?

✻ Worked fo
