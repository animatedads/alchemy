# Audio V9 Pattern Locator — Progress Ledger

This ledger is append-only during development.  It records decisions, experiments,
failures, evidence and next actions as they occur rather than reconstructing them
at release time.

## 2026-09-08 — Iteration 1 start

### Decision P001 — semantic authority
- The locator is an ooRexx ML application, not a Python matching engine.
- `MLPatternHash` owns affine-invariant curve identity and significance-ordered
  shape difference.
- `MLCloseNeighbour` owns bounded, explicit close-bucket probing for local
  deformation.
- V9 event chronology is independent evidence and must not be hidden inside an
  opaque scalar score.
- Native/FFmpeg code may extract measurements and accelerate bulk lookup, but
  must preserve the ooRexx coordinates, policies, ordering and evidence.

### Evidence E001 — exact dependency pinned
- Dependency: supplied `oorexx_ml_v0.1-dev9(2).zip`.
- Exact SHA-256 is recorded in `qualification/INPUT_SHA256.txt`.
- Python V9 Reverse Locator v0.3 is retained only as a comparison/oracle input;
  it is not a runtime dependency of this line.

### Next N001
Implement executable curve/pattern objects and a multi-evidence match object;
qualify affine invariance, small deformation and changed-turn discrimination on
synthetic audio-like temporal curves under ooRexx 5.3.0 r13196.

### Decision P002 — distributed execution boundary
- Distribution is first-class, but it must not distribute semantic authority.
- Work is partitioned as contiguous V9 event ranges crossed with immutable source
  shards.  Any ED209 node may execute a work unit.
- Workers return bounded candidate evidence only.  They do not resolve chronology.
- The coordinator deduplicates/ranks evidence and performs the single authoritative
  generation-local monotonic sequence solve.
- Replaying a failed work unit on another node must not change the answer.

### Implementation I001 — iteration-1 semantic kernel
- Added `src/AudioV9PatternLocator.cls`.
- Multi-curve pattern evidence uses `MLPatternHashDifference` and preserves
  largest-disagreement-first semantics across weighted curve evidence; it does
  not average unlike concerns into a scalar.
- Landmark policy delegates bounded close-bucket semantics to
  `MLCloseHashSchema` / `MLCloseNeighbour`.
- Candidate evidence keeps pattern, landmark, source/feed/time, worker and work
  unit provenance separately.
- Sequence resolver enforces generation-local monotonic time as a hard condition;
  among feasible paths it minimizes worst local acoustic rank, then rank sum.
- Added deterministic work-unit planner, worker-result object and coordinator
  merge seam for distributed nodes.

### Next N002
Write ooRexx 5.3.0 regressions for affine invariance, changed-turn rejection,
close-neighbour landmark probing, chronology, stereo agreement and distributed
local-vs-shuffled equivalence.

### Failure F001 — dependency guard basename assumption
- First iteration-1 test run stopped before executing Rexx tests.
- Cause: `run_tests.sh` searched `INPUT_SHA256.txt` for the staged dependency
  basename, while the ledger intentionally records the original supplied path.
- The actual staged dependency hash was the expected
  `32f4c570d282b2fb4ea7c9e870611d4ae8dccbd0121952add66afb97746fb702`.
- Repair: read the pinned first dependency hash by record position; the hash
  comparison itself remains fail-closed.

### Failure F002 — distributed test oracle preferred time proximity over acoustics
- The first Rexx execution reached `test_distributed_equivalence` and failed its
  final assertion: expected 3000 ms, actual 3100 ms.
- Resolver behaviour was correct.  Both event-12 candidates were monotonic after
  event 11; 3100 ms had exact pattern evidence while 3000 ms had a small pattern
  deformation.  There is deliberately no hidden "prefer the smaller time jump"
  heuristic.
- Repair: corrected the test oracle to 3100 ms.  This records an architectural
  rule: chronology is a hard feasibility constraint, not a substitute acoustic
  similarity score.

### Failure F003 — synthetic near curve collapsed under coarse pattern quantisation
- Re-running the distributed test after correcting F002 showed the selected
  event-12 candidate could not be asserted from the original `4.1` perturbation.
- Under the deliberately small 16-bin test policy that perturbation can quantise
  to the same retained pattern as the base curve, making time/source tie-breaks
  authoritative.  The test had accidentally assumed a non-zero pattern delta.
- Repair: increase the synthetic deformation to `4.8` for this test and emit the
  selected path during qualification.  A separate affine/shape regression still
  tests genuinely small deformation under the production-like 48-bin policy.

### Failure F004 — chronology test reused a deformation that quantised exact
- `test_sequence_resolver` expected the chronology-forced event-1 candidate to
  carry local rank 2, but its 16-bin synthetic near curve encoded identically
  and therefore legitimately had local rank 1.
- Repair: use an unambiguously non-identical `4.8` deformation in the chronology
  test.  This keeps chronology qualification about path feasibility/rank, while
  `test_pattern_semantics` owns small-deformation behaviour at 48 radial bins.

### Failure F005 — generation test used invalid ooRexx CALL syntax
- Full ooRexx ML dependency qualification completed successfully: 49/49 tests.
- The new generation-boundary regression then stopped at parser error 35.1 on
  `call .AudioV9SequenceResolver~new~resolve sets`; that is not valid ooRexx
  message-expression syntax in a CALL statement.
- Repair: invoke the message expression as an assignment while the SYNTAX trap
  is armed.  No production class change was required.

### Evidence E002 — pinned ooRexx ML dependency qualification
- Ran the complete supplied ooRexx ML v0.1-dev9 suite under exact ooRexx
  5.3.0 r13196: `PASS ALL ooRexx ML v0.1-dev9 TESTS (49 files)`.
- Output is captured in `qualification/OOREXX_ML_DEV9_TESTS.txt`.

### Implementation I002 — generation boundary is hard
- Added `test_generation_boundary_fail_closed.rex`.
- The sequence resolver refuses to construct a path across V9 generation IDs.
  Old/stale `evt_NNNNNN` identities cannot be silently chained into a newer run.

### Evidence E003 — locator iteration-1 regression
- Six locator regressions pass under exact ooRexx 5.3.0 r13196.
- Distributed equivalence was additionally run five consecutive times before
  sealing work continued; selected path remained 900 / 1900 / 3100 ms.

### Evidence E004 — source compile
- `src/AudioV9PatternLocator.cls` compiled successfully with supplied ooRexx
  5.3.0 r13196 `rexxc` and the pinned ooRexx ML dependency on `REXX_PATH`.

### Decision P003 — iteration-1 seal boundary
- dev1 is the executable semantic/distribution contract, not a production 4 GiB
  scanner.
- Iteration 2 will add a native/Foreign Runtime bulk feature provider plus an
  ED209 transport adapter while keeping all closeness, pattern and chronology
  authority in ooRexx.

### Evidence E005 — clean-reextract qualification
- The first sealed ZIP candidate was re-extracted into a clean directory.
- `sha256sum -c MANIFEST.sha256` passed for every packaged file.
- All six locator regressions passed from the extracted bytes.
- `AudioV9PatternLocator.cls` compiled from the extracted bytes with exact ooRexx
  5.3.0 r13196 `rexxc`.
- The artifact is being resealed once so this evidence is contained in the
  delivered package itself; final hash is recorded after that reseal.

## 2026-09-09 — Iteration 2 start

### Decision P004 — native provider may address buckets, never define closeness
- The existing v0.2/v0.3 CSR stores packed 18-bit landmark addresses, but that
  packing is not the similarity model.
- ooRexx constructs query coordinates `(dt,f1,f2)` and delegates neighbour
  enumeration and significance ordering to `MLCloseHashSchema`.
- Only those already-authorised exact neighbour coordinates are translated to
  packed CSR addresses `(dt<<16)|(f1<<8)|f2`.
- The native provider receives exact packed bucket addresses and returns postings;
  it has no probe radius, no neighbour-generation API and no ranking authority.

### Decision P005 — native measurement is a provider of curves/coordinates
- A native provider will reproduce the existing 8 kHz / 1024 FFT / 512-hop V9
  landmark measurement contract so the already-built CSR remains reusable.
- It additionally emits temporal RMS, spectral-centroid and spectral-flux curves
  for `MLPatternHash`; those raw curves are evidence, not scores.
- ooRexx parses the provider evidence and performs all pattern comparison.

### Next N003
Implement and qualify the Foreign Runtime provider against: exact CSR bucket
lookup, ooRexx-generated radius-1 multi-probe lookup, and native curve extraction
where affine gain remains pattern-identical and clipped deformation remains closer
than a changed temporal structure.

### Failure F006 — native provider first compile rejected ambiguous one-line IFs
- `native/build_native.sh` intentionally compiles with `-Wall -Wextra -Werror`.
- The first build stopped on two `-Wmisleading-indentation` diagnostics caused
  by multiple one-line `if` statements sharing a line.
- No binary was accepted from that build.
- Repair: expand those statements into independently braced/line-separated
  branches; compiler policy remains unchanged.

### Failure F007 — fixture builder rejected fixed-buffer path construction
- The first fixture-builder compile failed under the same strict compiler policy.
- Diagnostics covered two ambiguous one-line control statements and possible
  `snprintf` truncation into fixed 4096-byte path buffers.
- Repair: use exact-length heap path construction and separate control lines.
- No fixture bytes from the rejected build were used in qualification.

