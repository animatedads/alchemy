# Camera Behaviour ooRexx v0.56

v0.56 makes learned scene memory participate directly in primitive assessment while preserving every underlying observation.

`CameraSceneAwarePrimitiveAssessment` combines the existing `CameraLumaPrimitiveQuality` result with the current source-scoped `CameraSceneGenerationMemory`. An admitted motion primitive remains `ADMITTED_MOTION`. A rejected primitive landing in a coarse zone with recurring nuisance evidence becomes `EXPECTED_SCENE_ACTIVITY`; a rejected primitive in a historically unseen nuisance zone remains `NOVEL_LOW_QUALITY_FRAGMENT`. If scene context is unavailable or belongs to a different source key, assessment fails closed as `NO_SCENE_CONTEXT`.

The scene explanation is contextual evidence only: it does not delete the primitive, change its base quality reason, create an identity, or silently promote/reject peer evidence. `CameraSceneAwareQualitySet` preserves one assessment per input temporal track and exposes filtered expected/novel/admitted views.

A recurring zone may explain a new fragment even when the exact nuisance reason changes. In the real fixture sequence, the first two clips learn `TOO_SHORT` nuisance evidence at zones `5,4` and `11,5`; in the third clip those same zones produce `STATIC_FRAGMENT`. v0.56 explains those two as expected scene activity while fragments at `6,4` and `7,4` remain novel.

`CSB1` remains an absolute barrier. A fresh post-barrier scene generation inherits no recurring nuisance zones, so scene-aware explanation cannot cross a detected source change. Its numeric `SG<n>` ordinal depends on whether earlier clips already opened additional generations.

v0.56 is fully requalified on Foreign Runtime v0.20.0.

New focused suite: `test_camera_scene_aware_primitive_context.rex`.

# Camera Behaviour ooRexx v0.55

v0.55 adds source-scoped scene memory across clips.

`CameraSceneFingerprint` is a compact, identity-free description of one source segment built from active-cell topology plus the anonymous direction profile. Scene continuity uses 80% active-topology coverage and 20% direction-distribution similarity. `CameraSceneMemory` keeps a current learned generation per caller-supplied source key and continues it only when the new segment fingerprint remains above the configured similarity threshold (0.65 by default). A detected in-file `CSB1` source barrier always forces a fresh scene generation regardless of similarity.

`CameraSceneGenerationMemory` accumulates exact per-cell evidence across accepted clips: number of observed segments, number of active segments, active-segment share, mean persistence when active, and maximum residual. It also records low-quality temporal fragments by rejection reason and coarse zone. A fragment becomes a known recurring scene artifact only after the same reason/zone appears in at least two distinct clip tokens.

On the three supplied ordinary same-camera clips, all three remain in one scene generation (`SG1`), with fingerprint similarities 0.6955 and 0.90 for clips two and three respectively. The learned generation accumulates 177 comparisons and discovers five recurring low-quality artifact zones. The first segment of `1000053603.mp4` continues `SG1`; its detected 59970 ms source barrier forces the second segment into fresh `SG2` with no inherited scene artifacts.

This memory is scene context, not identity. It does not connect people, vehicles, plates, or `LT<n>` objects across clips.

New focused suite: `test_camera_cross_clip_scene_memory.rex`.

# Camera Behaviour ooRexx v0.54

v0.54 turns source-discontinuity evidence into an executable state barrier.

`CameraFFmpegMediaSource~analyzeSegmentedScene()` performs an independent source-boundary pass and activity pass, then partitions the activity evidence into source-local generations. The structural comparison that actually crosses a `CSB1` boundary is deliberately assigned to neither generation: it is evidence of source replacement, not movement.

Each `CameraSourceSegment` receives a fresh generation (`G1`, `G2`, ...), a fresh clip-local `LT<n>` track namespace, an exact segment-local activity/persistence prior rebuilt from retained per-comparison delta vectors, and a segment-local direction profile. `CameraLumaBehaviourBridge~segmentedPeerOutliers()` runs quality filtering and peer comparison independently for every generation, preventing peer populations from crossing a source change.

For the two supplied mixed-camera 119.94-second fixtures, the detected 59970 ms boundary yields two 60-sample generations. Comparisons 1-59 belong to G1; comparison 60 is the source-change barrier and is excluded from movement state; comparisons 61-119 belong to G2. Each generation therefore has 59 ordinary comparisons.

New focused suite: `test_camera_source_barrier_state_reset.rex`.

# Camera Behaviour ooRexx v0.53

v0.53 adds explicit source-discontinuity evidence, compact scene-cell priors, and a coarse anonymous direction profile.

`CameraFFmpegMediaSource~analyzeSourceBoundaries()` samples decoded luminance on the established 16x9 grid, removes frame-global luminance, and compares both local residual replacement and neighbour-gradient structure. A source change is admitted only when a large fraction of cells change together, structural replacement is strong, and the sampled scene is locally stable immediately before and after the transition. This separates a persistent camera/source cut from ordinary local motion and from broad luminance-only changes.

Boundary time is derived from decoded `AVFrame.pts` and the selected `AVStream.time_base`; no midpoint or frame ordinal is supplied to the detector.

`CameraLumaScenePriorSet` records per-active-cell maximum residual and persistence fraction (`changeCount / comparisonCount`). `CameraLumaDirectionProfile` aggregates anonymous temporal primitive steps into up/down/left/right/diagonal/stationary counts.

On the two supplied 119.94-second mixed-camera fixtures, the detector independently finds one source boundary in each at media PTS 59970 ms. The ordinary one-camera 59.97-second fixture produces no boundary.

New focused suite: `test_camera_source_boundary_scene_profile.rex`.

# Camera Behaviour ooRexx v0.52

v0.52 introduces a conservative quality gate between direct luminance temporal primitives and peer-relative behaviour comparison.

`CameraLumaPrimitiveQuality` evaluates only clip-local geometric evidence: observation count, moving versus stationary steps, direction reversals, frame-edge contact, and region-size stability. It produces an explicit score, admission flag, and rejection reason such as `TOO_SHORT`, `STATIC_FRAGMENT`, `EDGE_DOMINATED`, `SIZE_UNSTABLE`, `DIRECTION_UNSTABLE`, or `LOW_COHERENCE`.

The gate is not a semantic object classifier. It does not claim that an admitted primitive is a person, vehicle, or physical object; it only says that the coarse luminance track is coherent enough to participate in peer movement comparison.

New qualified bridge surfaces are `qualifiedTracks`, `qualifiedBehaviourVectors`, and `qualifiedPeerOutliers`. The older raw bridge methods remain available for diagnostic/backward-compatible comparison.

On the exact three CCTV fixtures with the established reducer/tracker settings, persistent temporal vectors reduce from 19/10/3 to 13/3/0 qualified vectors. At the existing peer thresholds, raw outlier counts of 6/5/0 reduce to 1/0/0.

v0.52 requalifies the native media path on Foreign Runtime v0.17.2.

New focused suite: `test_camera_luma_primitive_quality.rex`.

# Camera Behaviour ooRexx v0.51

v0.51 connects the direct decoded-video temporal primitives to Camera's existing peer-relative behaviour model.

`CameraLumaBehaviourBridge` converts clip-local `CameraLumaTemporalTrack` regions into ordinary `CameraTrack` observations using the known 16x9 grid geometry and sample cadence. From there the existing `CameraTrackBehaviourVector` and `CameraPeerOutlierModel` are reused unchanged. The direct MPEG path can therefore now produce the same normalized DX/DY/LENGTH/SPEED/STRAIGHT peer evidence that previously required externally supplied tracks.

This is deliberately an evidence bridge, not a semantic classifier. `LT<n>` tracks are coarse luminance-motion primitives. A peer outlier means a primitive's movement geometry differs from comparable primitives; it does not mean a person, vehicle, offence, or identity has been recognized.

v0.51 requalifies the media path on Foreign Runtime v0.17.1. Its Python zero-copy provider is not required by Camera v0.51, but becomes available for future optional numerical providers.

