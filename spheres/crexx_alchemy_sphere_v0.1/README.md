# cREXX Alchemy sphere v0.1

Status: development / runtime qualification pending. Date: 2026-10-24.

## Scope
Bidirectional cREXX Alchemy language adapter via public RXPA; keep the Alchemy Foreign Object as the identity/lifetime authority, rather than introducing a second object system. cREXX values and RXPA handles are borrowed during a call, never persisted. The cREXX typed class and signatures remain authoritative for the language-facing contract.

## Pinned upstream
adesutherland/CREXX develop at 4468c7d75925cc158a568392f4abe97a59156df6 (beta-3 RXPA, RXBIN 007). Do not silently replace this pin with newer develop. RXPA host ABI is pre-release and requires rebuild-together qualification.

## Implementation ledger
- dev1: synthetic ref-counted native projection, typed factory, copy/finalize, alias-visible idempotent close, CALLMETHOD and nested RXPA entry. Unresolved host-services negotiation was fail-closed.
- dev2: RXPA_PLUGIN_SESSION_WITH_HOST and session-affine thread-local state; nested enter/leave restores previous session; legacy host fails closed without object_set_type.
- dev3: cREXX fixtures for native box/alias, nested A -> RXPA -> B -> RXPA -> C sentinels 111111/222222/333333, signal propagation and lifetime smoke. Build/compile/assemble/link/run script included. Source-contract checks passed in assistant environment; real pinned CREXX runtime qualification NOT performed.
- dev3 artifact SHA-256: 288b915412231009a248f2273c3d002b97ac8b1c6de1a136380a8cec38004013.

## Review gates
Correctness and failure recovery; object responsibility and alias ownership; reentrancy and lock order; exact resolvable dependency versions; native ownership/lifetime/thread/ABI; authority before effects; method-level maintainability; real interpreter and platform qualification. Inventory is not acceptance.

## Next actions
1. Compile dev3 with exact pinned CREXX header/build; fix compiler and fixture defects against upstream examples.
2. Exercise both VMs and optimized/unoptimized paths, signals, repeated nested callback, wrong-lifetime and teardown.
3. Add live/finalized/copy counters and verify balancing, including failed factory/type stamping.
4. Connect actual shared Alchemy Foreign Object projection only after RXPA qualification; no parallel identity registry.
5. Commit source files from dev3 package into this sphere and run CI. The package is available in the conversation artifact, not yet committed as executable source in this repository.

## Boundaries
No MP4/video work. No ooRexx interpreter changes. No private cREXX VM internals. No claims of runtime success without logs.
