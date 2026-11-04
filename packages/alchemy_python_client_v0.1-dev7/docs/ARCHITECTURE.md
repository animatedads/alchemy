# Alchemy for Python: service and object contracts

## Boundaries

**Service call:** Python virtual service -> Connect Selector adapter (when supplied) -> selected direct/JSON-RPC/Queue mechanism -> published Alchemy service authority -> published Alchemy service contract -> explicitly chosen local/Queue Fabric implementation. The Queue Fabric provider, when present, is **behind** the service, not a compulsory transport dependency for every client. Remote response = data/value or job receipt. RPC notifications have no acknowledgement.

**Live object call:** Python virtual class -> existing `_rexxpython_poc` retained Rexx object -> native bridge -> real ooRexx method, with native identity, lifetime, exceptions and concurrency. Not a JSON-RPC connection; not a remote serialization of a class or an inferred Python MRO.

**Local direct call:** Connect Selector may select a local invocation path where qualified; Python does not emulate ooRexx direct invocation or convert live foreign objects into service values. Standalone direct JSON-RPC remains possible with the independent `JsonRpcClient` and a qualified backend.

## Semantics

| Property | Python service | Python native object |
|---|---|---|
| Authority | Published service operation contract | Live ooRexx object/runtime |
| Address | JSON-RPC method | Exact native proxy method/message |
| Result | JSON value, or service-defined job receipt | Python projection of a real object/result |
| Identity | Service contract identity, **not** object identity | Native identity/generation retained by bridge |
| Mutation | Explicit operations, idempotency policy | Native method / live target semantics |
| Exceptions | RemoteError(code,message,data) | Existing native RexxError/bridge exceptions |
| Lifetimes | Per call or explicit durable job ID | Native retain/release/pin/revocation |
| Class hierarchy | Facade is Python API ergonomics only | Runtime-specific MRO/class authority retained |

Avoid auto failover to Queue Fabric after RPC timeouts, especially for mutations. Queue Fabric retained job status cannot be deduced from HTTP 200 or JSON-RPC notification send success. Expose explicit `submit`, `status`, `cancel` and receipt/result schemas when the service supports them, not generic promises about durability.

## Packaging/dependencies

- Python SDK version `0.1-dev2` does not use Python's language macrospace by default.
- JSON-RPC envelope conforms to existing `oorexx.json_rpc_fabric/0.1` protocol; stdio example exchange is a reference target.
- Virtual service contracts require explicit versions and published method inventory. Do not guess backend class names.
- Optional `Macrospace` caller must configure the existing `0.31.7` native module and correct ooRexx package roots; do not solve via `find | head -1` or unexpected `REXX_PATH` duplicates.
- Network server and Queue Fabric gateway adapter are distinct implementation and qualification milestones, not bundled features of this SDK.

## Follow-on acceptance

1. Cross-runtime Python <-> ooRexx stdio test using qualified ooRexx 5.3.0 and real `json.cls`.
2. Server-side published queue job handler using the accepted Queue Fabric provider API; includes admission/authorization, ID, stable status, outcome and cancellation; separate from immediate request semantics.
3. Production HTTPS endpoint composed with existing Socket Provider/authentication/gateway systems, bounded framing, protocol and Unicode conformance.
4. Live object qualified integration test against exact macrospace v0.31.7 with actual retained Rexx object, concurrency/lifetime/case-collision probes.
5. Instrumentation Mesh optional adapter with only safe correlation/outcome/byte metadata, no raw service arguments or secrets.


The service selector contract in this SDK is provisional: `docs/CONNECT_SELECTOR_INTEGRATION.md`. The authoritative accepted Connect Selector method signatures remain a dependency to resolve.
