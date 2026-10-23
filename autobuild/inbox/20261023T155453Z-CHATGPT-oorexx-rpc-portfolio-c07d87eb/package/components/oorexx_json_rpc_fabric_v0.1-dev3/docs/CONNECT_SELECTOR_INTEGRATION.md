# Connect Selector — verified integration (dev3)

This contract was verified against `oorexx_connect_selector_v0.1-dev1.zip`,
API `oorexx.connect_selector/0.1`, obtained from the Library.

## Integration ownership

**ConnectSelector** (external package) is the sole application routing authority:
`register(name, connector)`, `select(intent)`, `explain(intent)`,
`execute(intent,payload)`.

`ConnectIntent(operation,mode='request',requirement='immediate',preferred='auto',destination='',options=.nil)`
expresses the requested guarantees. `ConnectCallAdapter` wraps an injected
`request/notify` object; `ConnectQueueAdapter` wraps an independently injected
Queue Fabric manager. The RPC core never imports ConnectSelector, Queue Fabric,
or a JMS bridge. Do not implement a competing adapter or selection policy here.

```
::requires 'ConnectSelector.cls'
::requires 'JsonRpcFabric.cls'

registry=.JsonRpcMethodRegistry~new
registry~register('catalog.lookup', handler)
selector=.ConnectSelector~new
selector~register('DIRECT',.ConnectCallAdapter~new(.JsonRpcDirectConnector~new(registry),'DIRECT'))
selector~register('RPC',.ConnectCallAdapter~new(.JsonRpcClient~new(.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(registry))),'RPC'))
localReply=selector~execute(.ConnectIntent~new('catalog.lookup'), params)
rpcReply=selector~execute(.ConnectIntent~new('catalog.lookup','request','immediate','RPC'),params)
```

A real remote RPC option injects a `JsonRpcClient` with `JsonRpcSocketTransport`
where the Socket Provider is configured. In-process loopback is only a test or
embedded connector, not proof of network interoperability.

## Guarantees

- `REQUEST`: synchronous call/result, or explicit error; ambiguous response
  loss does not prove a remote mutation failed.
- `NOTIFY`: accepted/sent only, never a promise of handler completion or durable delivery.
- `ENQUEUE`: Queue Fabric, owned by Connect Selector's Queue adapter; no
  implicit translation from RPC `request` to `enqueue`.
- `DURABLE`: valid only for ENQUEUE; no JSON-RPC adapter is eligible.
- If a named connector is missing/unsuitable, fail closed. After dispatch
  starts, do not silently retry or switch transports.
- Endpoint identity, authentication, TLS, authorization, deadlines and
  resource limits are deployment responsibilities; TCP demo is loopback-only.

## Legacy transition

`JsonRpcConnectorRegistry` from dev1/dev2 has been moved from the core into
`src/JsonRpcLegacyConnectorRegistry.cls`. Explicitly `::requires` that file if
running old callers; it remains available in this development release but is
not exported as a current API. New code must use ConnectSelector instead.
The direct handler adapter remains available for compatibility with ConnectCallAdapter;
it does not decide routing.

## Dependency discipline

The tested ConnectSelector runtime is provided separately. For the interop
smoke test, set the exact `CONNECT_SELECTOR_ROOT` directory and use its
`src/ConnectSelector.cls`, verifying the path exists. Do not assume that a
published package version resolves from an arbitrary `REXX_PATH` entry.
This module still has no hard dependencies except the runtime `json.cls`.
