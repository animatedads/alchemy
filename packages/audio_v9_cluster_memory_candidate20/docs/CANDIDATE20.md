# Audio V9 candidate20 — runner follows Memory Fabric horizon

Candidate20 is additive to Audio V9 dev20 candidate19.  Candidate19 already
keeps measured-delay reconstruction and motion-coherence continuation compact:
PCM/STFT/correlation/reconstruction buffers remain behind fenced Memory Fabric
block references.

This increment consumes Memory Fabric v0.1-dev10 live/adaptive horizon state and
the existing Cluster Object Memory Fabric Transport v0.2.

## Execution sequence

1. The Audio sparse logical stream is read normally.
2. Memory Fabric's live `AT` projection crosses the adaptive event horizon and
   creates one coalesced `MemoryFabricHorizonDemand` for the next logical range.
3. `AudioV9ResidentWindowDirectory` resolves that range only if a current,
   already-published Memory Fabric block covers it.  Block generation and
   provider owner epoch are revalidated on every resolve.
4. An external placement guard revalidates Job-to-Node authority for the exact
   destination.  The adapter cannot mint a placement lease.
5. `ClusterObjectMoveCoordinator` moves the compact runner/object state through
   Queue Fabric to the node/MI owning the block.  Audio bytes are not part of
   the MOVE envelope.
6. Only after MOVE acknowledgement are Memory Fabric cursor/window state and the
   horizon demand advanced/satisfied.
7. The destination resolves the fenced block locally and continues candidate19
   processing with its compact acoustic continuation.

## Important negative cases

- No resident route: `NEXT_WINDOW_NOT_RESIDENT`; runner stays put.
- Stale block/provider epoch: route resolution fails; runner stays put.
- Missing/failed Job-to-Node verification: `PLACEMENT_NOT_VERIFIED`; runner stays put.
- Queue delivery ambiguity: existing cluster object `MOVE_UNCERTAIN` behavior is
  retained; Memory Fabric demand is not falsely satisfied.
- A non-contiguous logical next block is rejected before MOVE.

RTO2 Grid may project horizon state as detached evidence, but it does not satisfy
Memory Fabric demands or become placement authority.