### Failure F008 — ooRexx rejected negative default argument literal
- `rexxc` stopped on `sourceLo=-1` in `USE STRICT ARG` for the native CSR
  wrapper.
- Repair: expose `.nil` as the Rexx-level "no source bound" value and translate
  `.nil` to native `-1` only at the Foreign Runtime call boundary.
- This also improves the public contract by avoiding a magic negative source ID.

### Failure F009 — native tests were launched outside package root
- The first native Rexx test invocation constructed `//native/...` from
  `directory()` because the shell loop had not changed into the package root.
- No provider function ran.
- Repair: the dev2 test harness changes directory to the package root before any
  test; all relative bridge/fixture paths are therefore deterministic.

### Evidence E006 — native landmark extractor is byte-contract compatible with v0.3
- Ran the old Python v0.3 `landmark_hashes()` only as a qualification oracle on
  `run/fixture/base.f32`; it is not a dev2 runtime dependency.
- Python emitted 532 `(packed_hash, anchor_frame)` landmarks.
- The new C provider emitted 532 landmarks in the same order with **0 mismatches**.
- This proves the existing ed209i CSR can be reused without rebuilding it merely
  because semantic authority moved to ooRexx.
- Captured in `qualification/NATIVE_PYTHON_LANDMARK_EQUIVALENCE.txt`.

### Failure F010 — end-to-end test over-specified the second candidate ordinal
- The full native chain correctly recovered source 1 at +50 frames as the top
  trajectory with the expected exact votes.
- The test then assumed source 2 at +100 must be candidate #2.  Additional
  deliberately-populated close-neighbour fixture buckets can legitimately form
  another source-1 offset ahead of that weaker trajectory.
- Repair: assert that source 2/+100 is present with its expected exact evidence,
  rather than assigning it a brittle global ordinal.  Candidate #1 remains a
  strong deterministic assertion.

### Failure F011 — stage codec used a directory-index expression in PARSE VAR
- `rexxc` rejected `parse var h['sources'] ...`; ooRexx requires a variable in
  that PARSE position rather than an indexed expression.
- Repair: assign the decoded `sources` field to a local variable first, then
  parse the `lo:hi` range.  Wire format and semantics are unchanged.

### Implementation I003 — native measurement and exact CSR provider
- Added `native/av9_pattern_provider.c` plus Foreign Runtime bridge metadata.
- The provider reproduces the v0.3 8 kHz / 1024 FFT / 512-hop landmark
  extraction contract and emits four raw temporal curves: RMS, spectral centroid,
  spectral flux and high-band ratio.
- The provider opens the existing NumPy CSR arrays directly and exposes only
  exact packed-bucket lookup.  It has no radius or neighbour-generation method.
- Added `AudioV9NativeProvider.cls`, native feature/posting objects, CSR landmark
  contract, ooRexx probe planner and native pattern-window reranker.

### Implementation I004 — distributed native landmark stage
- Added `AudioV9LandmarkWorker.cls`.
- A worker batches the union of exact packed buckets authorised by ooRexx
  `MLCloseNeighbour`, performs one bounded native lookup over its source-ID shard,
  and constructs visible exact/near offset-vote evidence.
- Candidate generation is bounded by max postings per hash, max votes and top-N
  policy.  Budget exhaustion fails closed rather than silently truncating votes.
- Added canonical stage evidence codec; replayed immutable work units are
  deduplicated, while different evidence for the same work-unit ID fails closed.
- Added balanced contiguous source-range planning for the 1-based CSR source IDs.

### Evidence E007 — native pattern semantics
- Native affine-gain fixture comparison has dominant pattern difference 0.
- Hard-clipped fixture remains closer than a changed-turn temporal structure:
  clipped dominant 15351 versus changed-turn dominant 19230 in the dev2 test.
- Pattern-window reranking selects affine-equivalent, then clipped, then
  changed-turn candidates regardless of candidate timestamp ordering.

### Evidence E008 — distributed data-plane equivalence
- Local full-source and shuffled two-shard native landmark runs produce the same
  ordered candidate set on the fixture.
- Replaying an identical immutable source shard on another worker does not
  double-count its evidence.
- Node-facing shell/Rexx worker output was encoded to files and merged back into
  the same canonical candidate evidence locally.
- A 120-source / 6-worker plan yields exact contiguous 20-source shards; arbitrary
  shard counts are balanced to within one source.

### Evidence E009 — iteration-2 qualification
- Complete ooRexx ML dev9 dependency suite: 49/49 PASS.
- Foreign Runtime v0.22.6 base native test: 128 assertions PASS.
- Audio V9 Pattern Locator dev2: 14/14 tests PASS.
- `AudioV9PatternLocator.cls`, `AudioV9NativeProvider.cls` and
  `AudioV9LandmarkWorker.cls` all compile with exact ooRexx 5.3.0 r13196 `rexxc`.

### Decision P006 — dev2 seal boundary
- dev2 is the executable native measurement / distributed candidate-generation
  checkpoint.  It deliberately stops before binding CSR source IDs back to the
  120 canonical FC/FD files and before extracting/reranking production candidate
  windows.
- Those source-catalog, bounded-window and stereo-feed joins are iteration 3;
  they will consume dev2 evidence rather than move similarity semantics native.

### Next N004
Implement source-catalog admission from the v0.2 CSR `meta.json`, bounded FFmpeg
candidate-window extraction, FC/FD feed provenance, per-window MLPatternHash
reranking, and conversion of the resulting evidence into generation-local event
candidate sets for the existing authoritative chronology resolver.

### Evidence E010 — dev2 candidate clean-reextract qualification
- The candidate dev2 ZIP was extracted into a new clean directory.
- `sha256sum -c MANIFEST.sha256` passed before any test-generated mutation.
- All 14 dev2 locator tests passed from the extracted bytes under exact ooRexx
  5.3.0 r13196.
- All three `.cls` sources compiled from the extracted bytes with r13196 `rexxc`.
- The package is resealed once so this clean-byte evidence is itself included;
  the final ZIP is then re-extracted and tested again.

## Iteration 3 — source binding, bounded windows and production chronology

### Failure F012 — default ooRexx numeric precision collapses 2023 millisecond timestamps
- Production absolute timestamps are 13-digit epoch-millisecond integers.
- A direct r13196 probe proved the default `NUMERIC DIGITS 9` converts
  `1696928003123` to `1.69692800E+12`, and two timestamps 100 ms apart compare
  equal at default precision.
- The dev1/dev2 synthetic tests used small time values and therefore did not
  expose this production-only defect.
- Repair in dev3: candidate construction and every absolute-time comparator /
  chronology / stereo-agreement arithmetic path explicitly use
  `NUMERIC DIGITS 30` before conversion or comparison.  Stored timestamps remain
  exact integers rather than rounded scientific notation.
- Stereo candidate evidence is also being extended with optional secondary
  pattern/landmark evidence so both FC and FD channels remain visible rather
  than collapsing a pair to one opaque score.

### Decision P007 — source identity is data; source similarity is not
- The v0.2 CSR `meta.json` remains authoritative only for source identity and
  index provenance: source ID, canonical name/path, filename-derived start,
  duration, camera/feed, size and mtime.
- ooRexx admits and cross-checks that metadata.  A native filesystem-measurement
  function may report exact size/mtime; it has no matching or policy authority.
- Candidate wall-clock time is derived in ooRexx from admitted source start plus
  landmark offset (`512/8000 = 64 ms` per frame).

### Failure F013 — EXPOSE ordering and direct self-message syntax in dev3 source
- After the F012 precision repair, `rexxc` correctly rejected methods where
  `NUMERIC DIGITS 30` had been inserted before `EXPOSE`; ooRexx requires
  `EXPOSE` to be the first executable instruction of an exposing method.
- The new source-record initializer also used `CALL self~validateCanonicalName`,
  which is not valid message-send syntax in ooRexx.
- Repair: move `EXPOSE` before `NUMERIC DIGITS 30` in every exposing method and
  send `self~validateCanonicalName` directly.  All four dev3 `.cls` sources now
  compile under exact ooRexx 5.3.0 r13196.

### Implementation I005 — production source binding and bounded window plan
- Added `AudioV9SourceBinding.cls` with canonical 20231009/20231010 original
  admission, exact CSR source-ID/feed/camera identity, filename-derived wall-clock
  binding, bounded ±4/±2/0 frame candidate-window plans, pattern reranking and
  explicit FC/FD stereo agreement evidence.
- Absolute time arithmetic is executed with `NUMERIC DIGITS 30`; source mtime
  identity remains textual evidence and is never used as similarity evidence.

### Failure F014 — Rexx test shell command concatenation parsed as arithmetic
- The first dev3 production-window test failed before decoding audio because a
  quoted `ADDRESS SYSTEM` expression embedded `root||...` inside a literal in a
  way ooRexx parsed as arithmetic text rather than string concatenation.
- Repair: construct the complete shell command in a variable with explicit `||`
  concatenation, then send that variable to `ADDRESS SYSTEM`.  No runtime
  locator semantics changed.

### Decision P008 — distributed workers may rebind source roots, never source identity
- Production CSR metadata records the ed209i source path, but a replayable source
  shard may be staged under a different filesystem root on another ED209 node.
- dev3 therefore permits an explicit worker-local source-root rebind to
  `camera_fc/<canonical name>` / `camera_fd/<canonical name>` while preserving
  the original indexed path as provenance.
