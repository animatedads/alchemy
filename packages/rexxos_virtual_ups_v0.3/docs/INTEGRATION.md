# Integration boundaries and qualification gates

## Intentions and service semantics

A caller should be able to ask "Is virtual mains present?", "How much simulated battery time remains?", "Advance the simulation by 30 seconds", or "Inject a research-only outage" without choosing the transport. The semantic implementation remains independently usable. The initial Python implementation is a **reference and test oracle**, not a substitute for a future independently deployable ooRexx native service.

Transport choices when the current Connect Selector is available and its actual interface has been verified:
- direct local object dispatch (no mandatory Queue Fabric dependency);
- standalone JSON-RPC 2.0 using the supplied `ups.*` operation names;
- Queue Fabric when durable work/status semantics are useful.

No Connect Selector API name or runtime transport adapter is claimed here. The stdio RPC proof does not imply a deployed RPC server. SOAP and gRPC must go through the shared service dispatcher/serialization selection when the owning RPC stack qualifies those bindings.

## Logical vs real time

The model owns `logical_seconds` (monotonic simulation time), unaffected by wall-clock changes, DST or remote hosts. The Single Time Service can later supply independently attested UTC correlation for lab observations **without changing logical tick semantics**. A correlation envelope might contain `{source: 'single-time-service', observed_at_utc: ... , simulation_tick: ...}` after the Time Service contract is qualified; no UTC claims are generated in this version.

## Instrumentation and evidence

`virtual.ups.event/1` records stable simulated transitions, with an `at` expressed only as the logical second and explicit `synthetic=true`. An adapter can map these into the *real* Instrumentation Mesh observation schema after verifying the registered `InstrumentationRegistry` / publisher interface and policy. Do not fabricate `instrumentation.event/1` source fields or publish runtime identities beyond their approved privacy/authority scope. Observing an event must not authorize a host shutdown.

Current implementation intentionally writes its own local deterministic SHA-256 journal only. No network emission, alerts or automatic callbacks occur.

## KL10 / guest bridge

1. Establish the guest's actual hardware/monitor power-fail signaling contract by reading authoritative DEC hardware manuals, TOPS-20 monitor source, or traceable KLH10 device code. A mail-subsystem `MX` log line is **not** a power-status read.
2. Build a distinct adapter translating `virtual.ups.signals/1` into the verified guest interrupt/register/console contract. Never modify the historical guest disk or wire signals directly into the real ED209 power domain.
3. Confirm expected guest behavior on a cold-copied KLH10 machine instance, with input/output evidence and no network access to the production management plane.
4. If a genuine outage shutdown path is eventually desired, it must be a separately authorized policy action, with durable consent, safe rollback and independent emergency access. This deliverable implements **no such path**.

## Storage / checkpoint

The journal is an append-only sequence of inputs plus replay-verified state/events. `snapshot` is an exported checkpoint assertion bound to a journal head, not a restore command. Future portability should carry the journal + checkpoint as named logical artifacts in Storage Fabric and couple its simulation tick to Migratable Job's freeze/restore boundary; do not put machine-local absolute paths into work definitions.

## Security / test limits

Use a dedicated private lab path and account. File mode 0600 and a private new directory are used. Do not serve the JSON-RPC stdio process from an unauthenticated web, TCP, XTP or Queue Fabric edge; it has no remote authority layer. In particular, `--simulate` is a local lab acknowledgement, **not** the RexxOS production authorisation system. A connector must supply proper caller identity, authorisation and policy checks before exposing mutations to others.
