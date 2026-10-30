# XTP dev7 architecture boundary

```text
ooRexx / portfolio SocketSelector
        |
    XTP provider objects
        |
  libxtp RouteTable + SocketProvider
        |
   best_connect / best_paths
        |
 per-route WireFilterChain
        |
 libxtp transport provider
        |
   L2 / L3 / L4 carrier
```

Dev7 closes an important dev6 gap: carrier selection was already library state,
but the actual client send path still lived only in `xtp-local`.  In dev7,
`libxtp` owns the client transport path through `send_message()` and
`SocketProvider::send()`.  `bin/xtp-connect` is a thin library caller used for
qualification and administration-oriented testing.

## Locked rules

1. Applications request XTP and a peer.  They do not call AF_PACKET, raw36 or
   UDP APIs directly.
2. `best_connect()` prefers the lowest permitted layer: L2, then L3, then L4;
   metric orders routes within a layer.
3. `best_paths()` exposes the ordered permitted path set for later striping,
   failover and multicast work.
4. Explicit route enable/disable changes path eligibility without changing
   application code.
5. A route carries its wire-filter profile.  Wire representation is therefore
   selected at the socket/path boundary and remains independent of the
   application object model.
6. Dev6 seven-column route files remain readable; dev7 writes an eighth
   `wire_filters` column.
7. Route-table replacement is atomic within one filesystem using write-temp +
   rename.
8. `zero-block` and `crunch` are self-describing XWF1 wire filters.  Expansion
   is bounded by the encoded logical length and a default 64 MiB decode ceiling.
9. ooRexx sees `XTPManager`, `XTPPeer`, `XTPRoute` and
   `XTPWireFilterChain` objects.  The current bridge uses `xtp-admin`; a later
   native ooRexx extension can replace that bridge without changing the public
   object contract.
10. Kernel residency remains an implementation/provider decision:
    userspace library, `xtp.ko`, or `CONFIG_XTP=y` must preserve the same
    selector/route semantics.

## Carrier status in dev7

Library client send is implemented for:

- L2 `l2` via EtherType `0x817D` / AF_PACKET;
- L3 `raw36` via IPv4 protocol 36;
- L4 `udp` via XTP-over-UDP.

Other L4 carrier names can be represented in the route graph but are rejected
by `send_message()` until their provider is implemented.  This is deliberate:
configuration is not treated as evidence that a carrier implementation exists.

## Still to do

- multipath striping and replay over a surviving path;
- multicast path-set distribution;
- carrier health/rejoin generations;
- actual AF_XTP socket-family implementation in the kernel provider;
- native ooRexx extension binding once an ooRexx development environment is
  available for compile/runtime qualification.
