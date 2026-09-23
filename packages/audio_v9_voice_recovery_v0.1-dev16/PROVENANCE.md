# Provenance — Audio V9 Voice Recovery v0.1-dev15

## dev15 landmark provenance

Executable base: sealed Audio V9 Voice Recovery v0.1-dev14. Dev15 changes only the search-landmark execution/provenance surface plus tests/documentation. No native provider, DSP class, reconstruction policy, ML dependency, ML Graph dependency, campaign authority, or loud-echo v1/v2/v3 algorithm is changed.

The user supplied the FC raw-video landmark `/run/media/hc3/1A52-190F/masvid/Master Video Library/fc/20231010_070249_tp00019.mp4` at 2023-10-10 07:13:12 and described clearly audible phone speech plus following audio. The project clock verifies +623 seconds from the nominal filename time. Content interpretation remains `USER_ANNOTATED`.

The calibration landmark at 2023-10-10 04:16:46.400 is derived from the prior user screenshot/Audacity alignment against `20231010_041038_tp00014_original`; the whole-second source offset is +368 seconds and the preserved sub-second anchor is +400 ms. It is `DERIVED_CANDIDATE`, not source identity truth.

The completed dev12 campaign spans 102 consecutive ten-minute jobs from 2023-10-09 21:00 through 2023-10-10 14:00 with 33,288 admitted events. Those campaign results motivate v3/censoring and the priority landmarks but are evidence inputs, not dev15 executable semantics.

## Lineage

Dev6 descends directly from sealed `audio_v9_voice_recovery_v0.1-dev5.zip`, SHA-256 `a97926146cc93413b1a8d655b7e159c9659138032b94c042cac091705b7aa307`. It preserves dev5 quality, source-family, anonymous-speaker, TF-mask and ML Graph semantics while replacing dev4 file-edge clock authority with the corrected v2 calibration model.

Earlier sealed lineage remains: dev4 SHA-256 `731c47eb9b22457ff355d07f99838eda42d21d74b7cfb0944330acd0876abefb`; supplied deployment/readiness dev2 SHA-256 `c5496ec6f7a68eebe8e6b48a46012e2141a5b9a2a5a5b6ba4857e5ed7f2821d2`. The dev3 seven-node campaign completed across all workers and its evidence is treated as immutable input to calibration.

## Separate general deployment component

User-supplied `oorexx_deployment_v0.1-dev2(1).zip` has SHA-256:

`305b1acbf3b1b8b413dbfd088272478d7f0fd076ee531b96fa42a53ed6b64ea9`

Its internal manifest verifies and its complete local behavioral suite passes under ooRexx 5.3.0 r13196.  It remains a separate general component; it is referenced by the Audio deployment adapter and is not folded into Audio source semantics.

## Spatial Python reference

Embedded reference archive:

`reference/python_spatial/pyaudprocessing_reference.zip`

SHA-256:

`4c76aa6ff4fb1d09d663a3f50624e81b8cc9711e771684ba36b3602a95de42b4`

Selected v6/v10.2/v11 reference files and site/calibration material remain present for audit.  They inform the spatial architecture; the ooRexx/native implementation is not a line-by-line translation.

## Embedded dependency authority

- Audio V9 Pattern Locator v0.1-dev5-hotfix1: `6d2716b5f697b9b705214dcc6bd8f93c62b5072111174dd6f3a485334ae5ecd8`
- ooRexx ML v0.1-dev11: `713c4998c67aed9b526f3e20f7b2f14de4b355939259bff55beebe9133980c79`
- ooRexx ML Graph v0.1-dev5: `24659562d1e5ca86a08bc3156f838eebd1e320a45e3e8969979fe7dde3b69d40`
- ooRexx Foreign Runtime v0.22.6: `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`

The runtime deployment layer may rebuild native Foreign Runtime/spatial objects for target ABI compatibility.  Such target-native binary hashes are deployment evidence and are not expected to equal the packaged prebuilt object.

## ooRexx runtime authority

Qualification runtime:

`Open Object Rexx Version 5.3.0 r13196 - Internal Test Version`

