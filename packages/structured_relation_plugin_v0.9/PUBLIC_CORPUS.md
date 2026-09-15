# Public corpus anchors — Bitcoin Core

Snapshot timestamp: **2026-08-20 12:51 Europe/London**.
Semantic blob verification refreshed: **2026-08-20 13:52 Europe/London**.
Value-flow verification added: **2026-08-20 14:09 Europe/London**.
Runtime Git-blob byte verification added in v0.8: **2026-08-20**.

Repository: `bitcoin/bitcoin`.

## PR #35688 — crypto: accept empty HMAC keys

- PR: `https://github.com/bitcoin/bitcoin/pull/35688`
- Base SHA: `81405fc7abbd1889f3978b8924e7acbe12b3403b`
- Head SHA: `dc67c4cc39062875c6571f9188abc83cfc6e6b90`
- Author: `l0rinc`
- State at snapshot: open, non-draft
- Base file: `src/crypto/hmac_sha256.cpp`
- Base blob SHA: `0796bbeb3271a210ed7ed5d85a82fc76939db61a`
- Head file: `src/crypto/hmac_sha256.cpp` in `l0rinc/bitcoin`
- Head blob SHA: `d9e16f361107c6d66f32ad8050c658d3b01f9241`
- v0.8 runtime verification: the exact embedded base/head byte strings are hashed with `git hash-object`; both computed object IDs match the retained blob SHAs before the semantic objects are admitted as `GIT_BLOB_BOUND`.
- Review discussion: `discussion_r3550259003`
- Review summary: `pullrequestreview-4661456996`

The retained semantic source shows the base `memcpy(rkey, key, keylen)` and successor
`std::copy(key, key + keylen, rkey)` under the same `if (keylen <= 64)` guard. v0.7 additionally derives
`keylen` as the effective length subject for both operations and links that exact value to the 64-byte `rkey`
extent before crediting the guard. The corpus separately keeps
(1) the author claim about empty-input UBSan behavior, (2) the reviewer argument for defined empty-range
semantics, and (3) the reviewer criticism that the earlier rationale mixed unrelated evidence.

## PR #31868 — [IBD] specialize block serialization

- PR: `https://github.com/bitcoin/bitcoin/pull/31868`
- Base SHA: `baa554f7089d8ce8ecb11e78ae097c10bfa85d8d`
- Head SHA: `41ef25fcbaf2c3d14f901ef3f56311a2d396a3d8`
- Author: `l0rinc`
- State at snapshot: open, draft, `Needs rebase`

Reported microbenchmark/IBD measurements remain separate from the author's explicit remeasurement and
simplification caveat.

## PR #34083 — vectorized ChaCha20

- PR: `https://github.com/bitcoin/bitcoin/pull/34083`
- Base SHA: `13891a8a685d255cb13dd5018e3d5ccc18b07c34`
- Head SHA: `5155730de55bdbada706ffaa39a827de7370efb8`
- Author: `theuni`
- State at snapshot: open, draft
- Observed public label: `CI failed`

Performance intent, local speedup claims, compiler-built-in design choice, generated assembly/IR evidence,
latency uncertainty and observed CI state remain independent evidence objects.