On the three exact fixtures, the direct path produces 19, 10 and 3 persistent behaviour vectors. The first two therefore enter peer comparison; the third is correctly suppressed for insufficient peers.

New focused suite: `test_camera_direct_media_peer_behaviour.rex`.

# Camera Behaviour ooRexx v0.50

v0.50 makes the adaptive luminance representation temporal.

Every sampled-frame comparison now produces a photometric-normalized changed-cell mask. Four-neighbour changed cells are grouped into transient `CameraLumaTemporalRegion` rectangles. Regions on successive samples are linked one-to-one by overlap or bounded grid-centre distance into anonymous `CameraLumaTemporalTrack` primitives.

These `LT<n>` identifiers exist only within the clip analysis. They are not people, plates, persistent identities or external lookups. A track retains only sample span, observation count, coarse-grid displacement, path length and maximum luminance residual.

`CameraLumaActivityMap~temporalTracks` exposes the compact `CLT1` temporal representation alongside the v0.49 spatial hierarchy. Thus Camera can now distinguish a cell that changed once from a rectangle that persists and moves through successive sampled frames.

The three fixtures produce 61/36/7 transient changed regions and 23/16/4 clip-local tracks respectively; the quieter third clip collapses to only four temporal primitives, three of which persist across two sampled comparisons.

New focused suite: `test_camera_temporal_luma_primitives.rex`.

# Camera Behaviour ooRexx v0.49

v0.49 adds the first explicit boxes-in-boxes adaptive spatial representation.

`CameraLumaActivityMap~hierarchy()` converts the fixed fine activity grid into a recursive rectangle tree. A node containing no active fine cells is represented once as one `INVARIANT` box and is never subdivided. A node containing activity subdivides into rectangular children until activity is spatially isolated or the configured maximum depth is reached. The hierarchy therefore preserves exact fine-grid activity evidence while spending leaf records only where local change forces extra detail.

`CameraLumaActivityHierarchy` reports the original fine-cell count, adaptive leaf count, invariant/active leaf counts, saved leaf records, leaf share and maximum depth. `CLH1` is a deterministic compact representation of the leaf rectangles.

This release rebases the media boundary on the user-supplied Foreign Runtime v0.14.0, which upstreams the borrowed typed-struct APIs Camera needs (`structView`, `pointerAt`, `peekBytes`) onto its callback/resource/address-space baseline.

The real fixture leaf counts are 67, 58 and 25 versus 144 fine cells; the quiet third clip therefore represents the complete coarse spatial state with only 17.4% as many leaf boxes.

New focused suite: `test_camera_adaptive_luma_hierarchy.rex`.

# Camera Behaviour ooRexx v0.48

v0.48 begins the actual fixed-camera invariant-reduction stage.

`CameraFFmpegMediaSource~analyzeLumaGrid()` decodes the video directly, samples the Y plane at a fixed 16x9 spatial grid (configurable), compares successive sampled frames, and marks only cells whose luminance changes by at least a configurable threshold. The resulting `CameraLumaActivityMap` retains active/invariant cell counts, invariant share, change observations, and compact per-active-cell evidence.

The default acceptance samples every 15th decoded frame, so each one-minute 900-frame CCTV clip contributes 60 spatial samples and 59 temporal comparisons. This is intentionally a coarse first-stage reducer, not semantic CV: it asks which fixed regions materially changed, not what or who caused the change.

Historical v0.48 used Foreign Runtime v0.13.1. v0.49 requalifies this media path on supplied Foreign Runtime v0.14.0, where the borrowed typed-struct APIs are upstream and no Camera-specific Foreign Runtime branch is required.

On the three exact CCTV fixtures at threshold 12, the reducer retains 33/144, 38/144, and 8/144 active cells respectively; the quietest clip therefore discards 94.4% of coarse spatial cells as invariant at this stage.

New focused suite: `test_camera_luma_activity_reduction.rex`.

# Camera Behaviour ooRexx v0.47

v0.47 completes the first direct decoded-frame path from the supplied CCTV MP4s into ooRexx.

It depends on Foreign Runtime v0.11.1, whose borrowed typed struct views allow Camera to traverse `AVFormatContext.streams[]`, inspect `AVStream.codecpar`, copy codec parameters into an `AVCodecContext`, select the video packets, receive real `AVFrame` objects, and read bytes from the Y (luminance) plane.

`CameraFFmpegMediaSource~decodeVideoFrames()` returns a compact `CFD1` decode inspection containing packet/video-packet/frame counts, geometry, pixel format, luma linesize and a small first-frame Y-plane byte sample. The supplied three motion-triggered CCTV fixtures each directly decode to 900 640x360 YUV420P frames.

No `ffmpeg`/`ffprobe` subprocess is spawned and no FFmpeg-specific C shim is present. `CameraCore.cls` remains container/codec agnostic.

New focused suite: `test_camera_ffmpeg_frame_decode.rex`.

# Camera Behaviour ooRexx v0.46

v0.46 advances the direct Foreign Runtime/FFmpeg media boundary from container inspection to real packet demux.

`CameraFFmpegMediaSource~demuxPackets()` allocates a genuine `AVPacket` through `libavcodec`, repeatedly calls `av_read_frame` on the live `AVFormatContext`, unrefs each packet with `av_packet_unref`, and reports deterministic packet count / terminal FFmpeg status / libavcodec version as `CameraFFmpegPacketInspection`. No `ffmpeg` or `ffprobe` subprocess is used.

The three supplied motion-triggered CCTV MP4s each demux to 1,837 packets on the qualified FFmpeg 61 ABI. Limited reads are also supported for streaming/probe use.

A direct H.264 decoder experiment identified the remaining clean-ABI boundary: MP4 decoding requires `AVStream.codecpar`/extradata, while Foreign Runtime v0.11.0 does not yet expose a typed struct view over borrowed `AVStream *` memory. v0.46 records that boundary explicitly in `FFMPEG_DECODE_BOUNDARY.md` instead of adding a command-line fallback or FFmpeg-specific C shim.

New files: `camera_ffmpeg_avcodec.bridge.json`, `FFMPEG_DECODE_BOUNDARY.md`, and `test_camera_ffmpeg_packet_demux.rex`.

# Camera Behaviour ooRexx v0.45

v0.45 introduces the first direct media-source boundary. `CameraFFmpegMediaSource` uses ooRexx Foreign Runtime v0.11.0 to call the real FFmpeg `libavformat` ABI directly from ooRexx. It does not spawn the `ffmpeg` or `ffprobe` command-line programs and does not add an FFmpeg-specific C shim.

The initial boundary is intentionally demux/inspection only: open a container through `avformat_open_input(AVFormatContext **)`, load stream information, and discover the best video/audio stream with `av_find_best_stream`. Decoded-frame materialization is the next layer. `CameraCore.cls` remains media-format agnostic; the FFmpeg adapter is a separate optional source file.

The v0.45 acceptance run directly opens the three supplied motion-triggered CCTV MP4 fixtures through Foreign Runtime and FFmpeg. All three expose a valid video stream and audio stream.

Camera v0.45 also requalifies the existing core against ooRexx Crypto v0.4 while retaining Alchemy Objects v0.8.

New files: `CameraFFmpegMediaSource.cls`, `camera_ffmpeg_avformat.bridge.json`, `test_camera_ffmpeg_media_source.rex`, and `MEDIA_FIXTURES.md`.

# Camera Behaviour ooRexx v0.44

v0.44 adds identity-free peer-relative transient-track outlier analysis.

`CameraTrackBehaviourVector` reduces each transient track to dimensionless movement geometry: box-scale-normalized X/Y displacement, normalized trajectory length, normalized speed, and path straightness. `CameraPeerOutlierModel` then compares each track only with same coarse object-type peers using per-feature peer medians and median absolute deviation (MAD). A track is an outlier only when multiple movement features depart materially; one odd scalar is insufficient by default.

The resulting `CameraPeerOutlierSet` is deliberately small and retains only transient track ids, peer-relative scores and the strongest departure dimension. It does not identify people or objects against an external database.

`CameraClipProcessor` now materializes this peer-relative assessment into `CameraClipSummary~peerOutliers` from the actual tracks participating in that clip.