Recovered qualification package SHA-256:

`8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`

Every executable `.rex` root uses `numeric digits 30`.  Every package `.cls` uses `::options numeric inherit`.

The temporal acoustic representation intentionally uses track-relative event times so acoustic identity is independent of the absolute campaign epoch and remains robust across dependency-local numeric environments.

## Corpus authority

Embedded canonical authority:

`campaign/FCPAPHOS_ORIGINALS_SHA256SUMS`

SHA-256:

`a168f7d82f603f8d1671a7debf5a3aaae4a71a9c33f10cf2d22bff2e5453fae9`

It contains exactly 120 unique entries: 95 FC + 25 FD.  The declared corpus byte total is 4,292,920,762 bytes.  Runtime preflight re-hashes every original on the deployed worker.

## Semantic boundaries

- Distribution assigns computation/ownership; it does not change source semantics.
- Acoustic classes and anonymous speakers are hypotheses/evidence until externally grounded.
- Prototype labels carry explicit provenance.
- A wobbly/restoring-set exclusion is diagnostic only and never deletes source evidence.
- Quality previews are derived material; reconstruction plans and original-source mappings remain evidence authority.



## dev5 graph continuity authority

The graph design is not a new visualization invention. It restores the semantic techniques recorded in the historical Audio V9 dev6 handover: Spectral Pattern Field boxes connected by continuation, adjacent-band, diagonal-migration and delayed-recurrence relationships; source-box-start edge ownership; multi-hypothesis delayed paths; and graph rendering as an instrument panel with no semantic authority.

At the historical dev5 state, the graph dependency was ooRexx ML Graph v0.1-dev3, SHA-256 `a4ee63c48eab3ac27166607998071800f32b9af0cf6c3dbba12e08fa6627402a`. The ML dependency was dev11, SHA-256 `713c4998c67aed9b526f3e20f7b2f14de4b355939259bff55beebe9133980c79`. Current dev12/dev13 graph authority is recorded later as ML Graph dev5. Dev11 wobble is model-relative distance-to-fit: all minimal restoring sets remain evidence and temporary exclusions are diagnostic only.

The canonical two-path regression uses delays 80,80,80 and 140,140,140 ms under an intentionally wrong one-coherent-delay model. It returns distance-to-fit 3, normalized distance 0.5, and two minimal restoring explanations.

## dev5 graph authority boundary and scaling

Per-chunk worker authority is the immutable TSV evidence, not the SVG or MLGraph archive. `TOPOLOGY` relation mode is the fleet default and writes exact semantic relation topology without constructing all pairwise `MLPatternHashDifference` objects. `FULL` mode is retained for bounded diagnostics where exact relation differences are required.

The quality path writes `characters.tsv`, `graph_edges.tsv`, `graph_paths.tsv`, `graph_wobble.tsv` and `tf_mask.tsv`. TF-mask rows retain the originating box-character id. `render_quality_graphs.rex` builds MLGraph scenes only from these already-computed files and supports bounded absolute-millisecond diagnostic windows. Optional MLGraph archive and SVG replay cannot decode audio, rerun source clustering, or alter evidence.

A 12-second dual-feed qualification fixture produced 1,276 characters, 6,020 topology relations and 1,276 TF-mask decisions. The semantic evidence pass completed without MLGraph construction. A bounded 2-second diagnostic view then rendered FIELD, RELATIONS, DELAY and RECONSTRUCTION SVGs twice from the same TSV evidence with byte-identical output; source evidence hashes were unchanged.

## dev5 TF reconstruction authority

`AudioV9TimeFrequencyReconstruction.cls` derives soft STFT-domain gains from already-established source-family/speaker/box evidence. Anonymous speaker or voice-compatible evidence may receive modest boost; confirmed or strongly supported non-voice interference may receive soft attenuation; uncertain or ambiguous vocalisation is protected. The renderer consumes numeric mask instructions but has no authority to change family/speaker labels.

## dev6 corrected file-edge calibration authority

