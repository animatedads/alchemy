# Audio V9 Voice Recovery v0.1-dev15

## Purpose

Dev15 continues the sealed dev14 prior-free recurrence line and repairs the landmark execution boundary so priority landmarks are probed with the v3 scanner rather than the older v2 scanner. Dev14 remains the audio/recurrence semantic base. Dev11 and dev12/v2 scanners remain separately callable for reproducibility. Dev14 v3 records cross-camera search censoring and local feed availability, and adds a bounded 6..80 ms same-feed matched-filter peak search that does not consult the seven named room-delay hypotheses. A landmark records filename, absolute wall-clock time, verified in-file offset, observation authority and user annotation without converting that annotation into detector truth. The first landmark is the user-observed FC phone-call reference at 2023-10-10 07:13:12 in `20231010_070249_tp00019.mp4`.

The primary objective remains better recovered audio. Dev13 does not weaken the dev6 rule that aggregate spatial evidence cannot move the camera clock. A source group must be supported on both cameras and on both sides of the seam, then be independently isolated and measured before it can contribute clock evidence. Classification, diarisation, graph rendering, landmark annotations and calibration remain evidence/reconstruction inputs, never deletion authority.

## dev15 landmark execution increment

Dev15 does not change native DSP, reconstruction, clock authority, ML, Graph, or the v1/v2/v3 scanner algorithms. It changes how named real-world landmarks are executed and preserved:

- `SEARCH_LANDMARKS.tsv` now carries sub-second anchor milliseconds and per-landmark default bounded probe windows.
- `LMK-20231010-FC-071312-PHONE` remains the user-grounded 07:13:12 phone-call/listening landmark and defaults to 60 seconds before + 240 seconds after.
- `LMK-20231010-041646400-CALIBRATION` records the screenshot-derived 04:16:46.400 broadband transient candidate and defaults to a tight 6 seconds before + 9 seconds after.
- `probe_search_landmark.sh` is now the preferred v3 path and emits `LOUD_EVENT_ECHOES_V3.tsv` plus `ANCHOR_EVENTS_V3.tsv`.
- The earlier v2 landmark behavior is retained as `probe_search_landmark_v2.sh`.
- `probe_priority_landmarks_v3.sh` runs both priority landmarks in one bounded corpus job.
- `summarize_search_landmark_v3.rex` filters the immutable v3 evidence around the exact millisecond anchor; it does not recalculate recurrence or classification.

The 04:16:46.400 anchor is explicitly a derived candidate from the earlier screenshot alignment, not user-asserted semantic identity. The 07:13:12 content cue remains user annotation; neither landmark grants the loud-event detector speech/source identity.

## Authority and campaign

Campaign interval: `2023-10-09 21:00:00` through `2023-10-10 15:00:00`.

Canonical corpus on each worker:

```
~/fcpaphos_originals/20231009_20231010/camera_fc/
~/fcpaphos_originals/20231009_20231010/camera_fd/
```

The corpus contract remains unchanged:

- FC: 95 files
- FD: 25 files
- total: 120 files
- total bytes: 4,292,920,762
- checksum-authority SHA-256: `a168f7d82f603f8d1671a7debf5a3aaae4a71a9c33f10cf2d22bff2e5453fae9`

`tools/verify_corpus.sh` remains fail-closed and verifies the exact 120-file checksum authority before analysis.

Seven deterministic core owners remain `ed209a`, `ed209b`, `ed209c`, `ed209d`, `ed209e`, `ed209h`, `ed209i`.  Worker identity owns time; host speed and completion order do not.

## dev2 deployment correction retained

The supplied dev2 deployment branch established the fleet-safe rule retained here:

- discover the installed exact ooRexx runtime;
- require ooRexx 5.3.0 r13196;
- reuse Foreign Runtime only when a real target load probe succeeds;
- otherwise rebuild `libforeign_runtime.so` from the packaged v0.22.6 source against the target ooRexx headers/system ABI when policy permits;
- apply the same reuse-if-loadable-else-rebuild rule to the spatial native provider;
- record readiness/build evidence under `run/deployment/`;
- verify the complete corpus before explicit worker start.

The general deployment implementation is intentionally separate.  `tools/deploy_worker.sh` expects `OOREXX_DEPLOYMENT_HOME` to point to General ooRexx Deployment v0.1-dev2.

## Exact decoded-sample geometry

Dev6 retains the dev3 exact decoded-sample contract learned from real Vorbis files. OGG packet/granule boundaries do not own distributed sample geometry. Normalization sidecars remain evidence, but a short/long decode at a file edge is now **media-extent evidence**, not a clock correction by itself.

`tools/decode_serial_interval.sh` converts to mono 8 kHz f32 and selects by **post-resample sample index**.  Every requested source slice is then normalized to the exact expected sample count:

- exact length: retain;
- long decode: sample-trim;
- short decode: explicit zero-pad and record that fact.

A `.decode.tsv` sidecar records file, wall-clock slice, source offset, expected samples, observed bytes, final bytes and normalization action.  Approximate sample counts are never silently accepted.

## Spatial quality reconstruction

Dev3 added a time-varying soft reconstruction path rather than one permanent A/B mix.

`AudioV9SoftReconstructionPolicy` consumes the spatial census and emits contiguous reconstruction-plan rows containing:

