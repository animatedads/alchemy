# Audio V9 Pattern Locator v0.1-dev5

Fifth executable ooRexx-authoritative reverse-locator iteration for the
historical FCP Aphos V9 event snippets.

The central rule is unchanged: **ooRexx ML owns what counts as the same pattern
or a close pattern.** Native code and FFmpeg measure and retrieve exact data;
they do not define similarity, chronology or stereo agreement.

## Why this line exists

The earlier Python/CSR locator proved that the existing 17,009,216-posting CSR
can be built and read, but its campaign matching phase became effectively
unobservable and disk-bound.  Dev4 turns that completed CSR into an addressable
posting store behind ooRexx semantics and commits one event result immediately.

The production path is:

```
V9 WAV
  -> decode one channel once to mono 8 kHz float32
  -> native landmark/curve measurement
  -> ooRexx MLCloseNeighbour-authorised probe buckets
  -> exact CSR posting lookup only
  -> bounded landmark trajectories
  -> bounded source-window FFmpeg decode
  -> MLPatternHash shape evidence
  -> MLTemporalPatternHash timing/turn evidence
  -> FC/FD stereo agreement when two-channel
  -> evt_NNNNNN.result.tsv checkpoint
```

There is no campaign-wide delay before the first result exists.


## dev5 additions

Dev5 keeps the dev4 production pipeline and adds three qualified lines:

- deterministic **STOP-bucket** handling for globally overfull CSR hashes: native code returns `USE/STOP` decisions and never silently truncates postings; ooRexx fails closed if the skipped fraction exceeds policy;
- the first executable **Spectral Pattern Field**: overlapping time-frequency bands, robust q25/q50/q75 measurement, moving 1 s boxes, common-mode residual graphs, and `MLPatternHash` objects per box;
- linear native-record parsing and direct time-to-frame bounds so field work scales by local window rather than repeated whole-record scans;
- bounded time-shard runners with immediate segment/box checkpoint files;
- **sample-phase-preserving distributed Spectral Pattern Field execution**: immutable work units pin one canonical 8 kHz float32 master by SHA-256, preserve the global 256-sample/32 ms FFT phase, carry right-hand context for owned windows, and merge fail-closed;
- raw-vs-processed structural comparison tooling.

The supplied real 0..15 s campaign raw window and processed rank-01 output show residual box-motion correlation `0.9898689573` and turn correlation `0.9871238635`. Literal quantised box hashes are much less stable under the recovery chain, so exact key equality is evidence only; movement geometry is the stronger invariant.

## dev4 additions

- ooRexx ML **v0.1-dev10** is the semantic dependency head.
- `MLTemporalPatternHash` adds irregular landmark-event timing evidence alongside
  the existing four-curve `MLPatternHash` evidence.
- one-event production runner with atomic result checkpoint;
- generation-3 pilot runner and independent V9 metadata validator;
- stereo search/rerank performed per feed, considering both channel assignments;
- exact CSR posting budgets fail closed instead of silently truncating evidence;
- optimized ML-derived radius-1 landmark probe stencil;
- the optimized stencil is qualified against dev10 generic `neighbourKeys()` at
  both interior and boundary coordinates;
- distributed source shards and replay-safe landmark evidence remain available
  from dev2/dev3 for later multi-node campaign orchestration.

## Authority boundary

### ooRexx owns

- close-neighbour coordinates, significance and probe policy;
- `MLPatternHash` shape identity and deformation order;
- `MLTemporalPatternHash` timing/turn evidence;
- source/catalog admission and wall-clock binding;
- candidate-window planning;
- FC/FD agreement and channel/feed assignment;
- generation boundaries and monotonic chronology;
- candidate ordering and retained evidence.

### Native / FFmpeg may only

- extract deterministic measurements from an admitted float32 signal;
- return postings for exact packed buckets already authorised by ooRexx;
- report exact filesystem size and nanosecond mtime;
- decode a bounded source interval selected by ooRexx.

The native provider has no API for radius, "near", chronology or final ranking.

## ML-derived close-neighbour stencil

The production CSR is an 18-bit address space:

```
dt[2 bits] | f1[8 bits] | f2[8 bits]
```

Dev4 does **not** treat arithmetic closeness of those integers as acoustic
closeness.  The ooRexx schema remains authoritative:

```
dt importance = 2
f1 importance = 1
f2 importance = 1
probe radius   = 1
```

Calling generic dev10 `neighbourKeys()` for every one of hundreds of landmarks
was too object-heavy for production.  Dev4 therefore asks dev10
`MLCloseHashSchema~difference` once for each relative radius-1 coordinate in a
27-cell stencil, then reuses those exact ML difference objects at each landmark.
Out-of-range boundary cells are skipped and the admitted probes are ordered with
dev10 `MLProbeKeyComparator`.