- Rebinding does not relax admission: canonical name/feed, source size and exact
  nanosecond mtime must still equal the CSR metadata.  A distributed copy should
  therefore preserve mtimes (for example `rsync -a`).

### Implementation I006 — canonical distributed window-plan wire format
- Added `AudioV9WindowPlanCodec`: the coordinator serializes only bounded windows
  already authorized by ooRexx landmark evidence and source admission.
- Each row carries source ID/feed, exact offset and wall-clock milliseconds,
  landmark evidence, active worker-local path and original indexed-path
  provenance.  Decoding rechecks all of those fields against the admitted source
  catalog; a worker cannot silently move a candidate or substitute a source.
- Added node-facing `plan_candidate_windows.sh` and `measure_window_plan.sh`.
  Measurement uses FFmpeg only to decode the exact authorized windows to the
  fixed 8 kHz float format; similarity/ranking remains in ooRexx ML.

### Failure F015 — window-plan decoder repeated the indexed-expression PARSE mistake
- `rexxc` rejected `PARSE VAR lines[1] ...` for the same reason previously
  recorded in F011: an indexed expression cannot appear directly in that PARSE
  position.
- Repair: assign the header row to a scalar variable before `PARSE VAR`.  The
  wire format is unchanged.

### Failure F016 — test assumed STREAM QUERY EXISTS returns boolean 1
- `measure_window_plan.sh` successfully produced both window files, but the test
  asserted that `STREAM(...,'QUERY EXISTS')` returns integer `1`.  r13196 returns
  the resolved pathname on success.
- Repair: assert non-empty existence results.  Measurement output was already
  correct; no locator code changed.

### Evidence E011 — dev3 production-binding qualification
- Exact ooRexx ML dependency suite: 49/49 PASS.
- Foreign Runtime v0.22.6 base native boundary: 128 assertions PASS.
- Audio V9 Pattern Locator dev3: 20/20 tests PASS.
- All four locator `.cls` sources compile under exact ooRexx 5.3.0 r13196.
- Strict native provider rebuild passes `-Wall -Wextra -Werror`.
- Production-like qualification now includes canonical OGG FC/FD sources,
  19-digit mtime-ns JSON evidence, 13-digit epoch-ms chronology, remote source
  rebinding, bounded FFmpeg windows, MLPatternHash reranking, stereo agreement
  and canonical window-plan transport.

### Decision P009 — dev3 seal boundary
- dev3 is the source-binding / bounded-pattern-window checkpoint.
- Landmark source-shard evidence and candidate window plans are transportable and
  replayable across nodes; the final post-pattern candidate-evidence codec and
  671-event production coordinator are intentionally iteration 4 rather than
  being rushed into this seal.

### Next N005
Add a ranking-preserving post-pattern candidate evidence codec, generation-aware
production coordinator, mono/stereo snippet admission, distributed work-unit
manifest, incremental result journal and resumable 671-event solve against the
existing ed209i CSR.

### Evidence E012 — dev3 candidate clean-reextract qualification
- Candidate dev3 ZIP was extracted into a new clean directory.
- `sha256sum -c MANIFEST.sha256` passed before any test-generated mutation.
- All 20 dev3 locator tests passed from the extracted bytes under exact ooRexx
  5.3.0 r13196.
- All four `.cls` sources compiled from the extracted bytes with r13196 `rexxc`.
- The package is resealed once so this clean-byte evidence is itself present in
  the delivered artifact; the final ZIP is then re-extracted and checked again.

## 2026-09-09 — Iteration 4 start

### Decision P010 — post-pattern evidence must be ranking-preserving and replayable
- Distributed window workers may return only evidence sufficient to reconstruct
  the exact ooRexx candidate ordering.  They must not return opaque scalar
  similarity scores or make chronology decisions.
- The wire contract will preserve, per curve, the dominant and total
  `MLPatternHashDifference` components used by `AudioV9PatternEvidence`, plus
  landmark dominant/score and exact source/time provenance.
- The coordinator reconstructs typed evidence, joins FC/FD where required, then
  performs the single authoritative generation-local chronology solve.

### Implementation I007 — post-pattern evidence wire and production coordinator
- Added a ranking-preserving candidate wire format.  Each curve carries the
  dominant and total `MLPatternHashDifference` components used by the authoritative
  `AudioV9PatternEvidence` ordering; landmark dominant/score and exact source/time
  provenance are retained separately.  Decoding reconstructs typed ooRexx
  evidence and fails if ordering changes.
- Added generation-map admission from `V9_SNIPPET_GENERATIONS.tsv`, evidence
  status reporting, mono/stereo evidence-file conventions, FC/FD joining and one
  generation-local chronology solve per V9 generation.
- Stereo source identity now retains each feed's exact source ID and offset
  (`FC:id@offset+FD:id@offset`) instead of only an averaged offset.
- Added node-facing `run_pattern_worker.sh` and final `solve_candidate_evidence.rex`.

### Failure F017 — dev4 test harness did not stage pinned runtime before first test
- All five `.cls` sources compiled under r13196, but the first runtime test failed at
  `::requires 'json.cls'` in `AudioV9SourceBinding.cls`.
- This is a runtime dependency-resolution failure, not a source parser failure:
  `rexxc` had already accepted all five sources.
- Investigation is comparing dev4 `run_tests.sh` / runtime preparation with sealed dev3;
  the pinned dependency requirement will not be weakened.

### Repair R017 — make ooRexx installation classes explicit in every Rexx wrapper
- Root cause: `json.cls` is supplied by ooRexx itself (beside the interpreter), not
  by Foreign Runtime.  The harness previously exposed only project, ML and
  Foreign Runtime paths.
- Repair: every shell entry point that launches Rexx now resolves the selected
  interpreter (`REXX_BIN` or `rexx`), derives its installation directory and
  appends that directory to `REXX_PATH` explicitly.
- This removes hidden dependence on caller environment and keeps the exact
  interpreter installation authoritative for its own standard classes.
- All shell entry points pass syntax validation after the repair.

### Implementation I008 — immutable production work manifest and resumable evidence spool
- Added `AudioV9ProductionWorkManifest`: deterministic event x channel x source-shard
  work units.  The manifest preserves generation, snippet-relative path, channel,
  query duration and exact source-ID range; decode revalidates every unit against
  the authoritative generation map and requires gap-free/non-overlapping source
  coverage for every event channel.
- With the production 671-snippet inventory and six source shards this contract
  yields 1,253 event-channel searches and 7,518 immutable replayable work units.
- Added `AudioV9WorkEvidenceCoordinator`: each unit evidence file is validated
  against its manifest assignment before candidates may enter the merge.  Source
  IDs outside the unit shard, mixed workers, wrong event/generation, and shard
  overlap fail closed.  Local shard ranks are discarded and authoritative global
  candidate order is reconstructed in ooRexx.
- Added direct `solveAllWork`, so final FC/FD join and generation-local chronology
  can consume completed work-unit evidence without an intermediate mutable rank
  database.
- Added per-generation work-evidence status and coordinator-side append-only
  journal synchronization.  Journal rows are bound to exact collected candidate
  bytes by SHA-256; a changed replay of a previously journaled unit fails closed.
- Added node/coordinator tools for work-manifest planning, work status, journal
  synchronization and distributed evidence solve.

### Failure F018 — generated negation guard used the wrong ooRexx operator text
- The first work-manifest test rejected a valid `AudioV9GenerationMap` at the new
  planner type guard.
- This is confined to newly generated dev4 source.  The design contract was not
  reached; the guard text itself is being audited/repaired before any rerun.

### Repair R018 — remove accidental double negation from I008 guards
- Audited every newly added I008 guard and replaced the generated `\\predicate`
  text with the intended ooRexx `\predicate` logical negation.
- The affected checks cover manifest type admission, directory membership,
  work-evidence type/source admission, SHA-256 hexadecimal validation and digest
  presence.  No wire or work-unit contract changed.

### Failure F019 — resume test parsed an indexed array expression directly
- `test_work_evidence_resume.rex` used `PARSE VAR report[1] ...`; r13196 rejects
  indexed expressions in that PARSE position, the same language rule already
  recorded in F011/F015.
- Production manifest/evidence code had passed to this point.  Repair is test-only:
  assign `report[1]` to a scalar and parse that scalar.

### Failure F020 — resume fixture gave both stereo channels the FC source
- The work-evidence fixture chose each shard's low source ID mechanically.  For
  `evt_000002` channel 1 in shard `[1..2]` this selected source 1/FC, so both
  channels were FC and the authoritative stereo joiner correctly failed with
  `no FC/FD stereo agreement`.
- Repair is fixture-only: channel 1 selects source 2/FD within the same admitted
  shard.  The stereo fail-closed rule remains unchanged.

### Decision P011 — dev10 becomes the locator dependency head
- Supplied `oorexx_ml_v0.1-dev10(1).zip` is now pinned as the semantic dependency.
- SHA-256: `8f7f104599e17035314645e300fceb9124735d779fc14c46d6c60ea9b44d6b89`.
- Complete dev10 suite passed under exact ooRexx 5.3.0 r13196: 57/57 tests.
- Existing `MLPatternHash` and `MLCloseNeighbour` authority remains unchanged.
- New `MLTemporalPatternHash` is admitted as additional structural/timing evidence;
  it does not replace landmark candidate generation or generation chronology.

