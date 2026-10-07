# XTP dev9 — native receive endpoint

Dev9 completes the userspace library transport boundary in both directions.

```text
SocketSelector / fabric
        |
  XTP provider binding
        |
 libxtp SocketProvider
     /             \
 send_message()   listen()
     |              |
 best_connect()   Listener
     |              |
 L2 / L3 / L4    L2 / L3 / L4
```

`xtp::Listener` is persistent.  It owns its carrier descriptor and duplicate
KEY set, acknowledges valid FIRST transactions, and returns reconstructed
logical bytes only for the first delivery of a KEY.  Duplicate transactions
are acknowledged again but are not exposed as a second application delivery.

Wire representation remains below application/socket semantics: `XWF1`
zero-block/Crunch filters are decoded by the Listener after XTP integrity and
sequence processing.

The listener route is selected from the same route table used by the sender.
For L4, `Route::destination` is the UDP bind endpoint; for L3 it is the local
IPv4 bind address; for L2 the configured interface is authoritative.

The ooRexx listener bridge remains intentionally fail-closed until a persistent
native ooRexx binding is available.  A shell-per-accept wrapper would change
transport semantics by discarding replay state and is therefore not used.