The focused regression models three mutually ordinary tracks A/B/C and a fourth transient track D with different geometry. Only D is classified as an outlier. It also proves that proportional pixel/box scaling preserves the normalized feature vector and that groups with fewer than three peers produce no judgement.

New focused suite: `test_camera_peer_outlier.rex`.

# Camera Behaviour ooRexx v0.43

v0.43 propagates the v0.42 compact producer identity through the complete trend and persistent-regime pipeline.

`CameraSignatureTrendModel` now partitions history by learned generation + producer token + day class + environment. `CameraSignatureTrendSnapshot`, window snapshots, `CameraSignatureTrendCondition`, and `CameraSignatureTrendRegime` retain the producer token. A Camera upgrade or assessment-contract/implementation change therefore starts a fresh trend comparison population and closes any active persistent regime instead of being interpreted as movement-pattern change.

`CameraAssessmentSignatureDelta` also exposes `producerChanged`, allowing adjacent compact signatures to state explicitly that the producer changed even when their learned generation and behavioural metrics did not.

This is deliberately conservative: producer identity is part of comparability, not part of the behavioural metric vector.

New focused acceptance suite: `test_camera_producer_partitioned_trend.rex`.

# Camera Behaviour ooRexx v0.42

v0.42 rebases Camera on Alchemy Objects v0.8 and binds a compact production identity to every generation-pinned assessment.

The learned-world generation and the producer identity are separate historical axes. `generationId` identifies what the camera had learned. `CameraProductionIdentity` identifies the Camera/Alchemy implementation and declared assessment contract that produced the evidence. It retains Camera package version, Alchemy base version, assessment contract id/revision, a Camera contract-shape id, construction provenance, and inheritance-integrity fingerprints.

The complete identity retains SHA-512. The long-running compact condition signature carries a 96-bit producer token (`|P=<24 hex>`), adding only 27 characters. This token is evidence identity, not authorization.

Alchemy v0.8 cooperative interposition is preserved, allowing Camera execution-provenance instrumentation to coexist with compatible logging/interposition providers.

New focused suite: `test_camera_production_identity.rex`.

# Camera Behaviour ooRexx v0.41

v0.41 activates Alchemy Objects v0.7 execution provenance on the three externally important Camera assessment/trend pipeline methods: `assessSummaryAtGeneration`, `observeAssessmentTrend`, and `observeAssessmentTrendState`.

Alchemy's v0.7 wrapper records method contract id/revision/fingerprint, implementation origin, construction provenance, inheritance-integrity fingerprint, security runtime profile, outcome and result-contract status for retained executions. Camera keeps the ledger bounded at 128 records. This is infrastructure evidence only: it does not change Camera's behavioural judgement or add policy authority.

The supplied 2026-08-24 roll-up still carries the exact accepted `alchemy_objects_v0.7.zip` while surrounding components have advanced substantially. v0.41 therefore stays on the v0.7 house contract and begins using its execution-provenance machinery rather than introducing a new dependency version.

New focused suite: `test_camera_execution_provenance.rex`.

# Camera Behaviour ooRexx v0.40

v0.40 rebases Camera on Alchemy Objects v0.7 and adds persistence/recovery over the compact overlapping trend stream.

The Alchemy-derived Camera classes now use the preferred non-virtual `self~init:super(...)` construction chain and declare the complete STANDARD adoption metadata set. Acceptance requires the v0.7 `AlchemyAdoptionVerifier` to pass and construction provenance to report `entrypoint=INIT`; `initAlchemy(...)` is no longer used by Camera.

`CameraSignatureTrendPersistenceModel` consumes immutable `CST1` trend snapshots. A configurable number of simultaneously trending overlapping windows constitutes a shifted sample; repeated shifted samples progress EMERGING -> PERSISTENT and open a `CTR<n>` regime. Expected samples progress PERSISTENT -> RECOVERING -> STABLE and close the regime. Generation/day/environment context changes reset persistence so a daylight/night or G17/G18 boundary cannot prolong a behavioural regime.

New focused acceptance suite: `test_camera_alchemy_v07_trend_persistence.rex`.

# Camera Behaviour ooRexx v0.39

v0.39 adds an overlapping compact-signature trend model for fixed-camera condition tracking.

`CameraSignatureTrendModel` consumes the tiny v0.36 `CameraAssessmentSignature` objects rather than frames or full explanatory evidence. By default it maintains overlapping 300-second, 900-second, and 3600-second windows. Each window derives per-metric first/last/average/min/max quantized z, elevated share, delta, and deterministic rising/falling/stable state.

History is partitioned by learned generation, day class, and environment code. A transition from daylight to artificial night, weekday to weekend, or G17 to G18 therefore starts a new comparison population instead of appearing as a behavioural trend. This directly preserves the time/environment safeguards behind the original CCTV design.

`CameraModel~observeAssessmentTrend` exposes the model through the Alchemy-derived Camera facade and emits `CAMERA.TREND.OBSERVE` instrumentation. Trend snapshots are immutable and have a small `CST1` compact representation suitable for long-running condition histories.

New focused acceptance suite: `test_camera_signature_trend.rex`.

# Camera Behaviour ooRexx v0.38

v0.38 adds graduated semantic disclosure over generation-pinned Camera assessments.

`CameraClipAssessment~disclosure(profile)` supports `PUBLIC`, `CUSTOMER`, `INTERNAL`, and `FULL`. PUBLIC is the tiny v0.36 condition signature. CUSTOMER adds bounded metric explanation (observed/expected/z/support/context) but no contributing-window/model internals. INTERNAL exposes the complete frozen Camera assessment evidence including contributing overlapping windows, learned-world counts, and event grammar. FULL adds Alchemy object identity and telemetry/instrumentation summary.

These are immutable semantic views, not an authorization substitute. Security-sensitive remote introspection should still use the inherited Alchemy sealed-introspection/capability machinery. Camera merely defines what each semantic disclosure tier contains.

New focused acceptance suite: `test_camera_graduated_disclosure.rex`.

# Camera Behaviour ooRexx v0.37

v0.37 is the first incremental migration onto the shared **Alchemy Objects v0.4.3** base-class infrastructure.

`CameraModel`, `CameraLearnedGeneration`, and `CameraAssessmentEvidence` now subclass `AlchemyObject`. The migration is intentionally selective: small Camera value objects such as boxes, points, compact signature metrics, and relation tokens remain ordinary domain objects rather than inheriting infrastructure for its own sake.

The three Alchemy-derived Camera surfaces retain Camera's existing semantic responsibilities but now inherit common identity, metadata, requirement declarations, method contracts, telemetry/instrumentation, disclosure-labelled state descriptions, detached relationships, compliance/introspection surfaces, and optional cryptographic evidence integration. Camera does **not** gain policy authority from this change.

Camera uses detached Alchemy relationships rather than retained object links for cross-object evidence: a camera records published generations and generations record their producing camera without making telemetry an ownership graph. Generation publication, pinned assessment, immutable-generation matching, and metric-evidence attachment emit declared instrumentation events.

The dependency is external and explicit: `AlchemyObject.cls` from `alchemy_objects_v0.4.3` and its declared `oorexx_crypto_v0.1` dependency must be on `REXX_PATH`. No Alchemy source is vendored into this Camera package.

New focused acceptance suite: `test_camera_alchemy_base.rex`.

# Camera Behaviour ooRexx v0.36

v0.36 adds a tiny deterministic condition signature and signature-delta layer on top of generation-pinned assessment evidence.

`CameraAssessmentSignature` reduces the full evidence object to a stable context header plus one compact metric token per assessed metric. Z-scores are clipped and quantized to signed eighth-sigma units, metric names use fixed two-character codes, and the full evidence remains available separately when exact explanation is required.

`CameraAssessmentSignatureDelta` compares two signatures without video or mutable model access. It reports per-metric residual change, state changes, maximum/mean absolute residual movement, elevated-count change, and explicitly flags generation, day-class, and environment changes. This separates scene trend from model drift and context drift instead of silently mixing them.

New focused acceptance suite: `test_camera_assessment_signature.rex`.