### Decision P012 — stop extending the stalled Python locator
- The live v0.2 Python/CSR run remained in disk-I/O wait after approximately ten
  hours and produced no per-event result/checkpoint.
- Its completed 17,009,216-posting CSR remains useful as an exact posting store.
- No further production matching semantics will be added to that Python line.
- The ooRexx locator must emit event/channel checkpoints immediately so long runs
  are observable and resumable.

### Repair R017b — make interpreter-supplied classes explicit
- During dev10 migration every Rexx-launching shell wrapper now resolves the
  selected interpreter directory and adds it explicitly to `REXX_PATH`.
- This makes `json.cls` and other interpreter-supplied classes available without
  depending on the caller's shell environment.

### Implementation I009 — dev10 temporal landmark-pattern evidence
- Added `AudioV9TemporalPatternContract` over the native landmark event stream.
- Landmark anchor frame * 64 ms is the explicit event-time axis; duplicate anchor
  frames are aggregated rather than inventing zero-time transitions.
- Separate channels retain F1 trajectory, F2 trajectory, pair spread, landmark
  density and relation-code mixture with explicit channel weights.
- Uses `MLTemporalPatternHash` with time-shift and time-scale invariance enabled:
  global clock shift/stretch is not identity, but local event-gap/elevation/turn
  variation remains visible.
- Temporal evidence is additional evidence only; it does not redefine close
  landmark probes, source admission or V9 generation chronology.

### Failure F021 — first production runner shell-quote literal was invalid ooRexx
- The first end-to-end `run_event_pipeline.rex` execution stopped at parse time
  in a helper that attempted POSIX single-quote escaping using nested quote text.
- No matching code or source data was reached.
- Repair: production paths fail closed if they contain a literal single quote;
  otherwise the helper emits one simple single-quoted shell argument.  Canonical
  FCP Aphos filenames and the established ED209 paths satisfy this contract.

### Implementation I010 — one-event production pipeline with immediate checkpoint
- Added `tools/run_event.sh` and `tools/run_event_pipeline.rex`.
- One admitted snippet is decoded once per channel, searched against deterministic
  source-ID shards through ooRexx-generated close-neighbour probes, globally
  merged, refined through 6 landmark trajectories x 3 nearby offsets per channel,
  reranked with both `MLPatternHash` and dev10 `MLTemporalPatternHash`, and then
  FC/FD joined when stereo.
- A completed event is atomically committed as `<event>.result.tsv`; there is no
  campaign-wide delay before the first result exists.
- Default refinement budget is at most 18 bounded source-window decodes/channel;
  ambiguous events can be widened later rather than charging that cost to every
  query unconditionally.

### Evidence E013 — first complete event checkpoint through new architecture
- Executed the production runner against the native fixture using a canonical
  `evt_000001.wav` query, 3-source CSR and two source shards.
- The pipeline completed and atomically wrote an 18-candidate result TSV.
- Top candidate was source 1 / FC; every row retained pattern, temporal, landmark,
  source name, wall-clock millisecond and window-shift evidence.
- This proves the executable path reaches a durable per-event checkpoint before
  any 671-event coordinator is introduced.

### Implementation I011 — gen3 metadata validation pilot
- Added `tools/validate_gen3_seed.rex`: surviving V9 metadata is comparison
  evidence only and does not feed ranking.  It derives the expected canonical
  original name and V9 snippet start (`event.start - 2 s`) and reports MATCH,
  TIME_ONLY, SOURCE_ONLY or MISS for the new locator's top result.
- Added `tools/run_pilot_ed209i.sh`.  Default is eight sequential
  `gen3_current801` snippets, because those have surviving V9 metadata and can
  therefore provide immediate production validation while the new acoustic path
  remains independent of the seed.
- The pilot writes one event result at a time plus append-only `pilot_summary.tsv`.

### Repair R022 — exact CSR posting budgets now fail closed
- The inherited native CSR reader previously stopped emitting a bucket after
  `max_per_key` matching postings.  That could silently remove valid evidence.
- The provider now raises `exact posting bucket exceeds max_per_key` on the first
  additional in-shard posting beyond the declared bound.
- ooRexx remains responsible for choosing the budget; native code may enforce it
  but may not silently truncate to satisfy it.

### Failure F022 — stereo global-top lists could erase the opposite feed
- The first complete two-channel fixture run reached the FC/FD join but found no
  agreeing pair.  Both channel-local global top lists were dominated by the same
  feed; opposite-feed evidence existed but had been discarded before joining.
- This is a real production-shape defect, not a stereo-policy failure.
- Repair: `AudioV9LandmarkWorker~locate` now accepts an ooRexx-authorized source-ID
  set and filters evidence before candidate ranking.  Stereo execution performs
  feed-specific searches/reranks for both channel assignments and joins only
  after each feed has retained its own bounded candidate set.
- Added `AudioV9StereoJoiner~joinOrNil` so the coordinator can evaluate both
  channel/feed assignments without weakening the existing fail-closed `join` API.

### Recovery F023 — prior unsealed dev4 source was not present in recovered artifact state
- On continuation, the filesystem contained the earlier dev4 progress/document
  files but not the unsealed I007/I008 source tree; the last complete executable
  source artifact available was sealed dev3.
- Recovery therefore rebased dev4 from exact sealed dev3 bytes, migrated them to
  dev10 and reapplied only code that could be reimplemented and requalified in
  this run.
- I007/I008 remain historical progress records from the lost unsealed working
  tree; they are **not claimed as delivered features of this recovered dev4**.
- Production campaign manifest/journal orchestration is deferred to dev5.  The
  dev4 seal target is deliberately the observable one-event/pilot execution path
  needed to obtain live ed209i evidence now.

### Failure F024 — generic dev10 neighbour enumeration made the worker non-viable
- Final combined qualification passed the first 13 dev4 tests, then the 120-second
  harness killed `test_native_worker_end_to_end` while repeatedly executing
  `MLCloseHashSchema~difference` from generic `neighbourKeys()` calls.
- This is a performance failure of the locator integration, not an ML semantic
  mismatch: roughly 532 query landmarks each asked the generic object-heavy
  radius-1 enumerator to construct/sort the same relative 3-D neighbourhood.
- Production cannot accept "raise the timeout" as a repair because the same path
  would multiply across 671 snippets and distributed shards.

### Repair R024 — ML-derived close-neighbour stencil
- `AudioV9LandmarkProbePlanner` now builds the relative `(dt,f1,f2)` probe stencil
  once at construction time.
- Every relative probe's `MLCloseHashDifference` is still computed by authoritative
  dev10 `MLCloseHashSchema~difference`; the locator does not duplicate or redefine
  significance scoring.
- Per-landmark work is reduced to integer coordinate addition, range admission,
  exact packed-address formation and reuse of the ML-derived difference object.
- Boundary coordinates skip only out-of-range relative probes.  The declared
  `maxProbeBuckets` budget remains fail-closed.
- A reference-equivalence test is required before this optimization is accepted.

### Failure F025 — optimized probe planner changed public probe ordering
- After R024, the complete suite reached `test_native_multiprobe_authority` and
  found that the optimized planner returned a near bucket before the exact bucket.
- The admitted bucket set and every ML-derived difference were already equivalent,
  but dev10 `neighbourKeys()` also guarantees difference-score/key ordering.
- Repair: after cheap stencil application, sort the at-most-27 final probe objects
  with dev10 `MLProbeKeyComparator`.  Difference calculation remains precomputed;
  only the public ML ordering contract is restored per landmark.

### Evidence E014 — dev4 combined qualification after R024/R025
- Final locator suite under exact ooRexx 5.3.0 r13196:
  `PASS ALL Audio V9 Pattern Locator v0.1-dev4 TESTS (25 files)`.
- Total suite elapsed time: 20.43 s; maximum observed RSS from the harness run was
  about 68 MiB.
- Complete supplied ooRexx ML v0.1-dev10 suite: 57/57 PASS in 9.75 s.
- Foreign Runtime v0.22.6 base native boundary: 128 assertions PASS.
- Strict native provider rebuild passes `-std=c11 -O3 -Wall -Wextra -Werror`;
  rebuilt provider SHA-256 is
  `b96bfd0696807eb0321f9d184f08a53fdb2a3f717af1e852ed7beda30da25567`.
- Exact r13196 `rexxc` passes all four delivered locator `.cls` files plus
  `run_event_pipeline.rex` and `validate_gen3_seed.rex`.

### Next N006 — clean-byte dev4 seal then live ed209i pilot
- Rebuild the package manifest from final source/documentation bytes, excluding
  generated run state.
- Clean-extract the candidate ZIP, verify the manifest, rerun all 25 locator tests,
  strict native rebuild and all six r13196 compiles from those extracted bytes.
- If green, seal dev4 and run an eight-event `gen3_current801` pilot on ed209i.

### Evidence E015 — candidate ZIP clean-reextract qualification
- Candidate ZIP SHA-256 before evidence reseal:
  `3fc8474d5b60c633d44b01259a1ee1635c380fe846f805a94b7dd67710b122f6`.
- Clean extraction verified every one of 90 candidate `MANIFEST.sha256` entries
  before running any generated tests/builds.
