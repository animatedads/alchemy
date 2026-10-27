# Wire Application Deployment Candidate 3 (ooRexx r13196)

This is an additive native update to Candidate 2, not a replacement server. Use Candidate 2's version-pinned HTTPS Server v0.5, Wire UI Server v0.17.1, Web Gateway v0.2, and Deployment v0.1-dev3 overlays. Candidate 3 adds an admission journal backed by Queue Fabric QueueDurableStore STRICT journal replay, and replaces the old WireDeploymentQueueIngress class.

Native qualification 2026-10-27: 8/8 test programs and 7/7 rexxc checks passed in the complete ZIP artifact. Persistent Queue Fabric restart/replay, requestId deduplication, divergent digest conflict, strict five-field validation, and evidence-bearing completion are tested. The signed WAPP verifier and live HTTPS/WebSocket/application startup remain **unqualified**.

Canonical ingress envelope: wire.deployment.command/0.1; fields contract, requestId, artifactDigest (sha256 + 64 lowercase hex), artifactRef (storage-fabric://), target. Do not silently accept the older wire.application.deploy/0.1 design envelope. The intention producer needs explicit version conversion and authenticated approval.

A requestId identifies the logical deployment; Queue Fabric packageId identifies a delivery. One accepted request remains pending across process restarts until an external worker records terminal status with evidence. The journal does not make an unverified package executable. Single active writer per journal root is mandatory; no distributed lease/fencing is implemented here. QueueDurableStore closes on append; true physical power-loss/fsync safety remains unproven.

Full qualified delivery ZIP SHA256: 8aa156951a6f2326ef7c8df944a04a3afcb9929ce1f89d5ce347ba4fed87dbe9. Exact tests are in the ZIP; the repository source snapshot is the native admission adapter and contract.