# Camera Behaviour ooRexx v0.35

v0.35 adds compact immutable evidence to generation-pinned clip assessment.

Every `CameraGenerationClipComparator` result now carries a `CameraAssessmentEvidence` object identifying the exact learned generation, publication time, clip/time/day/environment context, compact learned-world counts, and frozen event-grammar settings. Each assessed metric has `CameraAssessmentMetricEvidence` retaining observed/expected/z/support/state, the selected baseline family (`ALL`, `DAY`, or `ENV`), and — for temporal/calendar baselines — the exact overlapping frozen windows that contributed, including their applicability weight and local distribution support/mean/deviation.

This is evidence, not policy. Camera still makes no operational disposition. The object is designed so HardWorld, Structured Relation, NoSQLServer, Queue Fabric or another consumer can inspect or project why Camera reached an assessment without rerunning the mutable learner.

New focused acceptance suite: `test_camera_assessment_evidence.rex`.

# Camera Behaviour ooRexx v0.34

v0.34 makes immutable learned-world generations directly executable for clip-baseline assessment.

`CameraGenerationClipComparator` evaluates a `CameraClipSummary` only against the frozen distributions held by a selected `CameraLearnedGeneration`; it never consults the live learner. `CameraClipAssessment` now carries the generation ID that judged it, and `CameraModel~assessSummaryAtGeneration` provides explicit historical replay.

Frozen behaviour windows now implement the same triangular time weighting used by the live model. Frozen calendar contexts can provide day-class-specific metric estimates, and frozen environment profiles provide environment-specific metric estimates. This means an old clip can be reassessed against G1 after the live model has learned radically different traffic or illumination baselines, and the G1 result remains unchanged.

New focused acceptance suite: `test_camera_generation_assessment.rex`.

# Camera Behaviour ooRexx v0.33

v0.33 extends the immutable learned-world generation with three interpretation surfaces that must remain stable under old evidence: event-grammar thresholds, the compact-stream token dictionary, and learned current-condition regime memory.

`CameraTokenDictionarySnapshot` freezes token↔text mappings so a compact CBT stream associated with a published generation can still be decoded later even after new tokens are allocated. `CameraEventGrammarSnapshot` freezes the thresholds that determine STOP/CLOSE/APPROACH/SEPARATE/route-deviation semantics. `CameraConditionMemorySnapshot` freezes current-condition configuration plus completed condition regimes and recurring regime classes; deliberately ephemeral rolling recent-observation buffers and an in-progress active regime are not treated as learned-world state.

New focused acceptance suite: `test_camera_generation_condition_tokens.rex`.

# Camera Behaviour ooRexx v0.32

v0.32 completes another major part of the immutable learned-world generation: higher-order grammar, learned spatial zones, and calendar-conditioned behaviour.

Each `CameraLearnedGeneration` now additionally freezes learned `CameraZone` centroids/support, recurrent interaction episodes, recurrent event/episode motifs, and the weekday/weekend `CameraCalendarBehaviourModel`. Calendar contexts deep-freeze their own overlapping behaviour windows and scalar distributions, preserving exactly how weekday/weekend expectations differed when a generation was published.

The generation therefore carries not only scene geometry, routes, spatial primitives, motif transitions, time windows, and environment profiles, but also the learned higher-order vocabulary that turns primitive movement/events into recurring behavioural sequences.

New focused acceptance suite: `test_camera_grammar_calendar_generation.rex`.

# Camera Behaviour ooRexx v0.31

v0.31 extends each immutable learned-world generation into the temporal and environmental dimensions.

`CameraBehaviourModelSnapshot` deep-freezes every overlapping behaviour window, including route/event/episode/motif/transition weights, zone-event weights, scalar metric distributions, window support and totals. `CameraEnvironmentModelSnapshot` deep-freezes learned environment profiles, including adaptive structural/photometric thresholds, background luminance/structure distributions, ordinary metrics, and environment-signature metrics.

A published `G<n>` therefore now captures scene geometry + spatial primitives + routes + motif transitions + overlapping time expectations + environment/illumination expectations. Later learning cannot alter any of those frozen surfaces; a newer generation sees the changes instead.

New focused acceptance suite: `test_camera_temporal_environment_generation.rex`.

# Camera Behaviour ooRexx v0.30

v0.30 broadens the published `G<n>` object from a spatial-primitive generation into a genuine learned-world generation.

Each `CameraLearnedGeneration` now deep-freezes four semantic surfaces: the recursive nested scene geometry (`CameraRegionSnapshot`), the spatial behaviour primitive dictionary, the learned route dictionary (`CameraRouteSnapshot`), and the motif-transition dictionary (`CameraTransitionSnapshot`). Accessors return defensive collections and old generations remain addressable after newer generations are published.

`semanticCanonicalText` deliberately excludes the mutable lifecycle flag (`PUBLISHED` / `SUPERSEDED`). Superseding G1 therefore changes registry lifecycle state without changing the semantic identity of the learned world G1 represents.

The regression mutates live scene geometry, adds new primitives/routes/transitions, and even directly changes existing live route/transition sample counts after G1 publication. G1 remains byte-for-byte stable while G2 sees the newer learned world.

New focused acceptance suite: `test_camera_learned_world_generation.rex`.

# Camera Behaviour ooRexx v0.29

v0.29 adds immutable learned-model generations without adding any dependency on Runtime Registry or Object Queue Fabric.

`CameraLearnedGenerationRegistry` publishes numbered generations (`G1`, `G2`, ...). A generation freezes the current spatial primitive dictionary as read-only `CameraSpatialPrimitiveSnapshot` objects, including the prototype relative-track encoding used for deterministic matching. Publishing a newer generation supersedes the prior generation for current use but keeps every older generation addressable.

Learning and reading are deliberately separated. `CameraModel~learnSpatialPrimitive(track)` mutates the live learning model. `CameraModel~matchSpatialPrimitive(track, generationId)` performs a read-only match against a pinned generation and cannot create or alter primitives. An unknown movement therefore remains explicitly `SPATIAL_MATCH_UNMATCHED` in the old generation even if the live model later learns it.

Every generation match is an immutable `CameraGenerationPrimitiveMatch` carrying generation id, source encoding/track identity, first/last timestamps, structural signature, primitive id, residual, and match state. This preserves the provenance needed to explain exactly which learned world judged an observation.

New focused acceptance suite: `test_camera_learned_generation.rex`.

# Camera Behaviour ooRexx v0.28

v0.28 adds recurrent spatial behaviour primitives on top of the v0.27 nested-region relation stream.

`CameraSpatialPrimitiveModel` groups relative-track encodings only when their structural token grammar agrees and their explicit geometric/time residual falls within a configured tolerance. The first example creates an `SBP<n>` prototype; later close matches reuse it, accumulate recurrence statistics, and expose mean/max residual. Large geometric deviations or different region-transition grammar create a new primitive instead of being forced into an existing class.

`CameraSpatialPrimitiveMatch` is an immutable evidence-bearing result. It retains the source encoding id, source track id, timestamps, sample/region-transition counts, structural signature, primitive id, match state, and exact residual. This deliberately mirrors the useful provenance principle in structured-relation-plugin v0.5 without adding a dependency: Camera compression may discard repetitive geometry, but the compressed token still says exactly which materialized observation justified it and how closely it matched.

New focused acceptance suite: `test_camera_spatial_primitive.rex`.

# Camera Behaviour ooRexx v0.27

v0.27 returns to the original boxes-in-boxes compression model.

`CameraBox` now supports full-box containment, canonical nested paths, and deterministic deepest-containing-region lookup. A track can be materialized as `.CameraRelativeTrackEncoding`: each point is expressed relative to the deepest stable region that contains it and quantized to four one-byte-scale values (relative centre X/Y and relative width/height).

The first observation in a region emits an `A` anchor. Subsequent observations in the same nested region emit only `D` time/geometry deltas. Crossing into a different containing region emits an `R` region anchor. Thus stable scene geometry becomes a spatial dictionary and routine movement is represented as relationship change rather than repeated absolute frame coordinates.