- sample range;
- B-channel lag hypothesis;
- FC and FD weights;
- governed gain;
- source-family annotation when available;
- reconstruction reason/evidence.

The native `render_plan_f32` implementation crossfades between successive lag/weight/gain plans.  Current defaults use a 100 ms crossfade at 8 kHz.

Quality rules are deliberately speech-preserving:

- coherent dual-feed evidence can use balanced fusion;
- weak coherence softly favours the stronger observation rather than hard-switching;
- recovery gain is bounded to the configured 0..32 dB range;
- gain movement is rate-limited to avoid pumping quiet whispers;
- high-crest impulses hold the speech-gain trajectory and receive a local peak guard;
- an alarm/cat/impact/background label can annotate a window but cannot hard-mute possible speech at this stage.

`quality_preview.ogg` is a listening preview only.  The authoritative output is the reconstruction plan plus source evidence.  Final campaign audio should be re-rendered once from source/native-rate material after selection has stabilised.

## Box-derived acoustic character

`AudioV9AcousticCharacter.cls` turns existing movement-based spectral boxes into acoustic observations.  The current character vector retains independent evidence from:

- residual spectral movement;
- spectral turn;
- active fraction;
- box width/range;
- spatial coherence;
- FC/FD level ratio;
- crest/impulsiveness;
- spatial lag magnitude;
- spectral location.

Absolute baseline level is deliberately excluded from acoustic identity.  The same source at very different gain levels should therefore remain comparable.

Characters connect into feed-specific temporal tracks only when time, neighbouring-band geometry and ML close-hash compatibility allow it.  Same-time adjacent boxes never become a temporal track merely because they are neighbours.

## Temporal ML and precision

Track temporal comparison uses ML dev11 cylindrical temporal-pattern hashing.  Event times supplied to ML are **track-relative milliseconds**, not absolute CCTV epoch milliseconds.  Absolute wall-clock remains provenance.  This both matches the time-shift-invariant source-identity question and prevents a narrower dependency-local numeric environment from collapsing distinct large epoch timestamps.

ML differences are significance ordered.  Fast coordinate-wise pruning is used only where it is an exact necessary condition for the existing dominant-delta criterion; acceleration may not change semantic tie-breaking.

## Recurring source families

Compatible tracks form recurring source families.  These are acoustic recurrence objects, not presumed semantic labels.

The current conservative evidence dimensions include:

- `VOICE_LIKE`
- `ALARM_LIKE`
- `IMPACT_LIKE`
- `BACKGROUND_LIKE`
- `VOCALISATION_LIKE`

These are priors/evidence scores, not authority to erase audio.

An externally confirmed exemplar can be represented as `AudioV9SourcePrototype`.  `AudioV9SourcePrototypeClassifier` can then attach that grounded label to every ML-compatible family appearance.  Intended uses include confirmed examples of:

- `ALARM`
- `CAT`
- `CAMERA_PLAYBACK`
- recurring mechanical/background sources
- externally grounded reference voice material.

Incompatible families remain unlabelled rather than being force-classified.


## Source-conditioned time-frequency reconstruction

Dev5 adds `AudioV9TimeFrequencyReconstruction.cls`. Every emitted TF-mask row is derived from an existing acoustic family/track/member box and retains the originating `character_id`. The box remains evidence; the mask is a reconstruction decision, not deletion authority.

The current conservative policy provides modest positive gain to anonymous-speaker/voice-compatible boxes, soft attenuation to externally confirmed alarm/cat/camera-playback/impact/background families, and weaker attenuation to strongly inferred interference only when voice evidence is low. Ambiguous vocalisation and otherwise uncertain material are protected (`UNCERTAIN_PRESERVE`).

The native `render_mask_f32` path applies those rows in the STFT domain with overlap-add reconstruction. It reads only the numeric mask geometry/gain fields; family, speaker, reason and character provenance remain evidence metadata. This lets classification improve listening quality without giving a renderer authority to invent source labels.

A synthetic audio regression confirms simultaneous band-selective behaviour: a protected voice-band tone is boosted while a separate alarm-band tone is attenuated.

## ML Graph evidence and instrument panel

The current graph layer preserves the techniques from the historical Audio V9 dev6 handover and is pinned to ooRexx ML Graph v0.1-dev5 plus ML v0.1-dev11. The semantic relation families are:

- `CONTINUATION` — same-band temporal continuation;
- `ADJACENT_BAND` — same-time neighbouring-band relationship;
- `DIAGONAL_MIGRATION` — cross-band temporal movement;
- `DELAYED_RECURRENCE` — a delayed-path candidate, never an automatic echo declaration.

Edge ownership remains source-box-start ownership, so distributed halos may supply targets without creating duplicate relation authority. `FULL` relation mode retains exact `MLPatternHashDifference` values. The fleet/default `TOPOLOGY` mode retains the exact relation topology without recomputing thousands of expensive differences per worker chunk; `FULL` is an explicit diagnostic mode.

Every quality analysis writes immutable semantic evidence:

- `.graph_edges.tsv` — relation topology and optional ML differences;
- `.graph_paths.tsv` — independent ENVELOPE, DIRECT and REFINED spatial-delay hypotheses;
- `.graph_wobble.tsv` — dev11 model-relative constant-delay fit/restoring-set summary;
- `.tf_mask.tsv` — source-conditioned reconstruction decisions with box provenance.

