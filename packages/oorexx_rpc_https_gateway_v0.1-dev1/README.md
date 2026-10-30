# ooRexx RPC HTTPS JSON-RPC ingress v0.1-dev1

This is **source code**, not a proposal. Install as a *separate, optional application-layer binding* above the existing ooRexx HTTPS server. It implements a fail-closed JSON-RPC 2.0 POST route to the already-registered `RpcServiceDispatcher`. The RPC gateway does not own TLS, JSON parsing, request-object invocation, transport selection, queue durability or credential verification.

## Real integration wiring

```rexx
/* Application already registered its explicit object/method bindings. */
core = .RpcServiceRegistry~new
core~registerMethod('catalog','lookup',catalogObject,'fetch')
core~freeze
rpcDispatcher = .RpcServiceDispatcher~new(core)

/* platformAuthority is supplied by the platform identity layer, not by HTTP
 * request headers or caller-supplied JSON. See SECURITY.md. */
gateway = .RpcHttpsJsonGateway~new(core,rpcDispatcher,platformAuthority)
gateway~registry~registerOperation('catalog.lookup','catalog','lookup')
gateway~registry~freeze
server~route('POST','/rpc',gateway,'handle')
```

Add the four source roots to `REXX_PATH`, then `::requires 'https_server.cls'`, `::requires 'RpcServiceCore.cls'`, `::requires 'JsonRpcFabric.cls'` and `::requires 'RpcHttpsJsonGateway.cls'` in the application. Use HTTPS server v0.4.8, RPC Core dev1, JSON-RPC Fabric dev3; the module does not bundle or fork these dependencies.

`platformAuthority` must implement `authenticate(httpRequest,httpExchangeContext)` returning `.RpcHttpsIdentityAttestation~new(identityId,httpRequest)` after *actual* identity proof, or `.nil` on failure. It must separately implement `authorizeOperation(identityAttestation,service,operation,httpExchangeContext)` and return `.true` only on policy approval. Route registration validates service+operation against the frozen shared RPC registry, disallows CALLBACK operations, and is itself frozen before serving. Each JSON-RPC batch entry is independently authorized.

The HTTP response is 200 JSON-RPC, 204 notification, 401 unauthenticated, 403 untrusted transport, 405 wrong method, 413 oversized, 415 bad content type/encoding or 503 unsealed publication. A denied **method** has JSON-RPC fault `-32001` with no service invocation. HTTP semantics do not replace JSON-RPC response IDs, fault envelope or batch rules.

## Qualification truth

`python3 tests/verify_contract.py` checks source and fixture invariants only. To exercise actual ooRexx dispatch, set `REXX_PATH` to the four source directories and run `rexx tests/test_gateway.rex`. That suite is **not executed in the source packaging container** (no `rexx` executable installed there); the exact r13196, dev8 HTTPS runtime and dev22 LDAP deployment require target qualification. Do not claim deployment, certificate verification, or LDAP integration is operational from this source package alone.

Security and intended integration details: `docs/SECURITY.md` and `docs/ARCHITECTURE.md`.
