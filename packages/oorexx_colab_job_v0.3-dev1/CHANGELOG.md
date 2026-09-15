# Changelog

## 0.3-dev1

- Reject unsafe Colab remote input/output paths before any session allocation.
- Generated workload driver emits a SHA-256/size receipt for declared outputs.
- Runner retrieves and validates the receipt before output promotion.
- Local downloads are rehashed with ooRexx Crypto and byte lengths are verified.
- Added `ColabArtifactReceipt` and `ColabJobResult~artifacts`.
- Required missing receipts and size/hash mismatches fail closed.
- Preserved v0.2 Secret Broker, cleanup and allocator semantics.


## 0.2

- Added `ColabSecretBinding(environmentName, reference)` and `ColabJobSpec~secretBindings`.
- Added optional Secret Broker injection to `ColabJobRunner`; secret-bound jobs fail closed before allocation without a broker or resolvable reference.
- Added private 0700/0600 local materialisation, ordinal remote secret staging, driver-side environment injection and immediate remote unlink.
- Obvious credential-shaped environment names, including `HF_TOKEN`, are forbidden as ordinary literal environment values.
- Added result/evidence/exported-log redaction while secret leases are active; leases are retired on every finalisation path.
- Secret directory cleanup is mandatory even when the Colab session itself is explicitly retained.
- Hardened local command stdout/stderr capture under a 0700 private directory.
- Fixed ordinary environment iteration to use Directory indexes rather than values.
- Preserved v0.1.1 resource-thrift, lifecycle and Job-to-Node Allocator v0.6 behavior.
