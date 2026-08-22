# Source provenance

The v0.1 source root was chosen by hashing every `src/crypto.cls` in the user-supplied `oorexx-libs(20260822-023213).zip` roll-up.

Three copies existed:

- `oorexx_queue_fabric_v0.8.1/src/crypto.cls`
- `runtime_registry_v0.11/src/crypto.cls`
- `oorexx_work_load_units_v0.2/src/crypto.cls`

All three were byte-identical with SHA-256:

`b56e5e3d7547abc1202d200bfbb79b3e9df6523173cb95a35e47b0ad10c3e395`

That exact byte stream was used as the base. v0.1 then adds the shared MAC primitives and the tested ChaCha20 conformance repair described in `CHANGELOG.md`. No merge between divergent crypto implementations was required.