- From those extracted bytes:
  - locator suite: 25/25 PASS;
  - complete embedded ooRexx ML dev10 suite: 57/57 PASS;
  - embedded Foreign Runtime native boundary: 128 assertions PASS;
  - strict native provider rebuild PASS with SHA-256
    `b96bfd0696807eb0321f9d184f08a53fdb2a3f717af1e852ed7beda30da25567`;
  - exact r13196 `rexxc` PASS for all four `.cls` files and both production Rexx
    entry points.
- Candidate-clean evidence files are retained under `qualification/CLEAN_CANDIDATE_*`.
- Final reseal changes documentation/manifest evidence only; source/native/runtime
  dependency bytes are unchanged.  A final clean extraction is still required
  before the release hash is reported.

## P005 / F026 — Production CSR stop-bucket policy (2026-09-09)

Live ed209i dev4 evidence reached the exact CSR lookup but failed closed on the salvaged v0.2 index: 17,009,216 postings, largest hash bucket 271,337 postings, and 419 global buckets above the dev4 4,096-posting ceiling. Increasing source sharding to 64 did not resolve the failure, proving that some individual source streams contain more than 4,096 repetitions of low-information landmark hashes.

Decision: do not raise the posting ceiling. Treat globally overfull exact hash buckets as explicit non-discriminating **STOP buckets**. Admission is based on the global CSR bucket population (`offsets[h+1]-offsets[h]`) before source-shard filtering, so every distributed shard makes the same deterministic keep/skip decision. Native code does not decide similarity: ooRexx supplies the exact authorized bucket keys and the maximum globally admissible postings per exact bucket. Native returns bucket decisions plus postings only for USE buckets.

Fail-closed requirements:
- no silent truncation remains permitted;
- STOP bucket counts are returned as evidence;
- worker requires a minimum number of informative/USE probe hashes;
- worker refuses a query if the STOP fraction exceeds policy;
- existing `lookupExactPacked` retains its strict fail-on-overfull behavior for diagnostics/qualification.

This is deliberately analogous to a stop-word policy in an inverted text index: an extremely common landmark is weak location evidence and must not force enumeration of hundreds of thousands of postings.

### F028 — combined qualification harness timeout

A single outer 300-second command chained ML, Foreign Runtime, locator, native, runtime-rebuild and compile qualification. ML completed 57/57 and Foreign Runtime completed 128 assertions. The outer harness then expired while the locator suite still owned a temporary extracted Foreign Runtime; timeout cleanup removed that directory and the in-flight Rexx process reported an `Unable to load library "foreign_runtime"` error. This is not accepted as a semantic/runtime failure because it was induced by harness teardown. Repair: run each qualification surface independently with its own timeout and capture.

## P006 — Overlapping spectral field as shared locator/echo/segmentation evidence (2026-09-09)

Architect observation: track robust mid-band intensity `N(X,t)` over time for overlapping spectral bands X. Promote this from a locator-only experiment to a shared evidence surface.

Decision:
- Build an overlapping spectral field from each admitted audio window.
- For every frame/band retain robust distribution evidence rather than a single peak: low/median/high band log-intensity, plus interquantile width.
- Normalize each band independently over time so absolute gain and much static spectral coloration are evidence, not identity.
- Preserve raw band statistics alongside normalized values; normalization must not erase provenance.

Three semantic consumers share the same field:
1. **Location**: `MLPatternHash` / `MLTemporalPatternHash` compare per-band level, movement and turn geometry. Sparse landmarks/CSR are demoted to coarse anchors.
2. **Echo track**: search for the same multi-band trajectory at positive lag. A coherent lag across several overlapping bands is echo evidence. Per-band affine normalization tolerates frequency-dependent echo attenuation; dev10 temporal TIME_GAP/ELEVATION/TURN evidence retains local delay. Multiple coherent lags remain separate echo tracks.
3. **Scene segmentation**: classify structure evidence, not semantic speech identity. Stationary/background regions have low normalized slope/turn, stable band widths and repeated/common shapes. Continuous speech-like structure has sustained but non-stationary coordinated multi-band movement, spectral-centre motion and syllabic-rate modulation. Semantic label `speech` remains a later evidence/classification decision.

Reassembly boundary:
- Spectral-field magnitude trajectories do **not** contain waveform phase and therefore cannot themselves reconstruct audio.
- Echo tracks may authorize extraction/alignment of the corresponding real waveform windows. Reassembly combines/compares those aligned waveform observations; it must retain source path, delay, band evidence and alignment provenance.
- Never manufacture missing waveform samples from the pattern hash.

Distribution requirement:
- spectral-field extraction is deterministic/native measurement and may run on any ED209 worker;
- ooRexx ML owns normalization policy, pattern/temporal comparison, echo-track admission and segmentation semantics;
- workers return evidence objects/TSV only; coordinator decisions must remain placement-independent.

Next implementation target I010:
- native overlapping-band field extractor;
- ooRexx field parser/model;
- affine-gain, echo-delay, stationary-noise and speech-like-structure qualification fixtures;
- no production seal until these are green.

## P007 — Human speech anchors in rank_01.wav (2026-09-09)

Architect listening evidence for supplied `rank_01(4).wav`:
- approximately `0..10 s`: faint continuous conversation is present but substantially covered by noise;
- approximately `12 s`: the word **“Wellesley”** is audibly identifiable.

Use these only as **held-out human validation labels**, not as search/matching inputs. The spectral-field implementation must be judged on whether it independently exposes the first interval as continuous structured/speech-like activity and the ~12 s interval as a stronger/localized speech-structure peak.

Qualification implications:
- retain frame-level `N(X,t)` and movement/turn evidence around `0..15 s`;
- compare static/background score against continuous-structured score over `0..10 s`;
- check whether the ~12 s anchor produces stronger cross-band coordinated movement than nearby noise-only spans;
- test echo-track coherence around both the faint conversation and the stronger ~12 s utterance, because a delayed replica may preserve portions obscured in the direct path;
- any later speech label remains evidence-backed; do not use the human word label to tune candidate location or fabricate transcription.

This audio becomes a real-world regression fixture for I010 in addition to synthetic affine/echo/static/speech-like fixtures.

## P008 — Human clear-speech anchor and noise-residual pattern hypothesis (2026-09-09)

Architect listening evidence for supplied 180-second `rank_01(4).wav` adds a high-SNR speech anchor:
- approximately `72 s` into the clip (wall-clock about 09:44:42 for the 09:43:30 campaign window): clear speech over the CCTV speaker.

Use as a third held-out validation point alongside P007, not as an extraction/matching input.

Hypothesis to qualify:
- decompose each overlapping spectral-band trajectory into a slowly varying/local background field B(X,t) and residual structured motion R(X,t)=N(X,t)-B(X,t);
- faint/noise-covered speech and clear speech need not share absolute intensity, but should share the *class of coordinated multi-band movement*: persistent cross-band slope/turn activity, spectral-centre travel, modulation and local temporal structure;
- background/noise motion may vary by band and time, but should be less coherent across adjacent overlapping bands and less consistent under delayed-copy/echo tests;
- compare the 0..10 s noise-covered conversation, ~12 s “Wellesley” anchor, and ~72 s clear CCTV-speaker speech using the same blind field features and normalization policy;
- qualification succeeds only if the held-out labels are explained by measured evidence after extraction, not encoded into thresholds beforehand.

Echo implication:
- if the same speech motion is partially masked in the direct field, coherent delayed replicas may remain visible in subsets of bands;
- echo-track alignment may therefore recover correspondence across the masked and unmasked portions, after which any reconstruction must return to the real waveform windows as stated in P006.

## P009 — Separate vocal structure from CCTV transmission-channel profile (2026-09-09)

Architect observation: the clear ~72 s CCTV-speaker speech can provide a strong reference for the acoustic path, and a second speaker sample may contain related vocal structure.

Design boundary:
- model `TRANSMISSION_CHANNEL_PROFILE` separately from `SOURCE_VOICE_PROFILE`;
- CCTV loudspeaker/channel evidence may include stable frequency-response coloration, resonances, compression/limiting, distortion, room/echo geometry and band-specific attenuation/boost;
- vocal-structure evidence may include formant movement, pitch contour, syllabic rhythm, spectral-centre movement and cross-band slope/turn structure;
- do not allow channel similarity to masquerade as source-voice similarity;
- use source-voice evidence only for anonymous acoustic similarity/clustering and never as proof of a real person's identity;
- the clear ~72 s CCTV speech is suitable for estimating the transmission/channel profile, which can then be searched elsewhere to strengthen weak speech evidence passing through the same path;
- where comparing another speech sample, first factor out as much estimated transmission-channel coloration as possible before evaluating non-identifying vocal-pattern similarity.

I010 implication:
- extract both a channel/device signature and residual vocal-structure field from the same overlapping-band representation;
- qualify channel-profile recurrence independently of vocal-content recurrence;
- add a negative test where two different source signals passed through the same synthetic channel must match strongly on channel profile but not on source-vocal structure.

## P010 — Two-speaker telephone calibration corpus with transcript (2026-09-09)

Architect supplied:
- `Did_you_threat_to_break_in_AI_Master(1).ogg`: 55.168 s, mono, 8 kHz Vorbis telephone-band recording;
- `Did_you_threat_to_break_in_FINAL.txt`: timestamped transcript with transcript labels `Dyer` and `Lee`, including overlap;
- user-supplied real-world label mapping: Thomas = transcript label Dyer; Mr Benji Lea = transcript label Lee. Treat that mapping as human metadata, not as an identity conclusion from audio.

