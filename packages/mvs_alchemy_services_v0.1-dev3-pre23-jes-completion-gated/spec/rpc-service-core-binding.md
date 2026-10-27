# MAS RPC Service Core alignment — PRE23

RpcServiceCore dev1 owns explicit service/object/operation publication and callback admission. PRE23 publishes MAS operations through `MasRpcServicePublisher` and deliberately relies on ConnectSelector dev6's `ConnectRpcDispatchAdapter` for local invocation. The duplicate PRE21 `MasRpcCoreConnector` is removed.

Authority split:

- MAS owns MVS-visible service semantics and host-side provider composition.
- RpcServiceCore owns the allowlisted `(service, operation)` registry and dispatch.
- ConnectSelector owns route admission and provider choice.
- JSON-RPC/SOAP/gRPC bindings own their envelopes and protocol-specific status/fault behavior.
- SerializationSelector owns representation/schema.

The current RPC portfolio records five optional SOAP/JSON shared-object dispatch checks through RpcServiceCore. This does not convert MAS into a SOAP/JSON/gRPC server and does not qualify production network authentication, authorization, callback scheduling/backpressure or every gRPC streaming mode.