The relation/token objects are immutable snapshots; mutation of source track boxes after encoding cannot alter the materialized relation stream.

New focused acceptance suite: `test_camera_spatial_relation.rex`.

# Camera Behaviour ooRexx v0.26

v0.26 completes the Camera-side immutable materialization boundary.

`CameraModel~materializedState(condition)` now produces a `.CameraMaterializedStateSnapshot` containing a deep-frozen `.CameraCurrentConditionSnapshot`, the active `.CameraConditionRegimeSnapshot` when one exists, snapshots of completed regime history, and snapshots of the learned `.CameraConditionRegimeClass` dictionary.

The snapshot does not know about Virtual RYTA, Algorithm Relations, NoSQLServer, SQL, or any external consumer. It supplies a deterministic canonical semantic object that those layers may materialize independently.

All returned collections are defensive copies. Canonical text sorts completed regimes and regime classes, and regression tests mutate the live condition, active regime, completed regime, and learned class after materialization to prove that the snapshot and canonical identity do not change.

New focused acceptance suite: `test_camera_materialized_state.rex`.

# Camera Behaviour ooRexx v0.25

v0.25 adds an immutable, canonical **current-condition materialization snapshot** inspired by the Algorithm Relation contract in Virtual RYTA / HardWorld v0.6.

The camera remains independently versioned and does not require HardWorld. `.CameraCurrentCondition~snapshot` copies the complete current-condition scalar surface and deep-copies its metric signals into `.CameraCurrentConditionSnapshot` / `.CameraCurrentConditionSignalSnapshot` objects. Snapshot attributes are read-only.

`canonicalText` serializes every condition field that can affect a downstream deterministic read, with metric signals sorted by canonical text so directory insertion order cannot alter content identity. This is deliberately the camera-side materialized-input boundary: a downstream Algorithm Relation provider can hash this canonical content while learning/model mutation remains a separate camera operation.

The regression proves that later mutation of the live condition or its metric signal objects does not change the snapshot, and that two logically identical conditions with opposite metric insertion order canonicalize identically.

New focused acceptance suite: `test_camera_current_snapshot.rex`.

# Camera Behaviour ooRexx v0.24

This slice adds a rolling **current-condition / scene-rhythm** model above the learned motif-transition grammar. It keeps recent transition occurrences in a configurable rolling window (default five minutes), measures the empirical transition entropy, and compares current transition surprise against the time/day-conditioned historical grammar.

The new `.CameraCurrentCondition` is deliberately descriptive rather than an opaque master score. It exposes transition count, unique transitions, empirical entropy, baseline entropy, average contextual surprise, excess surprise, dominant transition/share, the baseline context actually used (`ALL` or `DAY:<class>`), and an explicit `INSUFFICIENT / EXPECTED / SHIFTED` state.

`CameraClipProcessor` now feeds each clip's learned motif-transition occurrences into the rolling condition model and attaches the resulting condition to the `.CameraClipSummary`. Current rolling state is intentionally **ephemeral**; it is not persisted as historical truth. The learned transition grammar and time/day baselines remain the persistent model. Midnight wrapping and rolling expiry are regression-tested.

This slice extends the rolling **current-condition / scene-rhythm** model from transition-only rhythm into an inspectable multivariate current-condition vector. Recent clip metric assessments (traffic, event, interaction, stop/deviation and directional rates, plus environment-conditioned photometric rate when supported) are retained ephemerally in the same rolling window as motif transitions.

The current condition now exposes how many baseline-supported metric families are present, how many are elevated, the strongest metric and z-score, and per-metric rolling signals containing average z-score, maximum absolute z-score, sample count and baseline context. A condition shifts when transition grammar is unexpectedly costly, when at least two metric families are persistently elevated, or when one metric is a strong outlier. No opaque composite suspicion score is introduced.

`CameraClipProcessor` assesses a clip against the existing historical baseline **before any learning step**, feeds that assessment into the ephemeral current-condition model, and attaches both `.currentAssessment` and `.currentCondition` to the clip summary. Historical learning remains explicit through `CameraClipComparator~learnSummary()` / `assessAndLearn()`.

New focused acceptance suite: `test_camera_current_metrics.rex`.


# Camera Behaviour Model — ooRexx v0.18

This is the eighteenth executable vertical slice of the fixed-camera behavioural scene model in ooRexx 5.3.0.

## Implemented through v0.6

- recursive `CameraBox` scene geometry
- photometric / structural / mixed change classification
- frame-level multi-object track association
- predicted-position and geometry gating
- temporary occlusion / missed-frame handling
- deterministic track expiry and midnight-safe time deltas
- route learning from completed trajectories
- route prototypes and route-tube deviations
- learned spatial zones
- first-class movement and pairwise event grammar
- overlapping circular time windows
- time-, route-, event-, and zone-conditioned behaviour distributions
- pure ooRexx information-surprise / description-length calculations
- photometric-only changes remain outside the mover/event grammar

## New in v0.7 — persistent dictionary and compact token stream

### Persistent learned camera state

`CameraModelPersistence` saves and reloads the slowly changing learned camera dictionary without serialising source video or pretending that transient track state is persistent.

The snapshot currently preserves:

- camera ID and root geometry
- route IDs, sample counts, and route prototype means
- zone IDs, sample counts, and learned centres
- behaviour-window centres and widths
- weighted route distributions
- weighted event distributions
- weighted `(zone,event)` distributions
- compact token dictionary identities

The reload path reconstructs real `CameraRoute`, `CameraZone`, `CameraBehaviourWindow`, and `CameraTokenDictionary` objects. Route and zone model counters advance past restored IDs so future learning cannot silently reuse an existing dictionary identity.

A reloaded camera is regression-tested by feeding it another matching trajectory and requiring it to reuse persistent `R1` rather than creating a new route.

### Compact token dictionary

`CameraTokenDictionary` maps repeated semantic strings to small positive integers. Empty references are token zero.

Current token namespaces include:

```text
TRACK:T1
ROUTE:R1
ZONE:Z3
```

The dictionary is persistent, so a stream written before shutdown can be decoded after the camera model is reloaded with the same token identities.

### Binary behavioural event stream

`CameraEventStream` writes a deliberately small binary stream with magic `CBT1`. Each event record currently contains:

```text
event type
timestamp (seconds-of-day)
track A token
optional track B token
optional route token
optional zone token
```

Unsigned integers use a base-128 variable-length encoding implemented in pure ooRexx by `CameraBinaryCodec`.

This first stream intentionally stores the behavioural grammar rather than imagery. Numeric residual/value quantisation can be added as a later stream version without changing the learned semantic model.

The regression scene derives 12 events and encodes them in 101 bytes:

```text
12 events
101 bytes
8.42 bytes/event
```

That figure includes the four-byte stream header and one-byte end marker. It is a real `length()`/filesystem byte count from the generated binary stream, not the earlier theoretical description-bit estimate.

### Round-trip acceptance

`test_camera_persistence.rex` verifies all of the following under the real interpreter:

- compact event stream encode/decode round trip
- event count, type, timestamp, and track identity survive decoding
- actual binary file size equals the encoder's reported byte count
- learned camera state survives a filesystem save/load cycle
- route and zone counts survive reload
- behaviour windows survive reload
- token count survives reload
- `ROUTE:R1` retains exactly the same token integer
- the reloaded token dictionary decodes the already-written binary event stream
- a post-reload trajectory reuses persistent `R1`

## Current data hierarchy

```text
source frames
    |
    v
CameraObservation
    |
    v
CameraTrack
    |
    +--> route / route-tube residual
    +--> spatial zones
    +--> event grammar
    |
    v
CameraBehaviourModel
    |
    +--> overlapping historical distributions
    |
    v
persistent camera dictionary
    +--> routes
    +--> zones
    +--> time-conditioned grammar
    +--> token identities

runtime events
    |
    v
CameraEventStream
    |
    +--> compact binary behavioural tokens
```

The design therefore keeps the slow-changing *model of the camera* separate from the high-rate *event stream produced by that model*.

## ooRexx discipline

Source and regression suites are compiled and executed under Open Object Rexx 5.3.0 r13196 extracted from the supplied package.

