# Sequence locality and reconstruction invariance

Media methodologies may be computationally expensive and may consume large, sparse or resident media objects.  Execution locality is therefore a first-class **execution concern**, but it is not a media-analysis methodology and never becomes acoustic or visual evidence.

The current reference contract composes with Audio V9 Candidate20 `audio.v9.sequence-execution-experiment/1`.  Its policies are `FIXED_EXECUTION`, `MOVE_TO_STORAGE`, `MOVE_TO_MEMORY`, `LOOKAHEAD_LOCALITY`, `STATE_AFFINITY`, `REDUNDANT_CONTINUATION`, `ECONOMIC` and `ADAPTIVE`.

The ownership boundary is strict:

- Media Methodologies owns experiment/lineage/work semantics.
- Audio V9 owns sequence continuity and its compact DSP continuation state.
- Storage Fabric owns durable material identity.
- Memory Fabric owns transient fenced resident objects and horizons.
- Generalized Compute Intentions may propose execution strategies.
- Job-to-Node owns admission, placement and lease authority.
- RexxOS/RTO2 own runtime identity and execution/failover mechanics.

A route proposal is not permission to execute.  The bridge intentionally has no API to mint an `AudioV9AuthorizedSequenceRoute`; an externally issued and verified Job-to-Node lease is required.

## Scientific invariant

For a deterministic reconstruction implementation and identical source evidence, changing execution locality must not change the reconstructed samples beyond the implementation's declared numerical tolerance.  Route/failover qualification therefore records both execution metrics and a reconstruction-equivalence measurement.

`equivalent=true` establishes only **execution invariance for that trial**.  It does not validate the reconstruction scientifically, increase confidence in the acoustic hypothesis, or provide an independent methodology lineage.

A failed equivalence comparison is retained as a failure/disagreement result; the framework must not select the numerically different route merely because it is cheaper or faster.

## Candidate20 reference result

The upstream deterministic Candidate20 fixture reports exact (`max_abs_error=0`) equivalence for FIXED_EXECUTION, MOVE_TO_STORAGE, MOVE_TO_MEMORY and LOOKAHEAD_LOCALITY, and again after one injected post-commit MI loss.  These are deterministic fixture results, not a claim of live multi-host execution.