MLGraph scenes are **not** constructed by default on workers. `render_quality_graphs.rex` adapts already-computed TSV evidence into four diagnostic views: `FIELD`, `RELATIONS`, `DELAY`, and `RECONSTRUCTION`. It can restrict presentation to an absolute millisecond diagnostic window, so a large chunk need not materialize every relation merely to inspect a few seconds. Optional `.graphs.tsv` archives and SVG files are replay products; neither decoding nor source clustering is rerun.

The graph renderer has zero semantic authority: it may project and style existing nodes/relations but may not create, delete, reclassify or alter them. Dev11 wobble remains model-relative distance-to-fit; all minimal restoring explanations are retained and diagnostic exclusions do not delete evidence.

## Anonymous speaker diarisation

Voice-like families may be clustered into anonymous identities:

```
SPEAKER_0001
SPEAKER_0002
...
```

These identifiers mean only "acoustically compatible recurring voice source under the current model".  They do **not** assert a real-world person's identity.  A real name may be attached only from independent provenance/evidence.

Per-chunk speaker IDs are not global authority.  `AudioV9CampaignAcousticCoordinator` rebuilds the anonymous speaker namespace from merged campaign families, so source sections can cross chunk and worker boundaries deterministically.

## Evidence outputs

Per acoustic analysis:

- `.characters.tsv`
- `.tracks.tsv`
- `.track_members.tsv`
- `.families.tsv`
- `.appearances.tsv`
- `.speakers.tsv`
- `.tf_mask.tsv`
- `.graph_edges.tsv`
- `.graph_paths.tsv`
- `.graph_wobble.tsv`

Campaign merge:

- `.source_families.tsv`
- `.source_appearances.tsv`
- `.speakers.tsv`

Every source-family decision remains traceable to a track and ultimately to the moving boxes that formed it.

## Worker stages

`tools/run_worker.sh` supports:

- `spatial` — continuous dual-feed spatial census;
- `quality` — spatial census plus acoustic source analysis, box-conditioned TF-mask evidence and soft quality preview/reconstruction plan;
- `full` — quality path plus existing detailed Audio V9 spectral evidence.

The completed dev3 campaign remains immutable first-pass evidence. Dev6 uses its decode/spatial evidence only as calibration input. Quality reconstruction is a second pass over a separately resolved timing model; no dev3 evidence is rewritten.

## File-edge calibration v2

The campaign-level dev4 merge exposed that the earlier edge abstraction was too simple. The legacy map contained 118 corpus edges, 40 rows marked `MEASURED`, and 78 unresolved rows. Of the 40 measured rows, 38 had only one retained observation after exclusions and all 40 carried zero TDOA-before/after values. The legacy map is packaged only as `tests/fixtures/unsafe_dev4_FILE_EDGE_MAP.tsv` and is an explicit negative qualification fixture. Dev6 refuses that schema as source-clock authority.

Dev6 separates four quantities at every edge:

- `E` — **media extent residual**: decoded canonical sample extent minus nominal filename spacing;
- `C` — **camera/file clock step** at the right-hand file start;
- `G` — **real seam gap/overlap**, with `G = C - E`;
- `T` — **physical/path TDOA change** across the edge.

Cross-feed lag evidence is represented as `L`, where the project lag convention gives `C = +(L-T)` for an FC edge and `C = -(L-T)` for an FD edge. `MEDIA_EXTENT` never advances the piecewise source clock directly.

`AudioV9FileEdgeCalibration.cls` provides v2 evidence and solution objects. Evidence kinds are:

- `MEDIA_EXTENT`;
- `SEAM_GAP`;
- `SPATIAL_LAG_JUMP`;
- `CLOCK_CANDIDATE`.

Every observation also carries an estimator bundle and an independent-group identity. Correlated `ENV`, `DIRECT` and `REFINED` estimates from one analysis window may be retained separately for diagnosis, but the bundle counts as **one vote**. A `CLOCK_MEASURED` result requires at least two independent candidate groups that agree within the configured sample tolerance. Diagnostic exclusion is never allowed to manufacture authority from a single survivor. Two independently supported competing clusters become `CLOCK_AMBIGUOUS` and leave the prior correction unchanged.

`observe_decode_edges_v2.rex` mines dev3-style decode sidecars symmetrically: `PAD_ZERO`, `TRIM`, and exact edge geometry become `MEDIA_EXTENT` evidence. `observe_spatial_edges_v2.rex` converts aggregate before/after lag changes to `SPATIAL_LAG_JUMP` evidence with `tdoa_known=0`; those observations are useful diagnostically but **cannot measure clock**.

`AudioV9EdgePathContinuityFitter` and `observe_source_conditioned_edges.rex` are the new graph/source-family bridge. For a recurring source/path present on both sides of an edge, weighted lag trajectories are fitted independently before and after the exact seam. Ordinary source motion is represented by the fitted slopes. Only when both sides fit the declared continuous-source/path model within the RMS gate is the extrapolated seam jump emitted with known zero instantaneous TDOA discontinuity under that model. Different source families remain independent groups.