The completed dev4 campaign merge is retained as negative evidence because it exposed an invalid abstraction. The supplied legacy `FILE_EDGE_MAP.tsv` covers 118 corpus edges and marks 40 as measured. Audit shows 38/40 measured rows have fewer than two retained observations and 40/40 have zero TDOA-before/after values. The old solver allowed dev11 wobble exclusions to reduce a competing set to one survivor and then report RMS zero; aggregate spatial lag change also passed `tdoaBefore=0, tdoaAfter=0`, so physical/path TDOA motion could be misinterpreted as a camera clock step.

Dev6 packages that exact map as `tests/fixtures/unsafe_dev4_FILE_EDGE_MAP.tsv`. `AudioV9FileEdgeCalibrationMap~fromFile` accepts only the v2 calibration schema and fails closed on the legacy map. `audit_legacy_edge_map.rex` is a permanent regression proving the unsafe characteristics remain detectable.

The corrected model keeps `E` media extent, `C` camera/file clock step, `G=C-E` seam gap/overlap and `T` physical/path TDOA change distinct. Correlated estimators are bundled into one vote. `CLOCK_MEASURED` requires two independent agreeing groups; single-candidate results remain `CLOCK_CANDIDATE`, and competing supported clusters remain `CLOCK_AMBIGUOUS`. Only `CLOCK_MEASURED` advances cumulative correction.

The source-conditioned path continuity fitter is intentionally model-explicit. It removes ordinary path motion by fitting lag trajectories on each side of the seam and emits a clock candidate only when the same declared source/path fits both sides within the RMS gate. This is where the dev5 graph/source-family techniques enter timing calibration rather than being replaced by a scalar lag average.

Campaign planning identifies 42 relevant edges inside the 18-hour interval: 32 FC and 10 FD. The other 76 corpus edges are outside campaign timing authority and need not receive expensive calibration for this recovery.

## dev6 qualification

Qualification uses `Open Object Rexx Version 5.3.0 r13196 - Internal Test Version`. The integrated dev6 master gate passes in 34 seconds in the qualification environment and retains the inherited 32,405-assertion distributed-order-independence regression, 83-assertion graph-topology regression, TF-mask audio behaviour and deterministic 1,276-character / 6,020-relation quality-graph replay.

The corrected edge layer adds executable checks for extent-only non-authority, correlated estimator bundling, independent source/path support, explicit TDOA subtraction, FD lag-sign convention, competing-cluster ambiguity, v2-only map loading, 42-edge campaign planning, legacy-map refusal and end-to-end exact sample repartition. The assertion-counted Audio total is 32,674.

Pinned dependencies are requalified in the same tree: ooRexx ML v0.1-dev11 passes all 63 test files; ooRexx ML Graph v0.1-dev3 passes 53 assertions across model, SVG, 3D SVG, pattern, temporal, temporal-market and difference-annotation tests.


## dev7 source-conditioned calibration evidence authority

Dev7 continues sealed Voice Recovery v0.1-dev6 (SHA-256 `9ea009c5fe3b33dc36ef208bfb6c6de4cea91365dda8a67c4b63197cd15cb19b`) without weakening the v2 edge solver. The completed dev3 campaign and the unsafe dev4 aggregate map remain immutable upstream evidence/negative qualification material.

The trigger for dev7 was operationally exact: staged dev6 correctly refused to infer `CLOCK_MEASURED` corrections because dev3 supplied only aggregate `spatial.tsv`, while `AudioV9EdgePathContinuityFitter` requires source-conditioned path points carrying source family, path identity, time/side, lag samples and score. Dev7 adds the producer for that schema.

Source independence is established by measurement, not labelling. `build_source_calibration_masks.rex` admits only acoustic groups supported in FC-before, FC-after, FD-before and FD-after. Families attributed to one anonymous speaker are collapsed to one calibration group. Native `av9_spatial_render_select_f32` then isolates that group independently in each feed, and `extract_source_conditioned_paths.rex` reruns spatial estimation on the isolated pair. A single aggregate lag row is therefore never copied into several family identities to manufacture support.

