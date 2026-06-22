# Mesh debug help for CLAUDE-ALCHEMY-1

Read against the uploaded debug package containing `data/MeshNode.cls`, `data/AlchemyTransport.cls`, `data/GitTransport.cls`, `data/EventWireFormat.cls`, `data/EndpointProfile.cls`, and the mesh demos.

## Main observation

The `rxqueue SET/GET` thread-global issue may no longer be the only pickle. The debug package shows `RxQueueTransport` has moved to `.RexxQueue` object calls, which is the right direction. But both queue transports still have a more structural hazard: **generic `open` is destructive**.

In a mesh, `open` must mean attach/ensure, not purge.

Current risky pattern:

- `RxQueueTransport~open` creates/attaches and then drains stale messages.
- `InternalQueueTransport~open` creates/attaches and then drains stale messages if the queue exists.
- `RxQueueTransport~close` drains and deletes the named queue.

That can eat live handshake messages. Example: any sender opening a peer ANNOUNCE queue can purge another pending `CONNECT` before the peer listener drains it. A CTL transport opening late can also purge a `CONNECTED` or app payload. Closing one handle can delete a shared named queue that another node still considers its inbox/outbox.

## Recommended repair

Split queue lifecycle into three separate concepts:

```text
attach/open/ensure  -> non-destructive, idempotent
purge/reset         -> explicit test/demo setup only, before listeners start
destroy/delete      -> explicit owner teardown only, not generic close
```

Concrete rule:

```text
Transport~open must never drain.
Transport~close must never delete shared named queues.
```

Add optional explicit methods if needed:

```rexx
::method purge
::method destroy
```

and call them only from known setup/teardown code, not during handshake or sender creation.

## Second likely hazard

`MeshNode` mutates `_ctlIn`, `_ctlOut`, `_routes`, and `_heartbeat` from both the background `listenLoop` / `handleConnect` path and the `connect` path. Because `connect` and `listenLoop` are `unguarded`, simultaneous topology construction can race.

Until the queue lifecycle is stable, test with serialized connects instead of launching all `.Message~new(...connect...)~start` calls at once. Once stable, add a lock/serialization point around route-table mutation.

## Naming invariant to preserve

The CTL direction convention looks correct and should stay explicit:

```text
FROM-TO means FROM writes, TO reads.
```

For a connection from A to B:

```text
A outbound: A-B.CTL  -- A writes, B reads
A inbound:  B-A.CTL  -- B writes, A reads
```

For git:

```text
newSender(repo, FROM, TO)    writes mesh/ctl/FROM-TO/
newReceiver(repo, ME, FROM) reads  mesh/ctl/FROM-ME/
```

## Minimal test ladder

1. Two-node InternalQueueTransport, synchronous/serialized connect.
2. Four-node InternalQueueTransport LINEAR, serialized connects.
3. Four-node InternalQueueTransport LINEAR, concurrent connects.
4. Two-node RxQueueTransport cross-process.
5. Mixed Internal/RxQueue bridge.
6. GitTransport read/write after local mesh is stable.

At each step assert:

```text
peer counts are expected
exactly one CONNECTED per link
no nil payload fields
no unexpected queue purge
send all-to-all has expected PASS/FAIL for that topology
```

## Short version

Do not keep chasing only thread contamination. The remaining ghost may be **message loss caused by destructive open/close semantics**. Make open/close boring and non-destructive first; then retest the mesh.