Observed audio envelope:
- approximately 1.6 s of low-level lead-in before sustained speech activity;
- transcript timestamp span is 20:58:23..20:59:12 (49 s), consistent with ~1.6 s lead-in and several seconds of trailing material/silence in the 55.168 s file;
- use `audio_offset ~= 1.6 + (transcript_timestamp - 20:58:23)` only as an initial alignment seed; refine from acoustic boundaries before using as qualification truth.

Why this corpus matters for I010:
1. clean two-speaker speech gives a real positive fixture for `CONTINUOUS_STRUCTURED` / speech-like multi-band movement;
2. labelled alternating turns let us test whether anonymous vocal-structure profiles cluster by speaker *within this recording* without using names as acoustic input;
3. overlap at transcript times 20:58:35 and 20:59:05 is a deliberate mixture test: the field should show superposed/coincident structure rather than forcing one speaker label;
4. telephone bandwidth and codec/channel effects provide a useful contrast with the CCTV transmission-channel profile;
5. channel/device profile and source-vocal profile remain separate. Any cross-recording comparison may report anonymous acoustic similarity/consistency only, never real-person identity proof.

Calibration deliverable:
- `reference/TWO_SPEAKER_PHONE_CALIBRATION.tsv` records transcript-relative event anchors and explicit overlap rows;
- speaker labels in that file are transcript/human metadata used only for post-extraction evaluation;
- spectral-field extraction, clustering and similarity must run blind to those labels.

## P011 — El Rehab stationary-background calibration fixture (2026-09-09)

Architect supplied `elrehab_example.ogg` as a real-world example containing a quiet air-conditioning hum in the background. Treat the AC attribution as human provenance; the acoustic measurements below are independent observations from the file.

File observations:
- 47.993651 s, stereo, 44.1 kHz Vorbis;
- long-term low-frequency spectrum contains a strong approximately harmonic stack near 43.1 Hz, 86.1 Hz, 129.2 Hz and 172.3 Hz;
- using 2 s windows with 0.5 s hop and estimating the fundamental from harmonics 2..4 gives median fundamental approximately 43.291 Hz with temporal standard deviation approximately 0.154 Hz across 92 windows;
- median narrow-ridge levels for the first three harmonics vary only about 1.3..2.1 dB across those windows, making this a useful stationary/recurrent spectral-field fixture rather than a one-frame tone example;
- stereo magnitude-squared coherence is high at several of those ridges (approximately 0.89 at 43 Hz, 0.76 at 86 Hz and 0.97 at 129 Hz), while nearby 50 Hz is much less coherent in this recording. Do not relabel the observed 43-Hz family as mains hum; preserve the measured frequencies.

I010 / Spectral Pattern Field qualification use:
- the overlapping boxes covering the 43-Hz harmonic family should exhibit high recurrence, low ridge-frequency motion, low turn density and a strong STATIC_BACKGROUND / SLOWLY_VARYING_BACKGROUND tendency;
- speech or other foreground structure should appear as residual coordinated movement across neighbouring boxes without requiring removal of the stationary field from the original waveform;
- this fixture is particularly useful for testing whether slow background estimation B(X,t) follows the persistent harmonic field while residual R(X,t) preserves transient/continuous foreground structure;
- box recurrence and cross-channel coherence are evidence dimensions, not instructions to suppress or delete the background;
- retain this fixture alongside synthetic hum/noise tests so production thresholds are not calibrated solely from generated audio.

### F026 — `::options numeric digits 30` is not accepted by the pinned r13196 runtime
User suggested replacing method-local precision guards with package directive `::options numeric digits 30`. Tested directly against the pinned `/mnt/data/oo53/usr/local/bin/rexx` (ooRexx 5.3.0 r13196). The directive is rejected at translation with Error 25.935: `NUMERIC` under `::OPTIONS` must be followed by `INHERIT` or `NOINHERIT`; `DIGITS` is not an admitted subkeyword in this runtime. `::options numeric inherit/noinherit` do not establish a 30-digit context for methods; an empirical required-package test still entered methods at DIGITS 9 and rounded `1696928003123` to scientific 9-digit precision. Therefore dev5 must retain explicit `numeric digits 30` before numeric conversion in precision-sensitive methods. `EXPOSE` remains first where required by ooRexx syntax; `numeric digits 30` follows EXPOSE and precedes `USE STRICT ARG`/arithmetic where needed. This is a runtime-compatibility finding, not a rejection of the desired package-wide semantic; if a later ooRexx head adds `::options numeric digits`, adopt it after qualification.

## P012 — Package-wide numeric inheritance contract qualified on r13196 (2026-09-09)

Architect supplied the correct ooRexx mechanism to avoid repeating `numeric digits 30` in every method: establish the numeric context in the executable caller and declare `::options numeric inherit` for the class package.

Exact r13196 experiments refine the mechanism as follows:
- `::options numeric digits 30` is indeed invalid on this runtime (F026 remains correct on that narrow point);
- a required class file prologue containing `numeric digits 30` executes at DIGITS 30, but that numeric setting does **not** leak back into a later arbitrary caller; a caller left at the default DIGITS 9 invokes an inherited method at DIGITS 9;
- when the executable caller establishes `numeric digits 30`, a method in a package declared `::options numeric inherit` enters at DIGITS 30;
- the inherited 30-digit context propagates through nested method calls, including calls into another required class package also declared `::options numeric inherit`.

Dev5 implementation:
- all 5 delivered `.cls` packages now declare `::options numeric inherit`;
- all 37 executable/test `.rex` entrypoints establish `numeric digits 30` once at entry;
- existing method-local precision guards are retained temporarily as harmless defence-in-depth at sensitive public numeric boundaries until the full spectral-field iteration is stable; they are no longer required for normal locator call paths;
- added `tests/test_numeric_inherit_contract.rex`, asserting method-context DIGITS 30, exact 30-digit `1/3`, and a non-collapsing 100-ms difference between 13-digit epoch-millisecond values.

Qualification on `/mnt/data/oo53/usr/local/bin/rexx` / `rexxc` (ooRexx 5.3.0 r13196):
- 5/5 locator class sources compile;
- focused numeric-inheritance regression PASS;
- full Audio V9 Pattern Locator dev5 suite PASS: 30/30 files.

Harness note: an initial full-suite invocation failed because the surrounding shell did not have the pinned ooRexx bin directory on `PATH`; rerunning with `/mnt/data/oo53/usr/local/bin` explicitly prepended passed unchanged. This was an execution-environment issue, not a semantic test failure.

## I011 — Moving time-frequency box lattice is executable (2026-09-09)

Implemented the Architect's moving-box model directly in `AudioV9SpectralField.cls`.

Each `AudioV9SpectralBoxEvidence` is a bounded overlapping time-frequency box with:
- time start/end and exact overlapping spectral band geometry;
- robust mid-band (`q50`) graph through the box;
- frame-common-mode residual graph (`q50_band - mean(q50_all_bands)`), retaining the original field unchanged;
- local baseline, range, motion, residual motion, turn magnitude, active fraction and q75-q25 width evidence;
- separate `MLPatternHash` objects for the mid-band and residual graphs;
- temporal order is authoritative: the box schema uses `rotationInvariant=.false` and `reversalInvariant=.false`.

Synthetic field qualification:
- stationary hum/noise box residual motion approximately `0.34648 dB`, turn approximately `0.48752 dB` after bounded smoothing;
- structured synthetic speech residual motion approximately `1.01497 dB`, turn approximately `0.73398 dB`;
- affine-gain synthetic speech has residual `MLPatternHashDifference dominant=0 total=0` against the unamplified speech;
- moving lattice test confirms successive 1 s boxes overlap at 500 ms and contain all 29 voice-profile bands.

The smoothing is deliberately applied to the *box graph*, not to the stored native field frames. It removes frame-local random noise while preserving speech/echo-scale movement evidence.

## F027 — production field parser was quadratic (2026-09-09)

The first real 180 s campaign run exceeded the qualification timeout while parsing the native spectral-field text. Root cause was repeated `SUBSTR()` over the entire remaining multi-megabyte record stream in `AudioV9SpectralField~init`, causing effective O(n^2) copying.

Repair:
- split the native record stream once with ooRexx `String~makeArray('0A'x)`;
- iterate records linearly;
- no change to measurement or similarity semantics.

Synthetic box test wall time fell materially (approximately 8.9 s to 3.6 s in the same local environment after the subsequent indexing repair as well).

## F028 — analyzers rescanned the complete field for every time window (2026-09-09)

After F027, the first real 180 s run exposed a second scale defect: `summarize()` and `box()` selected local frames by scanning every frame in the complete field. A 180 s recording therefore created nested whole-field scans for every segment and every spectral box.

Repair:
- `AudioV9SpectralField~frameBounds(start,end)` computes direct bounds from the uniform hop timeline and validates the exclusive end against actual frame milliseconds;
- cross-band common q50 is cached once per parsed frame (`commonQ50At`) instead of recomputed for every box/band;
- segment and box analyzers touch only the frames inside their requested time window.

This is also the correct distributed data model: a time shard can be measured and interpreted without requiring an all-recording object graph.

## I012 — bounded Spectral Pattern Field sharding / immediate checkpointing (2026-09-09)