Qualification proves the optimized planner emits the same bucket set, difference
evidence and public order as the generic dev10 path.  A formerly timing-out
532-landmark worker regression now completes in a few seconds rather than being
allowed an artificially larger timeout.

## Production layout on ed209i

The default pilot expects:

```
~/fcpaphos_project_v9_snippets/
    single_feed/    # 89 mono event WAVs
    dual_feed/      # 582 stereo event WAVs

~/fcpaphos_originals/20231009_20231010/
    camera_fc/
    camera_fd/

~/audio_v9_reverse_locator_v0.2/run/v9_locator/
    v9_originals_landmarks.v9idx/
```

The source catalog must contain the 120 canonical originals matching:

```
YYYYMMDD_HHMMSS_tpNNNNN_original.ogg
```

for 20231009/20231010 only.

## First production pilot

Stop the old Python locator first so it does not compete for disk I/O.  Then:

```sh
cd ~/audio_v9_pattern_locator_v0.1-dev4
./tools/prepare_runtime.sh
./native/build_native.sh
./tools/run_pilot_ed209i.sh 8 gen3_current801
```

The pilot selects eight generation-3 snippets and creates, event by event:

```
run/production_pilot/evt_NNNNNN.result.tsv
run/production_pilot/pilot_summary.tsv
```

Generation-3 V9 metadata is **not** supplied to matching.  After each result is
written, `validate_gen3_seed.rex` compares the acoustic winner with surviving V9
metadata and reports `MATCH`, `TIME_ONLY`, `SOURCE_ONLY` or `MISS` as independent
validation evidence.

To run one event directly:

```sh
./tools/run_event.sh \
  ~/fcpaphos_project_v9_snippets/dual_feed/evt_000347.wav \
  ~/audio_v9_reverse_locator_v0.2/run/v9_locator/v9_originals_landmarks.v9idx \
  ~/fcpaphos_originals/20231009_20231010 \
  ./run/manual \
  gen3_current801
```

## Distribution

There are now two independent distributed planes.

`AudioV9SourceShardPlanner` divides the historical CSR source IDs into non-overlapping ranges for landmark candidate work. Source shards may be staged under a different worker root if canonical FC/FD name plus exact size and nanosecond mtime still match CSR metadata.

The Spectral Pattern Field is distributed by **globally phase-preserving time shards**. A coordinator decodes one canonical mono 8 kHz float32 master, pins its SHA-256, and plans immutable core ranges. Work starts are rounded to the original 256-sample FFT-hop phase; each unit carries sufficient right-hand samples to finish every box/segment whose global start belongs to its core. The coordinator verifies completeness and duplicate-free ownership before merge.

This was qualified by running four 2.5 s work units in shuffled completion order against the 10 s speech fixture: merged 18 segment rows and 522 box rows are byte-for-byte identical to the one-node output, including ML pattern keys. Wrong-master SHA-256 and missing-unit cases fail closed.

Example:

```sh
# once, on the coordinator
ffmpeg -nostdin -v error -i input.wav -map 0:a:0 -ac 1 -ar 8000 -f f32le -y master.f32
./tools/plan_spectral_field_shards.sh master.f32 field.work.tsv 15000 VOICE 1000 500

# copy master.f32 + field.work.tsv + the package to workers; each worker runs
./tools/run_spectral_field_shard.sh master.f32 field.work.tsv sf_00000_000000000 results scratch

# after all unit result files return
./tools/merge_spectral_field_shards.sh field.work.tsv results merged_field
```

Frequency-band sub-sharding is intentionally deferred: the residual graph uses a per-frame common q50 over the complete band field. A future band worker must consume a pinned shared common-mode vector rather than redefining the background from only its local bands.

## Qualification summary

On exact ooRexx 5.3.0 r13196:

- ooRexx ML v0.1-dev10: **57/57 PASS**;
- Foreign Runtime v0.22.6 native boundary: **128 assertions PASS**;
- locator suite: **32/32 PASS**, qualified in two deterministic halves to stay within the execution harness wall-clock cap;
- strict native build: `-std=c11 -O3 -Wall -Wextra -Werror` PASS;
- all 6 `.cls` sources and all 12 delivered `.rex` tools: **18/18 `rexxc` PASS**;
- native provider SHA-256: `fcd44f1db808a9d163c778020de6044abcea61a6916c925bfb3505aa08d99284`.

See `QUALIFICATION.md`, `qualification/` and the append-only `PROGRESS.md`.

## Deliberate non-claims

- No live ed209i pilot result is claimed by this local qualification environment.
- Pattern/temporal differences are structural evidence, not calibrated
  probabilities or perceptual confidence percentages.
- Dev5 provides deterministic work-unit mechanics but does not claim that a full 671-event ED209 campaign has already been executed.
- Spectral-field scene labels remain provisional; the real campaign evidence showed scalar motion thresholds are insufficient for buried speech, so recurrence/inter-box movement is the next authority layer.
