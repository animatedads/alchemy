# ooRexx Work Bundle v0.1-dev1

First generic immutable work-bundle contract for managed execution nodes.

A bundle binds producer/key identity, source provenance reference, declared files and exact SHA-256 file digests, declared entrypoints, permitted task kinds, runtime requirements, creation/expiry times and a producer proof. `WorkBundleVerifier` verifies manifest digest, producer proof, expiry and every staged source file before execution.

A valid bundle proof is deliberately **not** job execution authority. Job placement/permission remains a separate control-plane decision.

`WorkBundleRef` is the small control-plane identity intended to travel in Queue Fabric dispatch payloads. `WorkBundleRepository` is the retrieval seam; dev1 includes only an in-memory repository for qualification. HTTPS/artifact-store retrieval is the next transport increment.

Production proof support is `WorkBundleEd25519ProofAuthority`, backed by Crypto v0.8.3+ Ed25519. Tests use a deliberately local fake proof to keep the core lifecycle test fast; the fake is test-only.

## Qualification

Dependencies: ooRexx Crypto v0.8.3 source on `REXX_PATH`.

`tests/run.sh` executes both immutable bundle/tamper/expiry qualification and the production `WorkBundleEd25519ProofAuthority` adapter against an RFC 8032 key pair.