Added:
- `tools/analyze_spectral_field.rex` — produces segment, box and summary evidence from a bounded 8 kHz float window;
- `tools/run_spectral_field.sh` — deterministic decode + one bounded field report;
- `tools/run_spectral_field_chunked.sh` — replayable time-shard execution with global timestamp rebasing and immediate per-shard files;
- `tools/compare_spectral_fields.rex` — box-for-box ML structural comparison plus movement/turn correlation.

Production doctrine is now consistent with the distributed locator: do not build one opaque 180 s in-memory field and wait for a campaign-wide answer. Build bounded field shards (15 s used for the current pilot), checkpoint each immediately, and rebase evidence onto the global time axis. Boxes/segments do not currently cross shard boundaries; that boundary is explicit in the generated summary rather than hidden.

## F029 — ooRexx comparison tool assumed a `SQRT` built-in (2026-09-09)

The first movement-correlation implementation called `sqrt()` as a Rexx routine; r13196 correctly raised Error 43 because no such built-in routine exists in the selected environment. Repaired without adding a dependency by using a bounded 30-digit Newton square-root routine inside the tool. This failure occurred in the evidence/report tool, not in locator semantics.

## E013 — real Spectral Pattern Field evidence checkpoint (2026-09-09)

Evidence file: `qualification/SPECTRAL_PATTERN_FIELD_REAL_DEV5.txt`.

Real campaign raw source was decoded from the supplied 09:40:30..09:49:30 master at offset 180 s (the 09:43:30..09:46:30 campaign window). Human annotations were applied only after blind field extraction.

Campaign raw 0..15 s:
- 467 field frames, 29 overlapping voice bands;
- 28 overlapping 1 s scene segments;
- 812 1 s moving boxes;
- mean residual box movement `0.4550301022 dB`;
- mean box turn `0.6116780742 dB`.

Campaign raw 60..75 s (contains human clear-speech anchor near global ~72 s):
- same 467/29/28/812 geometry;
- mean residual box movement `0.4419050479 dB`;
- mean box turn `0.6032860006 dB`.

Human-anchor post-hoc aggregates:
- faint/noise-covered conversation 0..10 s: shape motion `0.453084505716`, shape turn `0.609153570856`, active fraction `0.282421208750`;
- "Wellesley" region ~11..13.5 s: shape motion `0.460182554889`, shape turn `0.625308845612`, active fraction `0.286377456433`;
- clear CCTV speech ~71..73.5 s: shape motion `0.463056260653`, shape turn `0.636806699457`, active fraction `0.300415276233`.

Interpretation: the faint and clear CCTV speech regions are not cleanly separable by a scalar movement threshold. That is useful negative evidence: dev5 must use recurrence/shape structure across boxes rather than tune thresholds to the human labels.

The labelled two-speaker telephone fixture (55 s, processed in four bounded shards) is a strong positive structured-speech contrast:
- `CONTINUOUS_STRUCTURED` segments: 80;
- `TRANSIENT_STRUCTURED` segments: 22;
- `MOVING_STRUCTURED_BOX`: 1597;
- `MIXED_BOX`: 1342;
- `SLOW_BOX`: 19.

El Rehab low-frequency fixture (first 45 s measured in three 15 s shards) retains stable low-band baselines despite foreground variation. With the current LOW profile:
- band centred 100 Hz baseline mean approximately `-56.188 dB`, temporal box-baseline standard deviation approximately `0.471 dB`;
- band centred 160 Hz baseline mean approximately `-61.031 dB`, standard deviation approximately `0.422 dB`.
This is retained as background-field evidence; it does not replace the previously measured narrow 43/86/129/172 Hz ridge evidence.

Most important real invariance result: compare supplied raw campaign 0..15 s with supplied processed `rank_01` 0..15 s, same timeline, 812 corresponding boxes:
- exact residual pattern hash fraction only `0.0012315` (heavy filtering/recovery legitimately changes literal quantised hashes);
- mean ML dominant box-pattern difference `34.4089`;
- **residual movement correlation `0.9898689573233826`**;
- **turn-geometry correlation `0.9871238635303846`**;
- mean absolute residual-motion delta only `0.008507 dB`;
- mean absolute turn delta only `0.013902 dB`.

Conclusion: literal hash equality is too brittle under the recovery chain, but the *movement geometry of the overlapping boxes* is exceptionally well preserved. Dev5 therefore proceeds to significance-ordered recurrence/echo matching over box movement rather than making exact pattern keys authoritative.

## F030 — distributed shard worker used literal `\\t` as POSIX shell IFS (2026-09-09)

The first executable spectral-shard worker failed before DSP with `malformed manifest row`. Root cause: `IFS='\\t'` in POSIX `sh` is a backslash and letter `t`, not a tab byte. Repair uses `tab=$(printf '\\t')` and assigns that actual byte to IFS. Manifest/schema semantics unchanged.

## F031 — final distributed shard used raw PCM duration rather than valid field duration (2026-09-09)

The first local-vs-distributed Spectral Pattern Field equivalence run produced one extra final 9000..10000 ms box/segment on the 10 s fixture. The monolithic native field only contains FFT frames whose complete 1024-sample windows fit, so its authoritative field duration is `frameCount * hop` (for inputs >= NFFT), not raw PCM sample duration. The worker incorrectly used `totalSamples/sampleRate` when deciding whether a globally owned box was complete. Repair adds `fieldDurationMs` to `AudioV9SpectralWorkUnit` and gates all emitted windows against that exact global analysis duration. No thresholds or pattern semantics changed.

## I013 — globally phase-preserving distributed Spectral Pattern Field (2026-09-09)

Implemented deterministic multi-node time sharding for the moving-box field.

The critical invariant is global FFT phase. A worker is never allowed to start an independent spectral grid at an arbitrary wall-clock boundary. The coordinator first pins one canonical 8 kHz float32 master by SHA-256. `AudioV9SpectralShardPlanner` then creates immutable work units whose sample starts are rounded down to the global 256-sample / 32 ms hop phase and whose right context includes enough samples to finish every window owned by the core plus a complete 1024-sample FFT frame.

Ownership is by *global box/segment start time* in a contiguous core interval. Workers may read right-hand context from the next core but cannot own its starts. This means an overlapping box crossing a shard boundary is computed once, with the same global frames that a monolithic run would have used.

Added:
- `src/AudioV9SpectralDistribution.cls`;
- `tools/plan_spectral_field_shards.rex` + shell wrapper;
- `tools/run_spectral_field_shard.sh`;
- `tools/analyze_spectral_field_shard.rex`;
- `tools/merge_spectral_field_shards.rex` + shell wrapper;
- `tests/test_spectral_field_distributed_equivalence.rex`.

Each manifest row pins the canonical master SHA-256, total samples, core milliseconds, exact work sample range, profile, box/segment geometry, sample rate, hop and NFFT. Workers recompute the master SHA-256 before extracting their sample window. The coordinator requires every planned result and verifies core ownership, window length, step alignment, complete band columns and duplicate-free keys before merge.

## E014 — one-node/distributed field exact equivalence (2026-09-09)

On the 10 s structured-speech fixture:
- monolithic field: 18 one-second/500 ms-step segment rows and 522 one-second/500 ms-step spectral boxes;
- distributed field: four 2.5 s cores, executed deliberately in arrival order 3rd, 1st, 4th, 2nd;
- merged `segments.tsv`: byte-for-byte identical to monolithic;
- merged `boxes.tsv`: byte-for-byte identical to monolithic, including ML pattern keys and 30-digit evidence values;
- wrong canonical-master SHA-256: fail closed before shard extraction;
- missing unit result: fail closed at coordinator merge.

This establishes that node count and worker completion order are not semantic inputs to the Spectral Pattern Field.

Frequency-band sub-sharding is deliberately not yet made independent: every residual box uses the per-frame common q50 across the complete band field. A future second-stage band shard must therefore consume a pinned shared common-mode vector/field artifact rather than recomputing "background" from only its local bands. Time sharding is already exact and provides enough parallel work for the current campaign and V9 corpus.

## F032 — outer qualification command wall-clock cap interrupted whole-suite transcript (2026-09-09)

Two attempts to capture all dev5 tests in one container command were terminated by the surrounding execution harness after the suite had already progressed deep into the ordered test set. The first interruption occurred while a temporary dependency tree was being torn down and therefore surfaced a misleading `MLConstraints.cls not found`; the second stopped before the final temporal/window tests. No individual semantic regression failed.

Repair/qualification method: run the exact same `tests/test_*.rex` set as two deterministic halves, 16 files each, under the same pinned r13196/ML dev10/Foreign Runtime environment. Both halves passed. The package `run_tests.sh` remains a complete one-command suite for hosts without this chat execution cap. The interrupted transcript is retained as `qualification/ITERATION5_DISTRIBUTED_SUITE_TIMEOUT.txt` and is not acceptance evidence.

## E015 — dev5 pre-seal distributed qualification (2026-09-09)

- locator tests: 32/32 PASS as two complete 16-test halves;
- ooRexx ML v0.1-dev10: 57/57 PASS;
- Foreign Runtime v0.22.6 base native boundary: 128 assertions PASS;
- native provider strict rebuild PASS; SHA-256 `fcd44f1db808a9d163c778020de6044abcea61a6916c925bfb3505aa08d99284`;
- exact r13196 `rexxc`: 18/18 delivered class/tool sources PASS;
- distributed Spectral Pattern Field: 4 shuffled workers merge byte-for-byte identically to one-node 10 s fixture; wrong-master and missing-unit cases fail closed.

