# Status update: ConnectSelector 0.1-dev1 located and reviewed

The following document was written before `oorexx_connect_selector_v0.1-dev1.zip`
was found in the Library. Its provisional cautions remain valid only for the
older generic adapter. **See `NATIVE_CONNECT_SELECTOR.md` for the exact source-
reviewed native contract and the new `NativeConnectSelectorPort`.**

---

# Alchemy for Python -> Connect Selector integration (v0.1-dev2)

## Authority and scope

Connect Selector is being developed as the Alchemy authority for **choosing**
service invocation: direct local call, JSON-RPC Fabric, or Queue Fabric. This
Python SDK **must not** implement a competing resolver, duplicate selector
policies, turn every service request into an RPC call, or require Queue Fabric.

The accepted Connect Selector runtime package/signatures were NOT available
in the accessible Library at the time of this build. Thus `ConnectSelectorPort`
is a *Python SDK adapter shape*, not a claim that the ooRexx selector already
exports `request()` and `notify()` with these parameters. An integration
adapter must be authored after the exact versioned selector contract is
published and qualified. Do not wire a real backend by duck-typing guessed
native names.

## Two independent Python surfaces

1. **Service projection**: Python `ServiceContract` -> `ServiceProxy` or
   `VirtualServiceClassFactory` -> `SelectorClient` -> an injected application
   `ConnectSelectorPort` -> Connect Selector's actual published interface.
   That authority may select direct call, JSON-RPC or Queue Fabric according
   to the service operation's business semantics, caller authority, topology
   and resource policy. RPC remains a valid explicitly bound client option
   through `JsonRpcClient` with no selector dependency.
2. **Live object projection**: `Macrospace` -> existing native retained Rexx
   proxy -> ooRexx runtime. This path is not governed by a service selector;
   remote proxies do not become native objects simply because Python exposes
   method syntax.

## SDK intent contract (provisional, Python-side only)

`Invocation` carries:

- `service`, `api_version` (pinned published service identity)
- `operation` (name of the explicitly published service operation; currently
  stored as `Operation.rpc_method` for compatibility)
- `kind` (`request` or `notification`)
- `semantics` (`immediate` or `job`)
- `params` (list/dict/None)

`SelectorClient` delegates these to `ConnectSelectorPort.request(intent)` or
`.notify(intent)`. This is a *narrow injection seam*, not a selection engine,
wire protocol, Queue Fabric queue format, or object-identity protocol. The SDK
does not choose or expose an unqualified explicit transport override. The
backend must bind the actual authenticated caller identity and own routing,
permissions, timeouts, service availability and observations.

An ambiguous transport failure must never cause silent retry or switching
backends. No cross-connector at-most-once or exactly-once guarantee is inferred.
A notification return is not remote success. `JobServiceClient` requires an
actual service-confirmed accepted-job receipt; selecting Queue Fabric does not
by itself confirm durable admission, execution, or completion.

## Required real integration gates

1. Obtain Connect Selector's exact accepted source, API signature, provenance,
   version and tests. Replace SDK adapter calls with an implementation tied
   precisely to that contract; fail closed on unsupported API versions.
2. Verify service contracts are shared by local, RPC and Queue mechanisms;
   authority and operation schema cannot silently diverge across backends.
3. Exercise direct, JSON-RPC and Queue Fabric with actual ooRexx runtime and
   test correct function, receipt/status and error semantics.
4. Exercise denied routing, unknown contract, revoked service, no connector,
   duplicate idempotency, ambiguous network failure and prohibited failover.
5. Preserve optional direct `JsonRpcClient` for Python deployments that do not
   use Connect Selector and keep Macrospace independently loadable.
6. Make Instrumentation Mesh annotations correlation-safe; do not leak caller
   secrets, raw payloads or foreign object contents into telemetry.

## JSON-RPC Fabric v0.1-dev2 compatibility observation

Reviewed the Library package `oorexx_json_rpc_fabric_v0.1-dev2.zip`.
Its documented Socket Provider profile uses **8 ASCII uppercase hex bytes of
length followed by a byte-counted JSON document**, one connection per request;
it is **not HTTP framing** and is not covered by this SDK's `HttpTransport`.
The dev2 docs also say Queue Fabric is not yet attached to JSON-RPC Fabric and
its socket TLS/Unix profiles are not qualified. No live Python/ooRexx socket
interop is claimed here. The selector can route to a compatible RPC endpoint
when its own protocol and deployment are qualified.