`plan_edge_calibration.rex` proves that only **42 source edges fall inside the 18-hour campaign: 32 FC and 10 FD**. Those are the only edges requiring expensive source-conditioned calibration. It emits bounded edge windows for graph/path analysis and flags near-simultaneous opposite-camera edges as potentially confounded.

The legacy dev4 command names `solve_file_edges.rex`, `observe_decode_edges.rex`, `observe_spatial_edges.rex`, and `geometry_observations_from_counts.rex` are retained only as fail-closed tombstones; they cannot produce legacy authority in dev8.

The authoritative v2 map schema is `campaign/FILE_EDGE_CALIBRATION.tsv`. The packaged file contains only the schema header, so no correction is active by default. `plan_source_interval.rex` and `decode_serial_interval.sh` consume only this v2 schema. Passing the legacy dev4 map fails closed.

A synthetic end-to-end regression demonstrates the intended mathematics. A source file with `E=-3` samples plus two independent continuous source/path trajectories each recovering `C=-3` yields `CLOCK_MEASURED`, `G=0/CONTIGUOUS`, and a 60-second requested interval is repartitioned as 239,997 samples from the left file plus 240,003 from the right file, preserving 480,000 samples exactly.


## Source-conditioned edge calibration — dev7

Dev7 fills the evidence gap intentionally left by dev6. Standard dev3 `spatial.tsv` rows are aggregate FC/FD measurements and are never duplicated or relabelled as independent source-family votes. The new calibration path measures each admitted source group from its **own isolated FC/FD time-frequency reconstruction**.

`build_source_calibration_masks.rex` consumes the existing acoustic evidence (`appearances.tsv`, `speakers.tsv`, `track_members.tsv`, `characters.tsv`). A candidate calibration group is admitted only when it has at least the configured support in all four quadrants: `FC_BEFORE`, `FC_AFTER`, `FD_BEFORE`, and `FD_AFTER`. Voice families already attributed to the same anonymous speaker collapse to one calibration group so near-duplicate voice families cannot manufacture independent votes. One-camera-only or one-side-only families remain ineligible.

For each admitted group the tool emits FC/FD selection masks. Native `av9_spatial_render_select_f32` applies those masks as STFT/Hann overlap-add **evidence isolation**, preserving phase while suppressing bins outside the selected source boxes. This selector is not a final listening renderer.

`extract_source_conditioned_paths.rex` runs the existing spatial estimator on each independently isolated FC/FD pair and writes the required path-point schema:

```
source_family
path_id
time_ms
BEFORE/AFTER
lag_samples
score
```

The actual TSV also retains edge/feed/source-file provenance. Measurement windows that straddle the seam are excluded. `ENVELOPE` points are retained for coarse graph/diagnostic context but are **not sample-exact clock authority**: the envelope estimator operates at 10 ms bins (80 samples at 8 kHz), so it cannot resolve the few-sample clock steps this calibration is intended to measure. Only source-conditioned `DIRECT`/`REFINED` trajectories can enter exact clock evidence.

`calibrate_edge_window.sh` performs the bounded per-edge sequence: nominal FC/FD decode with no unsafe map, acoustic/source-family analysis, four-quadrant group selection, source-isolated path extraction, and source-conditioned continuity evidence. Calibration f32 intermediates are removed by default; evidence TSVs and hashes are retained.

Fleet execution is deterministic. `plan_source_conditioned_jobs.rex` assigns each of the 42 campaign edges to the worker whose core interval owns the exact seam. Current qualification produces 42 jobs (32 FC, 10 FD) distributed as: ed209a=6, ed209b=4, ed209c=6, ed209d=6, ed209e=7, ed209h=6, ed209i=7. All nodes may read the full corpus, but only the owning worker may write the edge result.

`run_source_conditioned_calibration_worker.sh` is queue-friendly, resumable by per-edge `COMPLETE.tsv`, verifies the corpus/runtime before work, fails on an unknown/zero-job worker identity, and refuses to declare completion unless every assigned edge is present in the deterministic worker roll-up. `merge_source_conditioned_workers.sh` accepts the seven worker outputs only when every worker has a completion marker and a matching evidence SHA-256; missing or corrupted worker evidence fails closed.

The synthetic calibration regression deliberately includes a second periodic source that phase-locks to a conflicting lag. The well-resolved source recovers the true `-3` sample step, but the conflicting independent source prevents promotion beyond `CLOCK_CANDIDATE`. This is required behavior. The inherited dev6 solver regression separately proves the positive case in which two genuinely independent coherent source/path groups agree and produce `CLOCK_MEASURED`.

Dev7 therefore produces the evidence needed by the dev6/v2 solver; it does **not** manufacture a measured campaign map merely because 42 calibration jobs completed.


## Dev8 bounded calibration repair

The first real dev7 fleet execution exposed a **data-dependent scaling defect**, not a uniform machine-speed problem: ed209c and ed209h completed all six assigned edges quickly, while several other edges entered hours of I/O/swap pressure. The hotspot is acoustic fragmentation: source-family clustering may compare a new track with many existing candidate groups, and anonymous diarisation may compare many voice-like families against many existing speaker groups. On difficult material this becomes effectively quadratic and can inflate the ooRexx object working set until the host thrashes.

Dev8 repairs the operational path in four ways:

