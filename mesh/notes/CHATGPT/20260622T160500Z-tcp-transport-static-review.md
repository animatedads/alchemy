# TCP transport static review for CLAUDE-ALCHEMY-1

## Inventory

`alchemy_mesh_debug(9).zip` does not contain `data/TcpTransport.cls`.

`alchemy_new_providers_package(69).zip` does contain:

- `data/TcpTransport.cls`
- `practice/transport_test.rex`
- `practice/object1.rex`
- `practice/object2.rex`

The TCP peer demos use one listener per object and one client endpoint to the peer:

- `object1`: listens on `0.0.0.0:9340`, sends to `127.0.0.1:9341`
- `object2`: listens on `0.0.0.0:9341`, sends to `127.0.0.1:9340`

## Static result

`fop oorexx` reports zero errors and zero warnings for:

- `data/TcpTransport.cls`
- `practice/object1.rex`
- `practice/object2.rex`
- `practice/transport_test.rex`

No live ooRexx/socket test was run here because this sandbox does not expose a Rexx runtime.

## High-confidence notes

The TCP transport is architecturally cleaner than trying to force named queues into a cross-machine role:

- server role owns an inbox `.Queue` and accept loop;
- client role sends line-framed `EVENT|{json}` tokens;
- this avoids `.Queue` versus `.RexxQueue` confusion for network traffic;
- the object1/object2 demos have the right peer shape: each object has its own listener and its own outbound endpoint.

## Risks to verify live

### 1. Missing dependency in reduced packages

`TcpTransport.cls` requires:

```rexx
::requires "socket.cls"
::requires "data/AlchemyTransport.cls"
::requires "util/KeepAlive.cls"
```

The reduced packages inspected here do not include `util/KeepAlive.cls`. If the live Alchemy tree already has it, this is fine. If a reduced test package is used, include `util/KeepAlive.cls` or replace the keepalive call in the test build.

### 2. Accept-loop condition labels

`acceptLoop` uses a condition handler label that ends with `iterate` after a `signal`. This is worth live verification because `SIGNAL` may unwind active control structures. If this trips, split accept into a helper method that returns `.nil` on failure instead of signalling to a label that performs `iterate`.

### 3. Client handler message lifetime

The accept loop starts per-client handler messages but does not keep a reference. If handlers disappear early on the live runtime, remember those `.Message` objects through `AlchemyKeepAlive` until they return.

### 4. Listen return code

`openServer` checks bind but does not check `listenRc`. Add a check if `socket.cls` returns numeric status for `listen`.

## Suggested live ladder

1. Run the existing transport smoke:

```sh
rexx practice/transport_test.rex
```

Expected TCP section: server starts on `127.0.0.1:29331`, client sends one `TEST/TCP` event, server drains at least one message.

2. Run TCP peer ping-pong in two terminals:

```sh
# terminal 1
rexx practice/object1.rex 5 TCP

# terminal 2
rexx practice/object2.rex 5 TCP
```

Expected object1 result: `PASS: 5/5`, `FAIL: 0/5`.

3. Only after that, wire TCP into MeshNode topology. Do not debug TCP and mesh routing/concurrency at the same time.

## Short recommendation

Yes, the TCP transport exists in provider package 69 and is statically clean. It is not present in debug package 9. Before changing mesh code, live-test `transport_test.rex` and `object1/object2 TCP` as isolated transport checks. If TCP fails, first inspect `util/KeepAlive.cls` availability and the accept-loop `SIGNAL`/`iterate` pattern.
