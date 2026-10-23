# Authority boundary

`cluster.object.peer/0.2` is a movement seam, not a placement or memory authority.

A source host may snapshot a registered movable object and ask a verified destination to reconstruct the next generation beside a fenced Memory Fabric block. The destination validates fabric id, block id, block generation, provider id and owner epoch before local memory resolution.

The source releases its resident object only after a positive destination acknowledgement. Missing/ambiguous acknowledgement is `MOVE_UNCERTAIN`; it is not silently interpreted as success.

Bulk memory remains outside the MOVE graph. Memory Fabric and Storage Fabric retain their existing authority over resident and durable material respectively.
