# ooRexx Socket/Event Runtime Adapter v0.1-dev1

This package connects the common SocketProvider readiness contract to Event Runtime without making either transport-specific.

It intentionally does **not** add fd polling to Event Runtime. Event Runtime v0.1-dev1 owns registration and typed dispatch; native/provider code owns I/O. A readiness scheduler may watch the descriptor exposed by a SocketProvider listener and call `SocketListenerEventAdapter~drainReady` when readable. The adapter then consumes `tryAccept()` nonblocking and emits `SOCKET.ACCEPTED` through a normal `EventSource`.

The accepted socket object is carried as the Event data object. It is not flattened into bytes or a generic map.

## Ownership and concurrency

- SocketProvider owns listener/connection/address semantics.
- Provider owns native descriptor and nonblocking readiness drain.
- Event Runtime owns subscriptions/triggers and dispatch.
- This adapter owns only the projection from a ready SocketProvider listener into typed Event Runtime events.
- Closing/removing an adapter does not close the listener or leave multicast membership.
- One mutable listener/membership descriptor has **one active readiness consumer**. Use one `SocketDescriptorSet` as the registration authority for a scheduler. Do not concurrently drain the same listener from multiple adapters/threads.
- Simultaneous memberships use distinct adapters/source IDs and therefore distinct EventSource sequence spaces.
- Provider calls and Event Runtime/application callbacks execute after the adapter/registry object guard is released.

## Multiple descriptors

`SocketDescriptorSet` registers multiple adapters by descriptor and can dispatch one known-ready descriptor without polling the others. Duplicate descriptors are refused within the set. It deliberately does not choose/select/poll descriptors; that remains the scheduler's job.

## Qualified dependency floor

- ooRexx SocketProvider v0.1-dev16, SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`
- ooRexx Event Runtime v0.1-dev1, published source package `packages/oorexx_event_runtime_v0.1-dev1`
- NORM v0.1-dev3 is the first provider qualification target, not an API dependency.

## Validation state

Architecture and ownership were independently reviewed on Rasen Falcon by CODEX-PC; existing Event Runtime and NORM contract suites passed in that review. The new adapter package itself has **not yet been executed under r13196**, because the review checkout did not contain the candidate branch and autobuilder is currently stopped. `VALIDATION.md` records that distinction. Source publication does not upgrade NORM dev3's existing live qualification claims.