Retained rules include:

- non-attribute instance state uses `expose`
- tests use `call` for procedures rather than bare function-call expressions
- ordinary variables avoid interpreter-owned `RC`, `RESULT`, and `SIGL`
- no reliance on short-circuit behaviour from `&` or `|`
- no invented mutex or timestamp classes
- semantic state uses constants/objects rather than free-form status strings
- route, zone, event, temporal, token, and persistence models remain explicit and inspectable
- generated source is executed under the actual ooRexx interpreter rather than being accepted by static reasoning alone

A reserved-variable scan over executable source/tests reports no ordinary use of `RC`, `RESULT`, or `SIGL`.

## Tests

Run:

```sh
rexx test_camera_core.rex
rexx test_camera_tracking.rex
rexx test_camera_routes.rex
rexx test_camera_events.rex
rexx test_camera_behaviour.rex
rexx test_camera_spatial.rex
rexx test_camera_persistence.rex
```

All source and test programs are also passed through `rexxc`.

Expected runtime results:

```text
CAMERA CORE SMOKE: OK
CAMERA TRACKING SMOKE: OK
CAMERA ROUTE SMOKE: OK
CAMERA EVENT SMOKE: OK
CAMERA BEHAVIOUR SMOKE: OK
CAMERA SPATIAL SMOKE: OK
CAMERA PERSISTENCE SMOKE: OK
```

## Development history

The following sections record the successive executable slices from v0.8 onward.

## v0.8 clip/session summary slice

Adds a first-class `.CameraClipSummary`, external measurement import contract, and `.CameraClipProcessor`.
The import format is deliberately tiny and pixel-engine-neutral:

```
CLIP|clip-id|start-second-of-day|duration-seconds|environment-code
FRAME|second-of-day
OBS|second-of-day|x|y|width|height|luminance-delta|structure-delta
```

A clip summary retains frame/activity counts, photometric-only activity, unique tracks, route usage,
coarse direction distribution, event grammar counts, interaction/deviation/stop counts, and the actual
encoded behavioural event-stream byte count. The processor ends clip-local tracks using the existing
missed-frame lifecycle rather than inventing a second termination path.

## v0.9 time-conditioned clip comparison slice

Adds `.CameraScalarDistribution`, temporal scalar metrics on `.CameraBehaviourWindow`,
`.CameraMetricAssessment`, `.CameraClipAssessment`, and `.CameraClipComparator`.

Clip/session summaries can now be compared against the camera's overlapping historical
baseline without collapsing the result into one opaque score. The current auditable
feature families are:

- track rate per minute
- event rate per minute
- mover-observation rate per minute
- interaction rate per minute
- deviation rate per minute
- stop rate per minute
- photometric-change rate per minute
- coarse directional shares (down/up/left/right)

Each metric retains observed value, historical expectation, support, z-score, and
an explicit baseline state (`INSUFFICIENT`, `WITHIN`, or `ELEVATED`). Event and route
description-bit averages remain separate information-theoretic signals.

The comparison lifecycle is intentionally `assess -> learn`, so the current clip does
not make its scalar behaviour normal before it has been assessed. Scalar distributions
are also included in `CameraModelPersistence` as `WM` records.

The session regression demonstrates the same ten-track/downhill minute being ordinary
around 00:15 but strongly elevated against the learned 04:30 baseline. It also verifies
that the scalar baseline survives save/reload.

## v0.10 environment-conditioned observation layer

v0.10 separates behavioural time conditioning from observation-environment conditioning.
`CameraBehaviourModel` still answers what movement is expected at a time of day.  New
`CameraEnvironmentModel` / `CameraEnvironmentProfile` objects answer how much
photometric and low-level structural variation is expected under an illumination regime.

Initial environment profiles distinguish unknown, night/artificial, diffuse daylight and
direct-sun/hard-shadow conditions.  Thresholds are explicit and inspectable, and can be
raised from calibrated background observations.  This prevents a hard moving shadow or
brake-light wash from automatically becoming a mover while retaining the same 15:15
behavioural baseline across different weather/lighting conditions.

`PHOTOMETRIC_RATE` is now learned against `environmentCode`, not the time-of-day
behaviour model.  Environment background distributions and environment scalar metrics
are persisted independently with the camera dictionary.

## v0.11 automatic environment-state inference

v0.11 removes the requirement for every clip to arrive with a manually selected
illumination regime. `CameraEnvironmentSignature` carries five compact measured
scene statistics:

- global luminance
- local contrast
- shadow fraction
- bright fraction
- structural-noise level

`CameraEnvironmentModel~infer()` compares that signature against learned
camera-specific environment profiles. Before a profile has sufficient support,
small explicit prototypes provide a cold-start fallback for night/artificial,
diffuse daylight, and direct-sun/hard-shadow conditions.

Clock time is an intentionally weak prior rather than a substitute for measured
scene state. This is regression-tested with an otherwise ambiguous signature:
at 04:30 the prior resolves it toward night/artificial, while at 12:00 it resolves
toward daylight. A Rexx-specific regression caught and corrected the important
`%` versus `//` distinction while implementing this: `%` is integer division;
`//` is remainder.

`CameraEnvironmentInference` retains the inferred code, confidence, inference
method (`PROFILE` or cold-start `PROTOTYPE`), and signature distance. Unknown-
environment imported clips are inferred before any observations are classified,
so the inferred hard-shadow regime can suppress a wall illumination change before
it creates a false mover.

The external measurement format now optionally accepts:

```
ENV|globalLuma|localContrast|shadowFraction|brightFraction|structuralNoise
```

separately from the `CLIP` environment code. This preserves the distinction
between source metadata and measured environmental evidence.

Learned environment signatures are persisted as `ENVS` records and survive a
camera save/reload cycle. Explicitly labelled clips can train these signatures;
a clip whose environment was inferred does not automatically retrain the profile,
avoiding immediate self-confirmation of an uncertain classification.

Additional acceptance test:

```text
CAMERA ENVIRONMENT INFERENCE SMOKE: OK
```

## v0.12 calendar/day-class conditioned behaviour

v0.12 adds a second behavioural context dimension without fragmenting the existing
all-days baseline. `CameraCalendarBehaviourModel` maintains day-class-specific copies
of the overlapping time-window scalar distributions while `CameraBehaviourModel`
continues to retain the all-days fallback.

Initial day classes are explicit constants:

- `DAY_UNKNOWN`
- `DAY_WEEKDAY`
- `DAY_WEEKEND`

Every learned clip still contributes to the all-days time-of-day model. If its day class
is known, it also contributes to that day-class model. Comparison selects the contextual
model only after the configured minimum number of *actual clip summaries* has been seen
for that day class. This deliberately avoids treating the several overlapping windows
updated by one clip as several independent historical observations.

Each `CameraMetricAssessment` now exposes `baselineContext`, for example:

```text
DAY:122
ALL
```

so the source of an expected value remains auditable. Unknown day class and under-supported
day classes fall back to `ALL` automatically.

The external clip measurement record is backwards-compatible and may now optionally carry
one additional field:

```text
CLIP|clip-id|start-second-of-day|duration-seconds|environment-code|day-class
```

Day-context metric distributions persist as `DWM` records and real clip support counts as
`DCOUNT` records. The calendar regression trains materially different weekday and weekend
00:15 traffic rates, verifies that ten movers are ordinary for the learned weekend context
and elevated for the learned weekday context, verifies sparse-context fallback, and verifies
that the calendar model survives save/reload.

Additional acceptance test:

```text
CAMERA CALENDAR SMOKE: OK
```

## v0.13 interaction episode grammar

v0.13 adds a learned interaction-episode dictionary above the primitive event grammar.

Recurring pair sequences such as `APPROACH,CLOSE,SEPARATE` are retained as their original auditable `.CameraEvent` objects, while `.CameraEpisodeModel` can additionally represent the repeated sequence with a stable episode identity (`EP1`, `EP2`, ...). An episode is not treated as known until it has repeated support; unknown or reordered sequences remain literal.

New public model objects:

- `.CameraEpisode`
- `.CameraEpisodeEncoding`
- `.CameraEpisodeModel`

