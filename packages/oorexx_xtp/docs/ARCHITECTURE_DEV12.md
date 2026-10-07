# XTP v0.1-dev12 — persistent path health and generation-fenced rejoin

Dev11 fenced a failed path only for one transfer. Dev12 promotes path health to
persistent libxtp state.

`RouteTable` remains configuration: what paths are permitted. `PathHealthTable`
is operational state: which permitted paths are currently admissible.

States are:

- `UP`: eligible for `best_connect()` / `best_paths()`.
- `DOWN`: excluded after a real send failure or administrative fault mark.
- `PROBING`: excluded while external/provider qualification is in progress.

Requalification is deliberately explicit. `path probe` moves a path into
`PROBING`; after the carrier/provider qualification succeeds, `path up` moves it
back to `UP` and increments that path's generation. A multipath send with
`generation=0` derives the transfer generation from the selected path set.
Therefore a returned path cannot re-enter the stripe under the old generation.

The separation is intentional: libxtp owns data-plane failure detection and
persistent fencing. Provider-specific qualification (VPN establishment, cloud
edge reachability, raw36/L2 link checks) can be performed by the administrator
or higher platform service, then committed through the same libxtp path-health
API. No application or Queue/Memory/Storage Fabric code needs carrier logic.

The ooRexx administration objects expose the same state through `XTPPeer`:
`pathHealth`, `pathDown`, `beginPathRequalification`, and `pathRequalified`.
