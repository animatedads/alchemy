# alchemy_rto_core v0.1-dev4: RTO2's core, with the receiver's checks

Architecture: Tom Dyer. Coding: the dev3 core came from `rexxos_rto2_grid_v0.1-dev15`
(`rto2/`); the dev4 changes are by Claude (Opus 5.5), 24 Nov 2026. Crypto:
`oorexx_crypto_v0.8.3` (SHA-512, HMAC-SHA-512, Ed25519, plain ooRexx).

## Why

RTO2's core sends **state, never code**: the receiver supplies an object of its own
installed class, reconstruction is inert, and bind and activate are separate steps.
That is the right design (the older `oorexx_rto` ships method source and runs it on the
receiver; see the note at the end).

A two-process probe of dev3 showed `AlchemyRTO~reconstruct` checked nothing before it
called `rtoImportState`:

| attack | dev3 | dev4 |
|---|---|---|
| envelope for C1:MI-A applied to OTHER:MI-Z | accepted | `RTO_WRONG_TARGET` |
| schema `not.rto/9` | accepted | `RTO_SCHEMA` |
| state changed after capture | accepted | `RTO_DIGEST` |
| an older capture over newer committed state | accepted | `RTO_STALE` |
| state changed and digest recomputed | (no digest) | `RTO_SEAL` when a verifier is given |
| lifecycle after reconstruct | not recorded | `RECONSTRUCTED`, then `BOUND`, `ACTIVE` |

## What changed

- `capture(obj, sequence, committedSequence [, sealer])` adds a SHA-512 digest over a
  canonical form of the envelope (sorted keys, length-prefixed strings) and, with a
  sealer, a seal over that digest.
- `reconstruct(result, target [, verifier])` runs `admit` first: schema, sequences,
  root = `target~rtoIdentity`, not older than the target's `committedSequence`, digest,
  and (with a verifier) the seal.  Each failure raises SYNTAX 93.900 whose text starts
  with its code.  Nothing reaches the target unless every check passes.
- Wire form: `envelope~toWire` (JSON) and `.AlchemyRTOEnvelope~fromWire(text)`;
  `.AlchemyRTOCaptureResult~of(envelope)`.
- Sealers and verifiers:
  - `AlchemyRTOHmacSealer(keyId, keyHex)`: a shared key in one trust domain; it both
    seals and verifies.
  - `AlchemyRTOEd25519Sealer(keyId, privateHex)` on the sender and
    `AlchemyRTOEd25519Verifier~new~trustKey(keyId, publicHex)` on the receiver: the
    receiver can check a seal and never make one.
- `AlchemyClusteredApp~rtoLifecycle` records its state; `rtoLifecycleState` reads it.

A digest without a verifier detects damage, not an attacker (one who recomputes it gets
through; the tests say so).  Between nodes, pass a verifier.

Cost, ooRexx 5.2 in plain Rexx: SHA-512 is about 0.3 ms per byte for large states,
HMAC about 0.15 s, Ed25519 about 1 s per sign or verify.  The seal covers the 128-character
digest, so its cost does not grow with the state.

## Tests

```
bash tests/run_tests.sh
```
`send.rex` captures in one process; `recv.rex` reconstructs in another and tries every
attack above.  20 checks; pass on ooRexx 5.2.0 and 5.3.0.

## Not changed

`RTO2CountJob.cls` (the qualification job) is copied unchanged.  The grid's RPC, XTP and
queue paths are not touched or tested here.

## The older oorexx_rto

`packages/oorexx_rto` (RTOSerializer, RTOSecurityManager, wire label `oorexx.rto.v2`)
rebuilds classes from method source sent by the sender.  Probed on 24 Nov: shipped
`init`, leaf and superclass methods all ran `address system` on the receiver with
RTOSecurityManager supplied; no digest is checked.  Do not point it at an MU.  NotNotes
uses RTOSecurityManager and needs its own check.
