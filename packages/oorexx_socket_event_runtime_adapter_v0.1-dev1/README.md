# ooRexx Socket/Event Runtime Adapter v0.1-dev1

This package connects the common SocketProvider readiness contract to Event Runtime without making either transport-specific.

It intentionally does **not** add fd polling to Event Runtime. Event Runtime v0.1-dev1 owns registration and typed dispatch; native/provider code owns I/O. A readiness scheduler may watch the descriptor exposed by a SocketProvider listener and call `SocketListenerEventAdapter~drainReady` when readable. The adapter then consumes `tryAccept()` nonblocking and emits `SOCKET.ACCEPTED` through a normal `EventSource`.

The accepted socket object is carried as the Event data object. It is not flattened into bytes or a generic map.

## Ownership

- SocketProvider owns listener/connection/address semantics.
- Provider owns native descriptor and nonblocking readiness drain.
- Event Runtime owns subscriptions/triggers and dispatch.
- This adapter owns only the projection from a ready SocketProvider listener into typed Event Runtime events.
- Closing/removing an adapter does not close the listener or leave multicast membership.

## Multiple descriptors

`SocketDescriptorSet` registers multiple adapters by descriptor and can dispatch one known-ready descriptor without polling the others. It deliberately does not choose/select/poll descriptors; that remains the scheduler's job.

## Qualified dependency floor

- ooRexx SocketProvider v0.1-dev16, SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`
- ooRexx Event Runtime v0.1-dev1, published source package `packages/oorexx_event_runtime_v0.1-dev1`
- NORM v0.1-dev3 is the first provider qualification target, not an API dependency.