Dev5 is ready for candidate packaging and clean-byte qualification.

## E016 — dev5 clean candidate qualification (2026-09-09)

Candidate ZIP SHA-256: `e1285280149628db15581eb261ac5b139cc40d583ffb54dff17d4634b3e210d2`.

From a new extraction of the candidate bytes:
- 133/133 manifest entries verified before generated runtime/test state;
- locator suite: 32/32 PASS as 16 + 16 complete deterministic halves;
- ooRexx ML dev10: 57/57 PASS;
- Foreign Runtime v0.22.6 base native boundary: 128 assertions PASS;
- native provider strict rebuild PASS, SHA-256 `fcd44f1db808a9d163c778020de6044abcea61a6916c925bfb3505aa08d99284`;
- exact r13196 `rexxc`: 18/18 delivered class/tool files PASS.

Clean-candidate transcripts are retained under `qualification/CLEAN_CANDIDATE_*_DEV5.txt`. The package is now resealed once so those records are part of the delivered artifact; final-byte manifest and qualification are performed after that reseal.

## I011 / P012 - dev6 inter-box graph branch (2026-09-09)

- Branch source is the sealed `audio_v9_pattern_locator_v0.1-dev5.zip`, SHA-256 `69adf235508a362094f5240f6d32eeb2e9b6129bf536f61fdb418360c0b5cf56`; dev5 remains untouched while ed209i qualifies it.
- dev6 semantic target is the graph between Spectral Pattern Field boxes, not another intensity threshold layer.
- Planned edge families are explicit evidence, not a scalar: same-band temporal continuation, adjacent-band same-time relation, diagonal spectral migration, and bounded delayed recurrence.
- Distributed authority rule: an edge is owned by the worker that owns the source box start. Halo boxes may be read as targets but may not create duplicate ownership.
- MLPatternHash remains the authority for local graph-shape difference; the graph layer records its significance-ordered difference evidence rather than inventing a replacement score.
- Fine echo work will use small boxes / 32 ms steps; medium speech/phrase work can retain larger boxes. Multi-scale graphs remain separate evidence layers.

## P013 — graph-as-instrument-panel / renderer remains non-authoritative (2026-09-09)

The Architect clarified that dev6 graph functionality is not merely an output format: it is the primary diagnostic/qualification surface for verifying that the moving spectral boxes and their relationships are actually behaving as intended.

Graph rendering therefore becomes a first-class dev6 evidence requirement, with a strict authority boundary:
- Audio V9 Spectral Pattern Field + MLPatternHash / MLTemporalPatternHash remain semantic authority;
- inter-box edge objects retain exact evidence and are authoritative inputs to later reasoning;
- graph layout, projection, SVG/UI presentation and visual emphasis are renderer/evidence concerns only and may never create, remove or reclassify semantic edges;
- distributed shard boundaries must be visually inspectable but must disappear semantically after merge.

Diagnostic projections required for dev6:
1. **time × spectral-band field** — every box located by global time and band centre, with box motion/turn/active evidence available for inspection;
2. **continuation/migration graph** — same-band temporal continuation plus adjacent-band / diagonal spectral movement;
3. **delayed-recurrence graph** — recurrence edges labelled with exact delay and ML difference evidence, intended to make coherent echo tracks visible;
4. **shard provenance overlay** — optional worker/core ownership metadata, purely diagnostic, to expose duplicate/missing boundary errors;
5. **multi-scale view** — fine (32 ms / small-box) echo evidence and medium speech/phrase evidence remain separate layers rather than being collapsed into one visual score.

Existing ooRexx ML Graph remains a renderer/evidence component rather than ML semantic authority. Dev6 will export deterministic graph evidence suitable for that renderer; no graph renderer may redefine what counts as a close pattern, recurrence, echo, or speech-like structure.

## P015 — 2026-09-09 — Live dev5 vote-budget finding isolated from graph branch

The sealed dev5 pilot on ed209i passed global CSR STOP-bucket handling but failed closed on `evt_000074` at the subsequent 250000 landmark vote ceiling. This is a candidate-generation scaling defect, not graph semantics. It has been repaired separately as `audio_v9_pattern_locator_v0.1-dev5-hotfix1.zip` using deterministic whole-hash pair budgeting (`globalPostingCount * queryReferenceCount`) before posting expansion. dev6 remains based on sealed dev5 until that hotfix is proven live; after live acceptance, the worker/provider repair will be forward-ported without altering graph semantics.

## P014 / I014 — dev11 contextual wobbliness integrated into the inter-box graph (2026-09-09)

The Architect supplied exact `oorexx_ml_v0.1-dev11(1).zip`, SHA-256 `713c4998c67aed9b526f3e20f7b2f14de4b355939259bff55beebe9133980c79`.

This corrects the earlier speculative use of “wobble” as generic local jitter. Dev11's authoritative semantics are retained intact: a wobbly observation is contextual to an **active fit model**. `MLWobbleSetSearch` performs an exact bounded search in increasing exclusion cardinality, stops at the first cardinality restoring fit, retains every minimal restoring set at that distance, reports distance-to-fit / normalized distance / participation, and fails closed on its evaluation bound. Temporary exclusion is diagnostic only and is never permission to delete, dismiss or relabel evidence as noise.

Dependency qualification on exact ooRexx 5.3.0 r13196:
- ooRexx ML dev11: **63/63 PASS**;
- ML Graph dev3 against ML dev11: all seven graph/adapter suites PASS, 53 assertions total;
- existing Audio V9 locator baseline against ML dev11, before graph-specific additions: **32/32 PASS**.

Dev6 now pins:
- `deps/oorexx_ml_v0.1-dev11.zip` SHA-256 `713c4998c67aed9b526f3e20f7b2f14de4b355939259bff55beebe9133980c79`;
- `deps/oorexx_ml_graph_v0.1-dev3.zip` SHA-256 `a4ee63c48eab3ac27166607998071800f32b9af0cf6c3dbba12e08fa6627402a`.

Audio-specific first use is an explicitly declared **single coherent echo-delay hypothesis** over delayed recurrence edges. `AudioV9EchoDelayFitScorer` publishes RMS delay residual; `AudioV9SpectralWobbleAnalyzer` passes those observations to dev11 without inventing a second wobble metric.

Synthetic two-reflection qualification uses six recurrence edges at delays `80,80,80,140,140,140 ms`. Under a one-delay RMS fit criterion it returns:
- distance-to-fit = `3`;
- normalized distance = `0.5`;
- minimal restoring sets = `2`;
- every edge participation fraction = `0.5`.

This is the desired behavior: the model reports two equally minimal coherent explanations rather than declaring either reflection path rubbish. Evidence can later be reassigned explicitly to separate path/source hypotheses.

Added:
- `src/AudioV9SpectralGraph.cls` — explicit graph edge evidence, graph builder, echo-delay fit/wobble adapter, ML Graph adapter;
- stable `AudioV9SpectralBoxEvidence~id` (`BOX|startMillis|bandIndex`);
- `tests/test_spectral_graph_wobble.rex`;
- `qualification/SPECTRAL_GRAPH_WOBBLE_DEV6.txt`.

## I015 — Audio V9 ML Graph diagnostic renderer + first real graphs (2026-09-09)

The generic ML Graph renderer is semantically correct but produces an impractical repeated legend when an inter-box graph is represented as thousands of two-point series. Dev6 therefore adds a downstream Audio V9 renderer rather than changing ML Graph semantics.

`src/AudioV9SpectralGraphRenderer.cls` consumes already-supplied `MLGraph` coordinates/evidence and renders:
- time left-to-right;
- spectral frequency bottom-to-top;
- point radius as presentation-only scaling of published box residual motion;
- grouped edge-kind legend;
- continuation / adjacent-band / diagonal-migration / delayed-recurrence roles;
- `MLWobbleAnalysis` annotations.

It does not create, remove, score or reclassify semantic edges.

`tools/render_spectral_graph.rex` renders field, movement and delayed-candidate SVG views and now emits descriptive box/edge evidence statistics. These summaries report existing ML difference values only; they are not classifier thresholds.

First identical-policy 2 s real comparison (`VOICE`, 1000 ms boxes, 250 ms step): both fixtures have the same topology of 116 boxes / 454 possible relation edges. Their evidence differs:
- telephone: mean residual box motion `1.19593`, mean turn `0.99334`, 41 moving / 1 slow;
- El Rehab: mean residual box motion `0.64241`, mean turn `0.80989`, 24 moving / 17 slow;
- telephone adjacent-band ML total-difference mean `1376.39`, median `1143`;
- El Rehab adjacent-band ML total-difference mean `2962.01`, median `2867.5`.

Initial diagnostic implication only: the phone speech slice moves more locally while neighbouring spectral bands are much more mutually coherent under the same graph policy. This is useful evidence for graph-coordination modelling; it is not promoted to a speech/background classifier.

A 5 s telephone view rendered (464 boxes, 3956 edges, about 18 s). The corresponding 5 s El Rehab presentation exceeded the current surrounding render window after its field/graph evidence was already built. This is retained as a renderer-scaling defect; dev6 will optimize presentation traversal rather than increase timeouts or alter ML semantics.

Evidence: `qualification/REAL_GRAPH_PHONE_ELREHAB_DEV6.txt`.
