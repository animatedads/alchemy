# Provenance — Audio V9 Pattern Locator v0.1-dev5

## Semantic lineage

The locator is grounded in ooRexx ML v0.1-dev10:

- `MLPatternHash`: affine-normalised pattern identity and significance-ordered
  structural difference;
- `MLCloseNeighbour`: ordered quantised close-bucket probing and significance;
- `MLTemporalPatternHash`: explicit irregular-time shift/scale-invariant pattern
  evidence retaining local gap/elevation/turn differences.

The packed 18-bit V9 landmark value is an address into the pre-existing CSR,
**not** the definition of acoustic similarity.

## Exact dependencies

- ooRexx ML v0.1-dev10:
  `8f7f104599e17035314645e300fceb9124735d779fc14c46d6c60ea9b44d6b89`
- ooRexx Foreign Runtime v0.22.6:
  `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`
- supplied ooRexx 5.3.0 r13196 package used for qualification:
  `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`
- ooRexx ML Gopher sphere v0.1-dev10 (documentation/reference only):
  `6878ed9a621543cb0be3fa857880ee386e77d0742edb173f33d916bc03cbd493`

## Historical V9 evidence

`reference/` carries the previously reconciled evidence separately from matching:

- `V9_SNIPPET_GENERATIONS.tsv`: generation assignment for the 671 surviving WAVs;
- `V9_GEN3_EVENTS.jsonl`: surviving 801-event metadata for independent validation;
- `V9_GEN3_SCENE_MANIFEST.json`: historical run boundary/tier evidence;
- `V9_GENERATION_PROOF.json`: classification-generation reconciliation.

The scene manifest identifies tier `amp32`.  Event IDs preserve scan chronology;
classification/file mtime does not define chronology.

Generation-3 event metadata is never supplied to the acoustic matcher.  It is
used only after a result exists by `validate_gen3_seed.rex`.


## dev5 Spectral Pattern Field provenance

The Spectral Pattern Field does not replace or alter the original waveform. Native code measures bounded 8 kHz windows using a 512-sample Hann FFT and emits overlapping-band q25/q50/q75 log-intensity records. ooRexx owns smoothing, common-mode residual construction, scene/box evidence and `MLPatternHash` comparison.

The moving-box pattern schema is deliberately **not rotation invariant** and **not reversal invariant**: temporal order inside a spectral box is evidence. Exact pattern-key equality is not treated as authority after the real raw-vs-recovery test showed heavy processing can change quantised keys while movement/turn geometry remains highly correlated.

Real fixture files are qualification inputs and are not bundled into the release ZIP. Their SHA-256 values and measured summaries are preserved in `qualification/SPECTRAL_PATTERN_FIELD_REAL_DEV5.txt`.

## dev5 STOP-bucket provenance

The salvaged production CSR contains globally frequent, low-information landmark buckets (live ed209i evidence included a largest bucket of 271,337 postings and 419 buckets above the earlier 4,096 ceiling). Dev5 does not raise the ceiling and does not truncate those buckets. Native selective lookup returns each exact authorized hash as `USE` or `STOP` according to its global CSR population; ooRexx records skipped evidence and enforces a maximum STOP fraction. This keeps the decision deterministic across distributed source shards.


## dev5 distributed Spectral Pattern Field provenance

Distributed field workers operate on one canonical mono 8 kHz float32 master whose SHA-256 is embedded in every immutable work unit. The coordinator plans exact sample ranges rather than arbitrary wall-clock decodes. Each work start is on the global 256-sample/32 ms FFT phase; right-hand context is carried far enough to finish owned 1 s boxes/segments and complete the final 1024-sample FFT frame. Ownership is by global box/segment start within the unit core.

This prevents node placement, shard boundary and completion order from altering the field. `test_spectral_field_distributed_equivalence.rex` qualifies four shuffled workers against a monolithic fixture and requires byte-for-byte equality of merged segment and box TSV, including ML pattern keys. The coordinator rejects missing units and duplicate keys; workers reject a master whose SHA-256 differs from the manifest.

Band-level parallelism is not yet independent authority because common-mode residuals depend on all bands in a frame. Any future frequency shard must consume a pinned common-mode artifact generated from the full field.

## Existing CSR reuse

The completed v0.2 CSR on ed209i contains 17,009,216 postings and remains a data
artifact, not a semantic dependency.  Dev2 qualification established that the
new native landmark extractor reproduced the historical Python v0.3 landmark
measurement contract exactly: 532 ordered tuples, zero mismatches on the
qualification signal.

Dev4 reads exact buckets from that CSR only after ooRexx has authorised their
coordinate neighbourhoods.

## Source provenance

CSR `meta.json` supplies indexed source identity.  ooRexx independently enforces:

- canonical `YYYYMMDD_HHMMSS_tpNNNNN_original.ogg` basename;
- 20231009/20231010 date admission;
- FC/FD source-family binding;
- filename-derived source start time using `NUMERIC DIGITS 30`;
- exact source byte size and nanosecond mtime through the native provider.

A worker-local source-root rebind is allowed only when those identity checks
still pass; the original indexed path remains in provenance.

## dev4 close-neighbour optimization provenance

R024 is an implementation optimization of dev10 semantics, not a new similarity
model.  The relative probe stencil's `MLCloseHashDifference` objects are created
by dev10 `MLCloseHashSchema~difference`; per-landmark address formation merely
translates those admitted relative coordinates into the existing packed CSR
address.  The final probe order uses dev10 `MLProbeKeyComparator`.

`test_probe_stencil_equivalence.rex` is the executable guard against semantic
drift from the generic dev10 path.

## dev6 dependency transition — 2026-09-09

Active ML dependency: `oorexx_ml_v0.1-dev11.zip`, SHA-256 `713c4998c67aed9b526f3e20f7b2f14de4b355939259bff55beebe9133980c79`.
Supplied source filename: `oorexx_ml_v0.1-dev11(1).zip`.
Active graph dependency: `oorexx_ml_graph_v0.1-dev3.zip`, SHA-256 `a4ee63c48eab3ac27166607998071800f32b9af0cf6c3dbba12e08fa6627402a`.

Dev11 wobbliness semantics are consumed without reinterpretation: contextual distance-to-fit under an active model, all minimal restoring sets retained, exclusion diagnostic only, bounded exact search fails closed.
