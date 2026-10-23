# Alchemy RPC Portfolio — source publication v0.1-dev1

This is a **source recovery and integration submission**, not a claim that all four RPC families gained new runtime functionality. It transfers the current accepted source sets to GitHub Autobuild without modifying the protocol-neutral dispatch semantics or bypassing acceptance.

## Components

- RPC Service Core `v0.1-dev1`: allowlisted target-object + method registrations and callback dispatch.
- JSON-RPC Fabric `v0.1-dev3`: JSON-RPC 2.0, independent transport/channel adapters.
- SOAP RPC Binding `v0.1-dev2`: SOAP 1.1/1.2 XML envelopes and faults, separate native libxml2 adapter.
- gRPC RPC Binding `v0.1-dev3`: schema-bound protobuf, unary HTTP/2 and outbound server-streaming callback client.

`SOURCE_PROVENANCE.json` contains SHA-256 for every original archive and every source file copied from it. Published sources omit architecture-dependent prebuilt shared libraries (`.so`), and original distribution manifests whose checksums would no longer describe this new source-only tree. Those binaries must be rebuilt for the actual target runtime. Upstream component version labels have **not** been increased.

## Authority boundaries

1. **Connect Selector** chooses the permitted route (direct, RPC, queue), and no protocol binder silently retries or fails over.
2. **Serialisation Selector** supplies the registered codec and schema; gRPC does not implement protobuf.
3. **RPC Service Core** explicitly maps public service + operation names to pre-registered object methods and owns inbound dispatch.
4. **JSON-RPC / SOAP / gRPC** own distinct wire formats and protocol-specific status/fault mappings, not service reflection.
5. Callback operations must handle partial message delivery, final failure, cancellation and deadlines; an earlier `onNext` is not final success.

## Qualification

- `python3 tests/verify.py` checks all component hashes, source boundaries, requirements, and ensures no compiled artifact is promoted.
- `sh tests/native_stream.sh` recompiles the native gRPC HTTP/2 transport fixture and exercises its 15 independent streaming tests (requires C++17, libcurl+HTTP/2, Python hyper-h2).
- `sh tests/runtime_contracts.sh` executes ooRexx RPC Core / SOAP / JSON-RPC / gRPC suites with an explicitly selected interpreter, Connect Selector, Serialisation Selector, and native build prerequisites. It refuses to label missing dependencies as successful tests.

**Not yet qualified here:** native ooRexx streaming callbacks on the target r13196 debug runtime (the installer is not currently accessible); inbound HTTP/2 gRPC service host, client/bidirectional streaming, and production TLS deployment. Native C++ fixture verification is not equivalent to end-to-end ooRexx qualification.

The target GitHub repository uses `alchemy.autobuild.integration/0.2`. This submission belongs on an immutable `autobuild-submit/...` branch with a two-commit `package` then `ready.json` transfer. Receiver acceptance—not submission—controls promotion to `main`.
