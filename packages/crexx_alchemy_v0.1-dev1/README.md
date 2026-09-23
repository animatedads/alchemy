# cREXX Alchemy v0.1-dev1

First implementation spike for the bidirectional cREXX Alchemy adapter.

It proves the RXPA mechanics before substituting the real Alchemy Foreign
Object: typed native objects, alias-preserving native payload lifetime,
idempotent alias-visible close, and synchronous typed callback through
`CALLMETHOD`, including nested RXPA re-entry.

No borrowed `rxpa_attribute_value` is retained and no private VM frame or
`proc_runtime` API is used.

The remaining dev1 wiring item is documented in
`docs/IMPLEMENTATION_NOTES.md`.
