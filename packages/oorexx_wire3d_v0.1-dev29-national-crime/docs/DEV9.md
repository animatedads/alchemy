# Wire3D v0.1-dev9 — ordered live semantic delivery

Dev9 hardens the existing Queue Fabric / Wire UI gateway seam. Queue Fabric's browser transport can deliver another message while an asynchronous semantic handler is still completing, so Wire3D now serialises semantic application explicitly.

## Invariants

- Snapshot/delta application is strictly ordered in one client.
- ACK occurs only after successful semantic application.
- A failed delivery is NACKed and does not poison the subsequent receive chain.
- `deliverySequence`, when supplied by the existing gateway, must increase monotonically.
- Deltas are fenced by both scene identity and revision.
- A snapshot is the explicit resynchronisation boundary and may replace/switch the active scene.
- Browser delivery still conveys no domain authority.

This is intentionally semantic ordering in Wire3D, not a second queue protocol. Queue Fabric and its Web Gateway retain transport, claim and delivery ownership.