The envelope path is explicitly diagnostic-only for sample-exact timing because its 10 ms / 80-sample analysis bins cannot establish few-sample steps. Source-conditioned DIRECT/REFINED trajectories remain eligible subject to the inherited dev6 independent-group/fit rules. A synthetic fixture with a true `-3` sample seam plus a periodic independent source proves fail-closed behavior: the broadband source recovers `-3`, the periodic source aliases to a competing path, and the solver remains `CLOCK_CANDIDATE` rather than averaging or promoting the conflict.

The fleet planner assigns the 42 in-campaign seams by exact worker-core ownership: ed209a 6, ed209b 4, ed209c 6, ed209d 6, ed209e 7, ed209h 6, ed209i 7 (32 FC + 10 FD). Worker calibration is resumable and queue-friendly. Worker completion requires all assigned edge outputs; campaign merge requires all seven completion markers and verifies each worker evidence SHA-256 before deterministic concatenation. A missing or corrupted worker is rejected.

At qualification time no real campaign source-conditioned v2 map is claimed. Dev7 establishes and qualifies the evidence-production mechanism only; the seven-worker 42-edge calibration still has to be executed against the original corpus before any new `CLOCK_MEASURED` campaign authority exists.


## dev7 qualification

The integrated Audio master gate passes under ooRexx 5.3.0 r13196 in 34.42 seconds with 32,693 explicitly counted assertions plus native/audio integration checks. The new fleet planner proves exactly 42 ownership-assigned jobs (32 FC + 10 FD) with distribution `6,4,6,6,7,6,7` across ed209a/b/c/d/e/h/i. Unknown worker identities fail before corpus hashing; worker completion requires all assigned edges; campaign merge requires all seven completion markers and verifies each worker evidence SHA-256. Missing or corrupted evidence is rejected.

The source-conditioned synthetic fixture emits 36 path points. SRC_A DIRECT/REFINED recover the true `-3` sample seam while periodic SRC_B produces a competing `+255` sample DIRECT path; the inherited v2 solver therefore retains `CLOCK_CANDIDATE` rather than manufacturing agreement. `ENVELOPE` remains diagnostic-only for sample-exact clock authority.

Dependency qualification remains ML dev11 63/63 files and ML Graph dev3 53 assertions. Static qualification covers 41 DIGITS-30 Rexx roots, 12 numeric-inherit classes, 36 shell syntax roots, 53 `rexxc` roots, and five byte-reproducible native artifacts. Full detail is in `qualification/QUALIFICATION_DEV7.txt`.


## dev8 bounded-calibration repair authority

The first real dev7 fleet run showed a non-uniform failure: ed209c and ed209h completed all six owned edges quickly, while other workers remained inside `analyze_acoustic_chunk.rex` for hours with heavy disk activity and kernel I/O wait. This rules out a simple fixed cost for every 120-second window. Inspection identified data-dependent candidate growth in source-family clustering and anonymous diarisation as the unsafe path; large fragmented family populations can make comparisons effectively quadratic and inflate the ooRexx working set into swap pressure.

Dev8 changes only the calibration evidence producer. The corrected clock solver and dev7 source-isolation authority are unchanged. Edge evidence is now measured from a seam-local 16-second interval (8 seconds per side), which is sufficient for the existing three-point-per-side path-continuity gate and is closer to the actual instantaneous discontinuity being tested. Calibration uses a dedicated analyzer that omits TF-mask and relation-graph generation. Family clustering has an explicit comparison budget; excessive speaker fragmentation collapses conservatively to one anonymous group rather than multiplying independence; and the acoustic stage has a five-minute watchdog plus stage-progress evidence.

Completed dev7 edges are not invalidated merely because they finished under the wider window. They retain their original provenance and may be carried forward; unfinished edges are rerun under dev8. No real campaign CLOCK_MEASURED map is claimed by packaging dev8.


## dev9 — source-conditioned trajectory geometry and CSVStream TSV authority