Each participating pair event is annotated with `episodeId` and `episodeDescriptionBits`. The raw event sequence remains available, so episode compression does not erase the evidence used to derive it.

The episode model is persisted using `EPISODE` records and restores stable identities and sample counts across camera-model reloads.

`test_camera_episode.rex` verifies:

- first occurrence remains literal;
- one sample is insufficient to promote an episode;
- repeated `APPROACH -> CLOSE -> SEPARATE` becomes a cheaper known episode;
- reordered events do not alias the known sequence;
- the end-to-end camera event grammar learns and reuses one episode identity;
- underlying events retain their episode annotation;
- persistence retains episode ID and support.


## v0.14 episode-aware binary stream compression

v0.14 makes learned interaction episodes real transport/storage primitives rather than only
information-theoretic annotations.

`CameraEventStream` now supports two compatible stream forms:

- `CBT1` — literal primitive-event records from v0.7 onward
- `CBT2` — literal records plus `TOKEN_EPISODE_RECORD` records

A known contiguous episode such as:

```
APPROACH -> CLOSE -> SEPARATE
```

may be emitted once as `EPISODE:EP1`.  The episode record stores the stable episode token,
the two participant track tokens, and only the per-member timestamp/route/zone residual data.
The primitive event types themselves come from the persistent episode grammar, so repeated
track identities and event-type tokens are not restated for every member.

The compression is lossless with respect to the fields represented by the pre-existing
`CBT1` stream: event type, timestamp, track A, track B, route and zone.  Decoding a `CBT2`
episode record expands it back into ordinary `CameraEventToken` objects.  The underlying
`CameraEvent` audit records are never deleted or replaced in the camera model.

Compression is deliberately conservative.  A run is substituted only when it is contiguous,
all members carry the same learned episode ID and participant pair, and the exact primitive
ordering matches the stored episode sequence.  Otherwise the encoder falls back to literal
event records.

`CameraEpisodeModel~episodeForId()` provides stable ID lookup for stream expansion.  Episode
token identities use the existing persistent token dictionary (`EPISODE:EP1`, etc.), so a
stream written before shutdown can be expanded by a reloaded camera dictionary and episode
model.

The focused regression uses an exact three-event interaction containing route/zone fields:

```
literal CBT1: 29 bytes
episode CBT2: 22 bytes
saved:         7 bytes
```

That is a real encoded byte count, including stream header and end marker.  More importantly,
the compressed stream is decoded and compared field-for-field with the original primitive
records, then persisted/reloaded and decoded again using the restored token dictionary and
episode grammar.

New acceptance suite:

```
CAMERA EPISODE STREAM SMOKE: OK
```


## v0.15 episode/time/day conditioning slice

Episode tokens now participate in the same overlapping circular time model as routes and primitive events.
`CameraBehaviourWindow` retains weighted episode frequencies, and `CameraBehaviourModel` exposes
`observeEpisode()`, `episodeProbability()`, and `episodeDescriptionBits()`.  A familiar interaction grammar can
therefore be cheap around one time neighbourhood and expensive in another without changing the episode dictionary.

`CameraCalendarBehaviourModel` adds day-class episode distributions with the same conservative support rule used
for scalar clip metrics.  Before a weekday/weekend context has enough actual clip summaries, episode cost falls
back to the all-days time model rather than trusting a sparse context.  Once supported, the day-conditioned model
can distinguish, for example, a common weekend 00:15 interaction from the same episode on a weekday.

Episode occurrences now receive ephemeral `EI...` instance identities when recognised.  These do not become
persistent dictionary identities; they exist so clip summaries can count repeated instances of the same `EP...`
grammar unambiguously while the persistent episode ID continues to name the learned sequence itself.

`CameraClipSummary` now exposes episode counts/rates and occurrence records.  `CameraClipAssessment` exposes an
`averageEpisodeDescriptionBits` value computed using the supported day context when available.  The underlying
primitive event stream remains intact for audit.

Persistence adds `WEP` records for all-days time-conditioned episode weights and `DWEP` records for day-context
episode weights.  Save/reload is regression-tested against both weekend and weekday episode costs.

The focused v0.15 regression learns `EP1 = APPROACH,CLOSE,SEPARATE` around 00:15 and a different episode around
04:30.  It verifies:

```text
EP1 00:15 bits            < EP1 04:30 bits
EP1 weekend 00:15 bits    < EP1 weekday 00:15 bits
sparse day context         == all-days fallback
restored costs             == pre-save costs
```

Run the new focused suite with:

```sh
rexx test_camera_episode_time.rex
```


## v0.16 longer behavioural motif grammar

v0.16 adds a grammar layer above pairwise episodes. `.CameraMotifModel` learns
participant-independent sequences built from already-derived semantic tokens rather
than from pixels or raw coordinates. A typical learned key can therefore look like:

```text
E:50:R:R7:Z:Z3 > E:52:R:R7:Z:Z6 > P:EP1 > E:53:R:R7:Z:Z8
```

which corresponds to an entry on a known route, a stop in a known zone, one learned
interaction episode, and an exit. Track identities are deliberately excluded from the
motif key, so the same behavioural grammar can recur with different participants.
Route, zone, event, and episode identities remain explicit.

The motif learner first orders clip events by timestamp, collapses the primitive
members of a single episode occurrence to one `P:EP...` token, and then learns either
the complete 3–6 token clip grammar or overlapping four-token motifs for longer clips.
A new motif remains literal until it has repeated support; a familiar motif receives a
stable `M...` identity and a shorter information description. Spatial changes such as
a different stop zone create a different motif rather than being silently generalised.

`.CameraClipSummary` now exposes motif counts, motif occurrences, motif rate, and
average motif description bits. `MOTIF_RATE` is also an auditable scalar clip metric.
The initial motif dictionary itself is deliberately global in this slice; time/day
conditioning of motif identities can be layered on next without changing the grammar.

Motifs persist as `MOTIF` records in `CameraModelPersistence`, retaining stable IDs,
sample counts, and exact sequence keys across shutdown/reload.

New acceptance coverage in `test_camera_motif.rex` verifies:

- first observations remain literal;
- repeated motifs become cheaper;
- changed spatial grammar creates a separate motif;
- participant identity is not part of the learned motif;
- timestamp ordering is used rather than event insertion order; and
- motif ID, support, and exact sequence survive persistence.

Expected additional runtime result:

```text
CAMERA MOTIF SMOKE: OK
```


## v0.17 time/day-conditioned motif grammar

v0.17 conditions learned `M...` motif identities on the same overlapping circular time
windows and conservative calendar/day-class model already used for routes, episodes, and
clip metrics. The motif dictionary remains global: `M1` still names one exact learned
behavioural sequence. What changes with context is the cost of observing that motif.

`CameraBehaviourWindow` now retains weighted motif frequencies independently from episode,
event, route, zone-event, and scalar metric state. `CameraBehaviourModel` exposes
`observeMotif()`, `motifProbability()`, and `motifDescriptionBits()`. A motif can therefore
be common around one time neighbourhood and expensive in another without changing its
identity or its lower-level audit trail.

`CameraCalendarBehaviourModel` adds day-conditioned motif distributions with the same
minimum real-clip support rule used elsewhere. Sparse weekday/weekend history falls back
to the all-days overlapping time model. Once supported, the day context can make the same
`M1` cheap on a weekend and expensive on a weekday.

`CameraClipComparator` now computes `averageMotifDescriptionBits` from the supported
calendar/time context rather than merely copying the motif dictionary's global encoding
cost. `CameraClipComparator~learnSummary()` observes motif occurrences only after the clip
has been assessed, preserving the rule that an observation cannot make itself normal
before it is scored.

Persistence adds:

```text
WMOT   all-days overlapping-time motif weight
DWMOT  day-context overlapping-time motif weight
```

The focused `test_camera_motif_time.rex` regression trains `M1` around 00:15 and a
different motif around 04:30, then trains different weekday/weekend contexts at the same
clock time. It verifies:

