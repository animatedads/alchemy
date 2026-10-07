# Storage Fabric authority persistence — v0.1-dev21

Persistence belongs to Storage Fabric authority, not to any one presentation surface.
FUSE, relation/query, intentions, peer services and native ooRexx callers may all
observe the same durable object/namespace state.

`storage.fabric.authority/0.1` adds a two-slot restart checkpoint for:

- catalogue objects and verified locations;
- environments and their generations;
- namespace bindings, aliases, query folders and query clauses;
- namespace parent relationships and query exclusions;
- provider identity/capacity/failure-domain records (never credentials);
- per-object replica requirements.

The checkpoint publishes `CURRENT` only after the new catalogue and authority
slot are complete.  The previous slot is retained so an incomplete newest slot
can be ignored during restart.

Surface session state is deliberately excluded: FUSE handles, query cursors,
conversation state and socket sessions are reconstructed.  Provider secrets are
also excluded and must be reacquired from the appropriate authority.

## FUSE projection persistence

The existing `StorageFuseGenerationStore` now has explicit `savePersistent()` and
`loadPersistent()` operations.  They persist live files, named streams,
directories and published generation snapshots.  Binary payloads are encoded
losslessly rather than being treated as text.  Qualification writes every byte
value 00-FF and verifies it after restart through both the generation store and
the ordinary `StorageFuseOperationCore` surface.

A FUSE checkpoint refuses to publish while transient file handles or an
unresolved generation barrier exist.  Those are surface/runtime state and are
not silently serialized as authority.

This is deliberately not a claim that FUSE is the Storage database.  The
surface-neutral authority checkpoint is the durable control/catalogue state;
FUSE persistence is a compatible projection-state checkpoint for the current
in-process generation implementation while provider-backed object persistence
continues to move underneath it.