Field input: completed dev8 transfer bundles from physical ed209c and ed209h, preserving logical worker identities A/B/E and D/I respectively. Bundle SHA-256 values are recorded in `qualification/DEV8_RESULT_AUDIT.txt`. The transferred set contains 30 logical edge directories; eight are governed `UNRESOLVED` outcomes caused by `CALIBRATION_COMPLEXITY_EXCEEDED`. All five transferred worker-level `source_path_evidence.tsv` files contain zero data rows.

Inspection showed this zero-evidence result was not proof of absent acoustic information. Several successful edges contain admitted source groups and source path points, but dev8's real 16-second geometry could emit only one complete BEFORE and one complete AFTER point per source/path because the path extractor used an 8-second window / 4-second step. The inherited `AudioV9EdgePathContinuityFitter` minimum is three points per side. Those paths were therefore guaranteed to be rejected as insufficient trajectories. The older qualification fixture used 32 seconds and did not expose the mismatch.

Dev9 changes the source-conditioned spatial scan to 4 seconds / 2 seconds while retaining the 16-second seam-local acoustic interval and the strict three-points-per-side fitter. The new 16-second regression emits exactly the required three BEFORE + three AFTER observations per admitted source/path. It produces 36 total path points on the two-source fixture and four exact-authority fits: SRC_A DIRECT and REFINED recover the true -3 sample discontinuity; SRC_B remains estimator-conflicting (+255 / -1168 in the fixture), so the downstream independent-group solver remains fail-closed.

Dev9 also establishes a project-wide structured TSV read boundary: `AudioV9TsvReader` wraps the stock ooRexx `CsvStream` with TAB delimiter and returns field arrays. Production structured-table readers migrated in dev9 include source mask/path/evidence tools, v2 decode/spatial observation tools, source-conditioned job planning, edge calibration planning, legacy migration/audit, family list ingestion and v2 solver evidence ingestion. Plain one-column filename lists are intentionally not treated as TSV. No bespoke CSV/TSV parser is introduced.

The r13196 `CsvStream` parser preserves adjacent empty fields but drops one final empty field when the physical record ends with a delimiter. Audio V9 repairs only that representational edge at the adapter boundary using `CsvStream~rawText`; quoted/delimited parsing remains the runtime's responsibility. This specifically preserves the empty `login` column for ed209e in `campaign/WORKERS.tsv` as a seven-field array.

No existing dev7/dev8 result is mutated. Dev9 is required before source-conditioned path evidence is regenerated/promoted; the corrected dev6 clock rule remains unchanged: only `CLOCK_MEASURED`, supported by at least two independent agreeing groups, moves cumulative correction.

## 2026-09-11 dev9-hotfix1

Fleet observation after sealed dev9 deployment:
- physical ed209c completed logical A/B then stopped logical E at edge 018 on
  exit 168 / CALIBRATION_COMPLEXITY_EXCEEDED;
- physical ed209h processed logical D edges 013-015 then stopped at edge 016 on
  the same governed complexity outcome;
- corpus gates passed and no runaway process remained;
- the missing behavior was the dev8 operator hotfix that converted this one
  bounded condition into an UNRESOLVED seam and continued later jobs.

Hotfix1 makes that behavior part of the packaged authority.  It also supports
resume from an existing sealed-dev9 `FAILED.tsv` for that exact condition
without recomputing the edge.  Genuine runtime/corpus/execution failures are
unchanged and remain fatal.

## dev10 processing-first reconstruction

Dev10 freezes global file-edge calibration as advisory/unresolved where no
independently-supported CLOCK_MEASURED evidence exists and moves into production
reconstruction.  It adds bounded local spatial reconstruction with 4 s context
halo, 8 s scan windows, 2 s scan steps, exact core cropping, seven-worker float
outputs, and a single final Vorbis encode.  No unresolved seam advances a global
clock correction; local FC/FD lag is estimated afresh from each processing
window.  The first full pass intentionally omits the expensive acoustic graph
and TF-mask stage so a complete chronological voice master can be produced and
reviewed before selective second-pass enhancement.

## dev11 loud-event echo survey authority