- calibration evidence is restricted to **8 seconds before + 8 seconds after the exact seam** (16 seconds total, clipped to the planned/campaign bounds); the original wider dev7 window remains provenance only;
- `analyze_acoustic_calibration.rex` emits only the six acoustic authority TSVs required for source conditioning and does **not** build TF-mask or spectral relation graph products;
- source-family clustering accepts an explicit comparison budget and fails closed with `CALIBRATION_COMPLEXITY_EXCEEDED` rather than running without bound; excessive voice-family fragmentation collapses conservatively to one anonymous calibration speaker group, which can lose a measurement but cannot manufacture the two independent votes required for `CLOCK_MEASURED`;
- the acoustic stage has a five-minute watchdog (`timeout -k 30 300` by default), plus `PROGRESS.tsv`, `CALIBRATION_WINDOW.tsv`, `acoustic.log`, and `FAILED.tsv` stage evidence.

Completed dev7 edges remain immutable evidence and may be reused. `run_source_conditioned_calibration_worker.sh` already skips an edge with `COMPLETE.tsv`; an unfinished edge is rebuilt from immutable source. Operators should point dev8 at the existing worker output tree when resuming if they intend to preserve completed dev7 C/H edges rather than create a separate result tree.

A pinned r13196 16-second qualification fixture completes the calibration-only analyzer in about **21–23 seconds**, producing 1,740 characters, 778 tracks and 52 families while omitting TF-mask and graph generation. The same full fixture is now part of the release gate; the previous 12-second-only qualification was insufficient for this fleet path.

## Performance checkpoints

On the packaged 12-second dual-feed synthetic fixture under ooRexx 5.3.0 r13196, the end-to-end box/source analysis produced:

- 1,276 acoustic box characters;
- 564 temporal tracks;
- 49 recurring source families;
- 13 anonymous voice clusters with diarisation enabled;
- elapsed time about 18.06 s in the final qualification environment.

This is a development performance fingerprint, not a forecast for every CCTV interval.



Dev7 retains the dev5 graph qualification: on the same 12-second fixture it produced 1,276 characters, 6,020 semantic topology relations and 1,276 TF-mask rows. Semantic graph TSV generation is part of the acoustic pass; MLGraph construction is deferred. A bounded 2-second diagnostic window renders all four SVG views from those TSVs, and independent replay produces byte-identical SVGs.


## dev8 qualification

Qualification uses `Open Object Rexx Version 5.3.0 r13196 - Internal Test Version`. The integrated dev8 gate passes with **32,717 explicitly counted Audio assertions**. It retains the 32,405 distributed coordinator regression and every dev7 timing/source/graph test, and adds bounded-family, conservative-diarisation, runtime-watchdog and full 16-second calibration-pipeline regressions.

The synthetic source-conditioned fixture emits 36 path points. Source A's DIRECT and REFINED trajectories both recover the true `-3` sample step; an independent periodic Source B produces a conflicting DIRECT path around `+255` samples. The v2 solver correctly leaves the edge at `CLOCK_CANDIDATE` with insufficient independent agreement. This is a negative safety qualification, not an audio-quality score.

Historical dev5 qualification used ML Graph dev3. Current dev12/dev13 authority is ML v0.1-dev11 plus ML Graph v0.1-dev5; see the dev12 and dev13 qualification records for the current dependency gates.

## Non-claims

Dev8 does not yet claim:

- that anonymous speaker clusters are real-world identities;
- that heuristic `VOICE_LIKE`/`ALARM_LIKE` scores alone distinguish every whisper, cat or alarm;
- that source-family labels authorize destructive suppression;
- that the completed dev3 18-hour census has already been rerun through dev7 source-family/TF-mask reconstruction;
- that `quality_preview.ogg` is the final forensic master;
- that missing source audio can be reconstructed when the recordings contain no observation of it;
- that the legacy dev4 aggregate spatial observations can by themselves resolve camera clock steps; their TDOA change is explicitly unknown;
- that standard dev3 `spatial.tsv` automatically supplies source-conditioned path points; the bounded 42-edge calibration pass must produce/attribute continuous source-path trajectories before those observations can gain clock authority;
- that the lost historical Audio V9 dev6 executable source has been recreated byte-for-byte.

Dev8 establishes a bounded and watchdog-protected source-conditioned evidence path above the safe dev6 timing model. The next campaign action is to execute its 42 ownership-assigned calibration jobs, merge the seven hashed worker evidence sets, solve the v2 map, inspect every `CLOCK_MEASURED`/candidate/ambiguous edge, and only then perform quality reconstruction from defensible clock corrections; unresolved/ambiguous edges retain the prior clock.


## dev9 source-path trajectory and TSV repair

Dev9 is a semantic repair of dev8, not a new clock solver. The bounded 16-second calibration window, complexity guard, watchdog and fail-closed `UNRESOLVED` handling remain unchanged.

Audit of the completed transferred dev8 results exposed a producer/fitter geometry mismatch: the 16-second seam window was scanned with an 8-second window and 4-second step, which yields only one complete BEFORE and one complete AFTER point per source/path. `AudioV9EdgePathContinuityFitter` correctly requires at least three points on each side, so source-conditioned DIRECT/REFINED evidence was rejected by construction even where source masks existed.

