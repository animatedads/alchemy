# XTP dev13 architecture

dev13 closes the persistent-path rejoin loop.

`RouteTable` remains configuration/permission. `PathHealthTable` remains
operational state. `SocketProvider::requalify()` now performs a live,
carrier-specific XTP transaction before committing `PROBING -> UP`.

The live probe uses an internal 16-byte qualification payload, still carried as
a normal XTP FIRST transaction and acknowledged by CNTL. A `Listener`
recognises it after wire-filter decoding, acknowledges it normally, and
suppresses application delivery. This gives the same qualification semantic for
L2 EtherType 0x817D, L3 protocol 36, and L4 UDP without exposing probe records
to application fabrics.

Successful qualification increments the route generation. Failure records the
carrier error, returns the route to DOWN, and increments the failure count.

Rexx administration calls the same `xtp-admin path qualify` operation.
`forcePathUp()` exists only as an explicit administrative override.