```text
M1 00:15 bits            < M1 04:30 bits
M1 weekend 00:15 bits    < M1 weekday 00:15 bits
sparse day context        == all-days fallback
clip assessment           uses contextual motif cost
restored costs            == pre-save costs
```

Run the new focused suite with:

```sh
rexx test_camera_motif_time.rex
```

Expected additional runtime result:

```text
CAMERA MOTIF TIME SMOKE: OK
```

## v0.18 motif-transition grammar

v0.18 adds a higher-order scene-rhythm layer without allowing motifs to grow without
bound. Consecutive learned motif occurrences become first-class transition objects:

```text
M1 -> M2   = X1
M2 -> M3   = X2
```

`CameraMotifTransitionModel` keeps stable transition identities and sample counts. The
source and target motif IDs remain explicit, so transition grammar stays inspectable and
does not erase the lower-level motif/event audit trail.

Transition occurrences are attached to `CameraClipSummary`, which now exposes transition
counts, rate-per-minute, and average transition description bits. `TRANSITION_RATE` is a
separate clip metric rather than being folded into motif rate.

The transition distribution is conditioned by the existing overlapping circular time
windows and conservative weekday/weekend context. Sparse day-specific history falls back
to the all-days model. This permits the same scene transition to be cheap around a learned
00:15 weekend regime and expensive around 04:30 or a weekday regime.

Persistence adds:

```text
TRANSITION   stable X... definition and support
WTR          all-days overlapping-time transition weight
DWTR         day-context overlapping-time transition weight
```

`test_camera_transition.rex` verifies stable transition identity, adjacency semantics,
time/day-conditioned information cost, sparse-context fallback, clip assessment, and
save/reload preservation.

Expected additional runtime result:

```text
CAMERA TRANSITION SMOKE: OK
```

## v0.19 rolling current-condition / scene-rhythm slice

v0.19 adds an ephemeral `.CameraCurrentConditionModel` above the persisted motif-transition
grammar. It retains only recent transition occurrences inside a circular rolling window and
compares that recent rhythm with the already learned time/day-conditioned transition model.
The resulting `.CameraCurrentCondition` exposes transition count, empirical entropy,
baseline entropy, contextual surprise, excess surprise, dominant transition and an explicit
`INSUFFICIENT / EXPECTED / SHIFTED` state. The rolling state is deliberately not persisted;
the learned historical grammar remains the persistent source of truth.

## v0.20 multivariate current-condition slice

v0.20 extends current conditions with baseline-supported scalar clip metrics. Recent
`.CameraClipAssessment` metrics are retained independently from transitions and aggregated
into inspectable `.CameraConditionMetricSignal` objects. Each signal exposes sample count,
average z-score, maximum absolute z-score and baseline context. Current condition therefore
can report that traffic, interactions or direction share have shifted even when motif
transition rhythm remains normal. A shift can be caused by multiple elevated dimensions or
one very strong dimension; there is still no opaque combined suspicion score.

## v0.21 rolling trend slice

v0.21 adds direction-of-change to the multivariate current-condition layer. For every usable
metric inside the rolling window, `.CameraConditionMetricSignal` now retains `firstZ`,
`lastZ`, signed `trendDelta`, and a `TREND_STABLE / TREND_RISING / TREND_FALLING` state.
Trend classification requires a configurable minimum number of observations and a minimum
signed z-score displacement, so two isolated samples cannot manufacture a trend.

`.CameraCurrentCondition` exposes the number of trending metric families plus the strongest
trend metric and its signed delta. A sufficiently sustained rising or falling metric can mark
the current scene `SHIFTED` before its rolling average has crossed the ordinary level
threshold. This is intentionally separate from level anomaly: operators can distinguish
"traffic is high" from "traffic is rising quickly toward an unusual regime".

The focused `test_camera_current_trend.rex` regression verifies a rising track-rate trend, a
falling interaction-rate trend, normal jitter, and minimum-sample protection. The rising
case remains below the existing level threshold, demonstrating that the shift is caused by
trend rather than by the v0.20 elevated-level rule.

Expected additional runtime result:

```text
CAMERA CURRENT TREND SMOKE: OK
```


## v0.22 current-condition persistence / recovery slice

v0.22 separates a momentary `SHIFTED` assessment from a sustained scene regime. The
ephemeral `.CameraCurrentConditionModel` now keeps explicit consecutive shifted/expected
streaks and exposes a separate persistence phase on every `.CameraCurrentCondition`:

```text
CONDITION_PHASE_INSUFFICIENT
CONDITION_PHASE_STABLE
CONDITION_PHASE_EMERGING
CONDITION_PHASE_PERSISTENT
CONDITION_PHASE_RECOVERING
```

The existing `INSUFFICIENT / EXPECTED / SHIFTED` state remains the instantaneous assessment;
the new phase answers a different question: whether that assessment has persisted long enough
to describe a changed regime. By default three consecutive shifted observations promote an
`EMERGING` change to `PERSISTENT`. Once persistent, two consecutive expected observations are
required to reach `STABLE`, with `RECOVERING` exposed in between. These thresholds are
configurable as `persistenceMinimum` and `recoveryMinimum`.

Insufficient evidence never counts as recovery, and repeated reads of the same scene timestamp
do not extend either streak. The state remains deliberately ephemeral and is reset by
`.CameraCurrentConditionModel~clear`; it is not written into the historical camera model.

The focused `test_camera_current_persistence.rex` regression verifies single-spike protection,
three-observation promotion, two-observation recovery, same-timestamp idempotence, and
insufficient-data behaviour.

Expected additional runtime result:

```text
CAMERA CURRENT PERSISTENCE SMOKE: OK
```

## v0.23 persistent condition-regime event slice

v0.23 promotes a sustained current-condition shift into a first-class compact
`.CameraConditionRegime` object. A brief `EMERGING` spike is deliberately not
persisted. When the configured shifted streak reaches `PERSISTENT`, the model
opens one regime whose `startSecond` is the first emerging instant, not merely
the confirmation instant. The same regime remains open while the scene is
persistent and while it passes through `RECOVERING`, then closes only after the
configured recovery streak returns the current condition to `STABLE`.

A regime records its start/end/duration, sample count, strongest observed metric
and z-score, peak transition-surprise excess, and an inspectable cause family
(`METRIC`, `TREND`, or `TRANSITION`). `.CameraCurrentCondition` exposes the
active regime id, while `.CameraCurrentConditionModel` exposes the current
regime and completed regime history. Repeated assessment of the same timestamp
continues to be idempotent, and one-off spikes create no durable regime record.

This is the first compact history layer for the "wrong atmosphere" model: the
runtime can retain a small stream describing *when a materially different scene
regime began, how long it lasted, and what measurable dimension dominated it*
without retaining every intermediate current-condition assessment.


## v0.24 recurring condition-regime class slice

v0.24 turns completed persistent-condition regimes into a tiny recurring dictionary rather
than treating every regime as unrelated history. `.CameraConditionRegime~buildSignatureKey`
creates an inspectable structural signature from the regime cause, dominant metric, signed
direction, and whether transition surprise materially contributed. The signature is deliberately
coarse: it captures the *kind* of changed atmosphere without overfitting incidental magnitude.

`.CameraCurrentConditionModel` now owns a small `regimeClasses` dictionary. When a regime
closes it is classified into a `.CameraConditionRegimeClass` (`CRC1`, `CRC2`, ...). Repeated
regimes with the same structural signature reuse the same class and accumulate occurrence count,
mean duration, maximum absolute peak z-score, and first/last observed start time. A class is
`CONDITION_REGIME_CLASS_NEW` after its first example and becomes
`CONDITION_REGIME_CLASS_KNOWN` after recurrence. Each archived regime retains both its
`signatureKey` and `classId`.

The focused `test_camera_current_regime_class.rex` regression proves that two positive
`TRACK_RATE` regimes reuse one class, a negative `TRACK_RATE` regime is distinct, and a regime
dominated by `INTERACTION_RATE` is distinct again. One-off `EMERGING` spikes still create no
regime and therefore cannot pollute the recurrence dictionary.

Expected additional runtime result:

```text
CAMERA CURRENT REGIME CLASS SMOKE: OK
```