Dev11 continues dev10 reconstruction unchanged and adds a diagnostic acoustic
survey.  The trigger is the observation that the CCTV recordings contain many
very high, sharp events (door bangs, cat vocalisations, alarms and road events)
which can act as naturally occurring room probes.  The survey never infers
noise identity from amplitude alone and never modifies audio.

The first transient onset is used as a short matched-filter template.  Native
sample-level correlation examines only the next 80 ms and scores neighbourhoods
around the declared property hypotheses 8.75, 17.50, 22.09, 23.32, 24.74,
26.04 and 58.30 ms.  FC/FD relative arrival is independently searched within
±35 ms.  Absolute correlation is used so a reflected waveform may invert.

High-peak admission is relative to the preceding local one-second RMS with a
50 ms guard.  Events are clustered inside 120 ms so the reflection family under
study cannot be double-counted as new physical events.  A best echo score below
0.70 remains `WEAK_OR_UNMODELED` and receives no physical pattern authority.
The region/pattern labels are therefore hypotheses for repeated-event analysis,
not source identity labels.

The synthetic qualification contains three independent cases: an FD-leading
door/stairwell probe with -177 sample FC/FD lag and strong 187/466 sample FD
returns; an FC-leading road-side probe with +140 sample FC/FD lag and a 140
sample FC return; and a mobile/unconstrained probe with a deliberately unmodeled
35 ms return.  The first two are recovered strongly; the third remains
unresolved despite having a strong cross-feed match.


## dev12 feed-relative survey and Graph dev5 authority

The dev11 scanner remains packaged and callable unchanged so the completed dev11
survey is reproducible.  Dev12 adds a separate native/Rexx v2 survey API rather than
silently changing the dev11 TSV contract.

The correction is grounded in the completed real dev11 survey archives:

- night 2023-10-09 21:00 through 2023-10-10 01:00:
  `dfc1a8c6141530a145047068085a1a1428321e84d5cfcbecef2719381a091fd3`;
- daytime 2023-10-10 10:00 through 14:00:
  `6a8615d3b946851f3d6c716980948807273a486170a27f6303d15fd5b7ff4f20`;
- immutable derived analysis bundle:
  `b98e1ba31d4c49ce318f56a027bbd66be0a82395ad505d8dbe083c0575532c98`.

Both surveys completed 24/24 bounded ten-minute chunks.  The merged dev11 evidence
contains 467 admitted events: 462 daytime and five night.  Every admitted event was
FC-triggered and no `FD_STAIRWELL_PATTERN` event was produced.  The real data showed
a median daytime FC peak of about 0.719 versus median FD peak about 0.0072, while the
largest observed FD peak remained below dev11's shared absolute 0.50 trigger floor.
This is evidence of an admission-scale defect, not evidence that FD-side physical
events are absent.

The same analysis found that the modeled families are highly overlapping: 436/462
daytime events had at least two families at or above 0.70 somewhere across the two
feeds, and 276/462 had all seven.  Of 402 rows with cross-feed score at or above
0.70, 74 (18.4%) placed the selected family maximum exactly on a +/-1 ms search
boundary.  Dev12 therefore records ambiguity and boundary contact explicitly rather
than promoting the numerical maximum to path identity.

V2 feed admission compares each feed with its own guarded baseline; event clustering
selects the largest normalized trigger ratio.  The output separates trigger feed,
matched acoustic leader, best echo feed and best echo family.  Every feed/family
pair retains measured lag, score and boundary status.  No audio samples are changed.

The current presentation dependency is ooRexx ML Graph v0.1-dev5 SHA-256
`24659562d1e5ca86a08bc3156f838eebd1e320a45e3e8969979fe7dde3b69d40`.
It is qualified against the exact pinned ooRexx ML v0.1-dev11 and keeps renderer
authority strictly downstream of immutable semantic evidence.  Historical sections
below that record earlier dev3 pins describe those historical release states and are
not rewritten.

## dev13 search-landmark provenance

Dev13 is a search/provenance increment over sealed dev12. It does not change the dev12 native echo scanner, reconstruction semantics, clock solver, or graph authority.