Dev9 fixes the producer rather than weakening the fitter. `extract_source_conditioned_paths.rex` now uses a 4-second spatial scan window with a 2-second step. On the same 16-second seam interval this yields three complete BEFORE and three complete AFTER observations for each admitted source/path. The synthetic qualification fixture emits 36 path points; broadband SRC_A DIRECT and REFINED independently recover the true `-3` sample seam with zero fit RMS, while the periodic SRC_B remains conflicting and therefore cannot manufacture agreement.

Structured TSV input is now owned by `AudioV9TsvReader`, backed by stock ooRexx `CSVStream` configured with TAB (`'09'x`) as delimiter. Records are arrays. Adjacent empty fields are preserved. Stock r13196 `CSVStream` omits a final empty field when a physical record ends in the delimiter; the adapter restores exactly that final structural field from `rawText` while leaving CSVStream responsible for parsing/quoting. The regression covers both adjacent and trailing empty fields. Production one-column filename/path lists remain ordinary streams because they are not TSV tables. Binary/sample-range access remains outside this layer and is a future `LazyReadFile` concern.

No dev7 or dev8 campaign evidence is rewritten by packaging dev9. Existing completed evidence retains its provenance. Dev9 must be used to regenerate source-conditioned path/evidence for affected seams before a real campaign clock map can be promoted.

## dev9-hotfix1 — governed complexity continuation

The first real dev9 fleet continuation exposed a control-flow regression from the
operator-applied dev8 runner hotfix: sealed dev9 correctly bounded pathological
edges, but exit 168 (`CALIBRATION_COMPLEXITY_EXCEEDED`) still terminated the
logical worker chain.

Hotfix1 restores the intended governed semantics without weakening any other
failure boundary:

- exit 168 is continuable **only** when the edge `FAILED.tsv` also records the
  exact reason `CALIBRATION_COMPLEXITY_EXCEEDED` and exact `exit_code=168`;
- that diagnostic is preserved as `COMPLEXITY_DETAIL.tsv` and the edge receives
  an explicit `UNRESOLVED.tsv` terminal marker;
- a prior sealed-dev9 complexity failure is promoted on resume without rerunning
  the expensive edge;
- `COMPLETE.tsv` and `UNRESOLVED.tsv` are both terminal edge outcomes for resume;
- governed unresolved edges contribute no source-path clock evidence;
- all other nonzero edge exits remain fatal and stop the worker immediately;
- worker completion records processed, resolved and unresolved edge counts.

No clock correction is inferred from an unresolved edge.  The downstream dev6
solver continues to advance source clock only from independently supported
`CLOCK_MEASURED` evidence.

## dev10: move into processing

Run a logical worker reconstruction:

```
tools/run_reconstruction_worker.sh ed209a /path/to/fcpaphos_originals/20231009_20231010
```

Repeat for the seven logical workers (physical hosts may impersonate logical
workers exactly as during calibration).  Each worker produces an exact
`voice.f32` for its owned core interval.

After all seven logical workers are complete:

```
tools/merge_reconstruction_workers.sh run/final/best_voice.ogg run/reconstruction/workers 8
```

The merge requires exactly 518,400,000 samples and performs one final OGG encode.

## dev11: loud-event echo survey

Dev11 adds a diagnostic-only room-geometry survey using the naturally occurring
high-peak events already visible in the CCTV audio.  It does **not** alter the
reconstruction samples or promote a new clock correction.

The scanner treats a large transient as an acoustic probe.  It takes a short
sample-level template around the first peak and searches only the next 80 ms
for correlated replicas.  The search is constrained to the current physical
hypotheses supplied for this property:

- 8.75 ms — 3 m round trip from a central source;
- 17.50 ms — 6 m wall-return path;
- 22.09 ms — short concrete-path initial arrival hypothesis;
- 23.32 ms — 8 m divider/stairwell return;
- 24.74 ms — 8.49 m corner-return path;
- 26.04 ms — west-wall to southeast-corner through-wall path;
- 58.30 ms — 20 m long stairwell/corridor return.

At 8 kHz these are approximately 70, 140, 177, 187, 198, 208 and 466 samples.
The values are **soft hypotheses**, not sample-exact truth.  Each is searched in
a small neighbourhood.  The measured audio owns the actual lag.

The detector is deliberately simple: it admits very high peaks relative to the
preceding local RMS, clusters peaks inside a 120 ms refractory interval so a
modeled echo cannot become a second event, identifies which camera leads, then
matches same-feed replicas and the FC/FD arrival difference.  Weak best matches
are explicitly reported as `WEAK_OR_UNMODELED`; merely being the largest score
does not make a room path true.

The current diagnostic pattern hints are conservative:

- `FD_STAIRWELL_PATTERN` requires an FD-side event plus strong FD evidence near
  the 23.32 or 58.30 ms stairwell families;
- `FC_ROAD_SIDE_PATTERN` requires an FC-side event plus strong FC evidence near
  the 17.50 ms family;
- otherwise a strong modeled reflection is `MODELED_ROOM_PATTERN`;
- weak or unmatched events remain `UNRESOLVED_PATTERN`.

This intentionally separates *where the echo pattern points* from *what made the
noise*.  A cat, siren or bang is not classified solely from amplitude.

For an already matched FC/FD float pair:

