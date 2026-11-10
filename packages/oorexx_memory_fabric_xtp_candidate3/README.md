# ooRexx Memory Fabric XTP 0.1-candidate3

Candidate3 extends the executable dev10+dev25 transfer-planning and sender-capacity candidate2 with **read ingress authority**. New source and tests: `src/MemoryXtpReadIngress.cls`, `tests/test_read_ingress.rex`, `tests/run_ingress.sh`. The `memory_fabric_gopher_sphere_v0.2` doctrine is shipped under `sphere/`.

**Not production remote memory I/O:** the real XTP named listener has NOT yet been bound to the ingress gate; the test authenticator/ACL are fixtures. Actual page bytes, lease authorization, cross-process memory commit, authenticated multicast and live ED209 route qualification remain open.

See `docs/READ_INGRESS_CANDIDATE3.md` and the inherited `docs/XTP_ADMISSION_DEV25.md`. The preferred local machine shared/DMA block bag is unchanged.

Run in a pinned dependency environment: `MEMORY_FABRIC_DIR=/.../dev10 SERVICE_DESCRIPTORS_DIR=/.../dev1 REXX_BIN=/.../rexx tests/run_ingress.sh`. Fail-closed when any dependency is missing.