A user-supplied listening observation establishes the first landmark: FC raw video `/run/media/hc3/1A52-190F/masvid/Master Video Library/fc/20231010_070249_tp00019.mp4`, nominal file start `2023-10-10 07:02:49`, with the observed phone-call reference at `2023-10-10 07:13:12`. The user reports the call is clearly audible when listening to the raw FC video in VLC at 200% volume, describes discussion about international police coordination, and identifies following audio as intercepted. Dev13 preserves those statements as `USER_ANNOTATED` evidence and does not claim that the executable independently establishes the semantic interpretation.

`AudioV9VoiceClock` independently verifies the declared in-file offset as exactly 623 seconds: file serial `63832518169`, anchor serial `63832518792`. `tests/test_search_landmark.rex` asserts the registry schema, single-row identity, feed, offset, anchor serial, annotation authority/status and listening method.

The default landmark probe is bounded to 300 seconds total (60 seconds before / 240 seconds after). It decodes canonical FC and FD material with the existing exact-sample geometry path, preserves the resulting PCM for later speech/graph inspection, and runs the dev12 loud-echo-v2 scanner only as auxiliary acoustic evidence. Absence of a loud-event row must not be interpreted as absence of speech.

## dev14 prior-free recurrence provenance

Dev14 is grounded in user-supplied archive
`ed209c_dev12_echo_51jobs_2100_0530.tar.gz`, SHA-256
`1168d49aeef2093003691cb189e4e8f00675c08bef8cb72f2001f78d4183aed0`.
The archive contains all 51 expected dev12 v2 ten-minute TSV/meta pairs from
21:00 through 05:30. It is evidence input only and is not embedded in this package.

The merged evidence contains 10,983 events (FC trigger 5,767; FD trigger 5,216),
9,759 `MULTI_FAMILY` rows, and only 400 `SINGLE_FAMILY` rows. The median
best-minus-second score margin is about 0.01031. The named search windows therefore
remain hypotheses rather than discovered identities.

The same campaign exposes two additional measurement conditions. First, 96 rows
land exactly at the current +/-35 ms FC<->FD search endpoint, including 45 with
strong cross-feed correlation. Those rows are censored. Second, 369 event rows
show exact local FC zero peak and zero baseline while FD remains active, spanning
approximately 00:06:14.398 through 00:34:31.263 in event evidence. No cause is
asserted from the TSV alone.

V3 preserves the complete v2 row and appends evidence only. Its 6..80 ms global
recurrence search is implemented independently of `g_echo_hyp`; it returns four
bounded same-feed matched-filter maxima per feed with 3 ms non-maximum separation.
This provides a non-circular input for later ML dev11 constant-delay/wobble analysis.
Applying wobble only to observations already selected inside one named +/-4 ms
family window is explicitly not considered independent proof of room geometry.

Synthetic v3 qualification adds a fifth low-gain cross-feed fixture at exactly
35 ms to prove censoring evidence. Existing dev11 and v2 tests remain separately
executable; no sealed prior survey result is rewritten.


## dev16 reflection-aware whisper reconstruction authority

Dev16 descends from qualified dev15 candidate SHA-256 `578751260b1084dc6a1532331fa4336ac85e0f1599e7687f9e5d812656c9fd4f`. The dev15 master gate was rerun on 2026-09-12 using the user-supplied ooRexx 5.3.0 r13196 package and completed with return code 0, including the 32,405-assertion spatial coordinator, quality-graph pipeline and reconstruction-processing tail.

The semantic increment is intentionally bounded. It does not modify native DSP, loud-echo v1/v2/v3 detection, file-edge clock authority, TF-mask policy, ML dev11, ML Graph dev5, or the original corpus/campaign evidence. It adds a new evidence/planning layer for low-level whisper reconstruction under time-varying propagation.

Authority rule: **audio establishes an acoustic path; video may corroborate but cannot create it.** Vehicle presence/geometry is therefore incapable of promoting a weak acoustic mismatch into fusion authority. Transient reflected gain is treated as propagation-state evidence and does not redefine source loudness or the whisper gain reference. Loud/impulsive observations are explicitly separated from whisper gain control and retained as independent acoustic-probe evidence.
