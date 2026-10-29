# Dev6 — Native projection and connection authority

Date: 2026-10-27. This is a Python adapter, not a new ooRexx or RPC service implementation.

## Actual source contracts

1. `oorexx_connect_selector_v0.1-dev7.zip` / `oorexx.connect_selector/0.1`: `ConnectIntent~new(operation,mode,requirement,preferred,destination,options)` and `ConnectResult(ok,provider,accepted,completed,durable,value,code,detail)`. Dev7 adds exception-safe JMS uncertainty dispositions. No auto-fallback after effect-uncertain calls.
2. `oorexx_rpc_portfolio_v0.1-dev1.zip` aggregates registered RPC Service Core, JSON-RPC and gRPC bindings. The Python client must not bypass method allowlists or select serializers by inference.
3. Independent accepted Python Macrospace 0.31.7 projects retained ooRexx objects with `.send`; bridge owns method resolution, condition translation, identity, re-entry and lifetime. The Oct 16 `alchemy_oorexxpython_upstream_adapter_v0.2` targets a *different* upstream package and has no qualified equivalence.

All source archive SHA-256 values are in SOURCE_REVIEW.json. Review is not cross-runtime acceptance.

## Construction sketch — requires externally qualified native objects

```python
from alchemy_python import (RexxSelectorProjection, NativeConnectSelectorPort,
                           rexx_result_field, rexx_logical)
# native_selector_object: retained existing RexxObject projection; NEVER JSON
# native_intent_factory: injected, real native ConnectIntent constructor;
# host_encode_options must build a genuine Rexx Directory/Table, not dict
port = NativeConnectSelectorPort(
    RexxSelectorProjection(native_selector_object), native_intent_factory,
    read_field=rexx_result_field, decode_bool=rexx_logical,
    encode_options=host_encode_options, encode_payload=host_encode_payload,
    default_destination='authorized-service-endpoint')
```

ConnectIntent options MUST be actual ooRexx Directory or Table, per ConnectSelector.cls; the default Python identity codec is for test doubles only. Caller must qualify native boolean and object conversions before production use. Explicit destination does not grant route policy permission.

## Acceptance work still open

- Compile and load exact independent Macrospace binary against ooRexx/Python ABI and verify real `send()` with `ConnectSelector`, real six-argument `ConnectIntent` construction and Directory/Table options, all eight native getters and exception/uncertainty cases.
- Run native registered DirectCall + RPC + Queue Fabric with the same service operation, enforce explicit route policies and denied provider/destination cases; no auto-retry after ambiguous acceptance.
- Test separate job service receipts versus queue ENQUEUE. Do not conflate accepted/durable/completed.
- Test real network JSON-RPC hex8/TCP, gRPC unary/stream against ooRexx, TLS/auth, cancellation, and no unauthorized method access.
- Qualify optional JMS broker directions with stable identity, dead-letter, redelivery, explicit acknowledgements and uncertain send/ack paths; RTO2 with actual epoch/lease/fence evidence.
- Verify accepted source provenance and publish full navigable source to GitHub; do not treat GitHub patch subtrees as complete source imports when upstream projects themselves say otherwise.