```
tools/run_rexx_pinned.sh tools/scan_loud_echo_events.rex \
    fc.f32 fd.f32 LOUD_EVENT_ECHOES.tsv
```

For a bounded real-corpus interval (maximum 10 minutes):

```
tools/scan_loud_echo_interval.sh \
    "2023-10-10 04:16:40" "2023-10-10 04:16:55" \
    run/echo-test/LOUD_EVENT_ECHOES.tsv \
    ~/fcpaphos_originals/20231009_20231010
```

The interval helper verifies the canonical corpus, decodes equal FC/FD sample
geometry, records the exact serial start in every event row, and deletes its
temporary PCM after the survey.  Structured TSV validation uses
`AudioV9TsvReader` / stock ooRexx `CSVStream` with TAB delimiter.


## dev12: feed-relative echo calibration survey

Dev12 preserves the complete dev11 loud-event scanner and its `LOUD_EVENT_ECHOES.tsv`
contract for reproducibility, but it does **not** use dev11 as the preferred two-feed
survey.  The first real eight-hour dev11 survey exposed two measurement problems:

1. dev11's shared absolute `MIN_PEAK=0.50` admission floor selected FC-scale events
   only on this corpus; and
2. the +/-1 ms family search clipped a material number of otherwise strong maxima.

The preferred dev12 entry points are therefore:

```
tools/run_rexx_pinned.sh tools/scan_loud_echo_events_v2.rex \
    fc.f32 fd.f32 LOUD_EVENT_ECHOES_V2.tsv
```

or, for a bounded canonical-corpus interval:

```
tools/scan_loud_echo_interval_v2.sh \
    "2023-10-10 04:16:40" "2023-10-10 04:16:55" \
    run/echo-test/LOUD_EVENT_ECHOES_V2.tsv \
    ~/fcpaphos_originals/20231009_20231010
```

V2 candidate admission is independent per feed.  FC and FD each compare their local
peak against their **own** guarded preceding RMS.  The absolute floor is only a low
numerical safety floor (`0.001` by default); the default relative criterion remains
6x.  When both feeds produce candidates in one refractory cluster, the event anchor
is the candidate with the largest peak-to-own-baseline ratio rather than the largest
raw amplitude.

`trigger_feed` and `leader` are deliberately separate.  `trigger_feed` says which
feed supplied the relative event anchor.  `leader` is asserted only when the
cross-feed matched-filter score reaches the configured strong threshold; otherwise
it is `UNRESOLVED`.  Raw FC-minus-FD timing remains present regardless.

The v2 TSV also makes previously hidden uncertainty first-class evidence:

- `best_echo_feed` is distinct from `best_echo_family`;
- every FC/family and FD/family pair carries measured lag samples, measured lag ms,
  correlation score and search-boundary flag;
- `strong_family_count` and `strong_feed_hypothesis_count` expose overlap instead of
  converting it into categorical certainty;
- `second_echo_score` and `best_second_margin` retain best-vs-runner-up separation;
- `boundary_hit_count` and `best_echo_boundary` expose clipped-search evidence;
- the default search radius is widened to 4 ms but remains bounded;
- `pattern_hint` is conservative and requires both a strong local echo and strong
  cross-feed match.  It is still a diagnostic hypothesis, never source identity.

Widening the search does **not** make the closely packed 22--26 ms hypotheses more
independent.  Their windows overlap by design in dev12.  The system therefore keeps
all measured alternatives for the ML Graph / ML dev11 contextual-fit layer rather
than treating the numerical best family as truth.

Dev12 also promotes the graph presentation dependency to **ooRexx ML Graph
v0.1-dev5**, SHA-256
`24659562d1e5ca86a08bc3156f838eebd1e320a45e3e8969979fe7dde3b69d40`, while
retaining ooRexx ML v0.1-dev11.  Graph dev5 is used only to adapt/render already
computed evidence.  It has no authority to create or change acoustic observations,
source labels, path hypotheses or reconstruction decisions.

## dev13: externally observed search landmarks

Dev13 adds `reference/SEARCH_LANDMARKS.tsv` as a small, provenance-preserving registry for real-world observations that should guide later bounded searches. A landmark is not a classifier label. It records who supplied the observation, how it was heard/seen, the exact source filename, nominal file start, absolute observation time, and the user's interpretation separately.

The first registered landmark is:

- ID: `LMK-20231010-FC-071312-PHONE`
- feed: FC
- source file: `/run/media/hc3/1A52-190F/masvid/Master Video Library/fc/20231010_070249_tp00019.mp4`
- absolute time: `2023-10-10 07:13:12`
- verified offset from filename start: `623` seconds
- observation authority: `USER` / `GROUND_TRUTH_LISTEN`
- listening method: `VLC_200_PERCENT`
- content cue: phone call; discussion about international police coordination
- follow-on cue: following audio user identifies as intercepted
- status: `USER_ANNOTATED`

The final cue is deliberately retained as a user annotation, not promoted to an acoustic fact.

`tools/plan_search_landmark.rex` resolves a landmark through `AudioV9TsvReader` / stock ooRexx `CSVStream`, verifies the declared filename-to-event offset using `AudioV9VoiceClock`, and emits a bounded probe plan. The default window is 60 seconds before and 240 seconds after the anchor, reflecting this observation's useful directionality (known phone call, then following audio), while remaining under the 600-second diagnostic cap.

