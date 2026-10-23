# ooRexx Instrumentation Intentions v0.1-dev1

Read-only specialist intentions over `instrumentation.mesh/0.1`.

This package lets Management discover operational instrumentation without making
Management, Network Transport Intentions, or an LLM the owner of telemetry.
Instrumentation Mesh remains authoritative for current snapshots, bounded
history, metric series, stable `semantic_ref` identity and progress.

## Intentions

- `LIST_INSTRUMENTED_SERVICES`
- `GET_LATEST_HEALTH`
- `GET_LATEST_METRICS`
- `GET_METRIC_HISTORY`
- `GET_METRIC_SERIES`
- `GET_OPERATION_PROGRESS`
- `EXPLAIN_INSTRUMENTATION`

The surface is explicitly non-mutating. Instrumentation Mesh command envelopes
are not exposed by dev1. Recognition of a management request therefore cannot
become service-control authority.

## Object identity

`InstrumentationSemanticBindingRegistry` binds Mesh `semantic_ref` values to the
existing authoritative service/machine/domain objects. Relevance evidence keeps
those original object references rather than inventing telemetry-owned service
objects.

## Socket isolation telemetry bridge

`SocketTelemetryInstrumentationObserver` consumes the `record(event)` shape from
`socket.telemetry/0.1` and translates generic socket counters/gauges into an
`InstrumentationEmitter`. It intentionally retains only transport, scheme,
address-family, multicast and role dimensions. Payloads, logical service names,
endpoint/native identity and security profiles are not propagated into the Mesh.

## Authority split

- service/domain component: owns operational truth and execution;
- Socket Isolation Telemetry: observes the generic socket isolation boundary;
- Instrumentation Mesh: owns operational vocabulary, snapshots/history/series;
- Instrumentation Intentions: owns read-only semantic discovery of that evidence;
- Management Intention Discovery: discovers this specialist when a related object advertises it.