`tools/probe_search_landmark.sh` executes that plan against the canonical FC/FD corpus. It preserves decoded FC and FD float audio, runs the dev12 v2 loud-echo survey only as **auxiliary** evidence, writes a semantic note that absence of loud-echo rows is not negative speech evidence, and hashes every output. This lets later speech/graph work reuse exactly the same bounded interval without changing the original raw video or the sealed dev11/dev12 evidence.

## dev14: prior-free recurrence discovery and censored-delay evidence

The completed dev12 overnight campaign supplied 51 consecutive ten-minute windows
covering `2023-10-09 21:00:00` through `2023-10-10 05:30:00` and 10,983
admitted events. Trigger admission is now balanced enough to demonstrate that the
v2 feed-relative correction worked (FC 5,767 / FD 5,216), but the campaign also
shows why named-family maxima must remain hypotheses: 9,759 events are
`MULTI_FAMILY`, with a median of all seven families above the 0.70 strong threshold
somewhere across the feeds.

Dev14 therefore adds a **v3** scanner without changing v1 or v2:

```
tools/run_rexx_pinned.sh tools/scan_loud_echo_events_v3.rex \
    fc.f32 fd.f32 LOUD_EVENT_ECHOES_V3.tsv
```

For a bounded corpus interval:

```
tools/scan_loud_echo_interval_v3.sh \
    "2023-10-10 04:16:40" "2023-10-10 04:16:55" \
    run/echo-test/LOUD_EVENT_ECHOES_V3.tsv \
    ~/fcpaphos_originals/20231009_20231010
```

V3 begins with the complete v2 row and appends calibration-only evidence:

- `cross_boundary` and `cross_search_radius_ms`, so an FC<->FD best match at the
  existing +/-35 ms search endpoint is explicitly censored;
- `fc_local_nonzero` / `fd_local_nonzero` and per-feed baseline coverage;
- four prior-free recurrence peaks per feed from a 6..80 ms matched-filter search;
- search-completeness and 3 ms non-maximum-separation metadata.

The prior-free recurrence search never reads `g_echo_hyp`. The seven named
8.75/17.50/22.09/23.32/24.74/26.04/58.30 ms families remain in the inherited v2
columns as physical hypotheses. Comparing those two evidence channels is the
intended use: a room path should recur in the prior-free channel before the named
family may be treated as more than a prediction.

The 51-job campaign also contains 96 rows exactly at the +/-35 ms cross-camera
limit, including 45 with `cross_score >= 0.70`; v3 marks these as censored instead
of presenting 35 ms as unconstrained geometry. It also exposes an interval where
FC event-local peak and baseline are exactly zero while FD continues to trigger
(approximately 00:06:14 through 00:34:31); downstream geometry must therefore
fail closed when one feed is locally unavailable.

The synthetic v3 qualification proves prior-free recovery of the fixture's
23.32 ms and 58.30 ms FD returns, the 17.50 ms FC return, and an artificial 35 ms
recurrence without named-family centring. A fifth low-gain fixture lands the
FC<->FD match exactly on +/-35 ms and must emit `cross_boundary=1`.

Real-campaign motivation and the 04:16:46 calibration candidate are preserved in
`qualification/DEV12_OVERNIGHT_51JOB_FINDINGS.md` and
`qualification/CALIBRATION_CANDIDATE_20231010_041646.tsv`.


## dev16 — reflection-aware whisper reconstruction planning

Dev16 preserves sealed dev15 and adds an explicit propagation-evidence boundary for the next reconstruction pass. The target voice is expected to be predominantly very low-level / whisper-like and to recur from the same approximate source location. Recorded amplitude is **not** treated as source loudness: a passing vehicle can act as a moving reflective surface and temporarily improve a reflected path to one camera.

The new `AudioV9PropagationReconstruction.cls` therefore keeps direct, static-reflection and transient-reflection observations separate. An acoustic path must first pass an audio compatibility gate. Video/vehicle geometry may corroborate that already-observed path, but visual evidence alone remains `VISUAL_ONLY_CANDIDATE` and is not admitted to fusion.

`AudioV9WhisperGainTracker` learns its low-level reference only from non-loud, non-transient windows. A bang, alarm, vehicle pass or transient reflection cannot reset the whisper gain trajectory merely because the recorded RMS rises. Loud/impulsive windows are explicitly marked `LOUD_PROBE_SEPARATE_STEM`; they remain valuable acoustic probes but are outside whisper AGC authority.

Compatible reflected observations may contribute to a whisper fusion plan, but reflected weight is bounded and all contribution weights are normalized. This is evidence-driven echo combination, not naive waveform summation. Video corroboration can modestly strengthen the ranking of an acoustically admitted reflection but cannot alter its measured delay, apparent gain or audio-match score.

`correlate_vehicle_reflections.rex` provides the ingestion seam for the pending video-processing campaign. It correlates time-overlapping visual reflector tracks with immutable audio propagation observations and writes the combined authority state without overwriting the audio measurements.

Dev16 deliberately stops at evidence/fusion planning. The final multi-path audio renderer and tuning of vehicle-reflection weights will be qualified against the real video/audio campaign evidence rather than guessed before those results exist.
