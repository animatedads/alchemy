# v0.12-dev12 qualification record

## Quality-corpus V2 + dev11 controller admission

v0.12-dev12 preserves the dev11 fail-closed prepared-fixture boundary and changes only the quality-reference/profile boundary. `reference/QUALITY_CORPUS.tsv` is now executable authority for the native scorer through `as_context_new_corpus`; 2..32 distinct PCM16/16 kHz/mono references are supported without changing the Rexx entry-point ABI again.

The active `AUDIO-QUALITY-TARGETS-V2` corpus contains four distinct prepared references. Two are the previous contrast references; two are sample-exact 48-second windows from the user-supplied `WhatsApp Audio 2026-09-08 at 17.15.39.mp4` (source SHA-256 `a3cb001a35a1567cdfc91d076a8c3ce7f062c189c31021f2b205c5add583c2bb`): 489..537 s for the quiet regime and 765..813 s for the brighter/high-register regime. They are decode/downmix/resample-only derivatives, so source-level differences remain evidence.

The separately uploaded `24 August Threats ... 1(2).mp3` has SHA-256 `f59b6f88ac7693655d0a1610e8380442853afcb6a94534d2d28b48a45c17c867`, exactly matching the already represented target 01 source. It is retained as duplicate provenance only and is not inserted a second time. The prepared-fixture verifier independently rejects duplicate prepared-reference hashes.

Because the profile changes, reference-distance and scalar scores from V2 are deliberately **not numerically comparable** with pre-V2 runs. A/B/C/D/E/I/H search-space mechanics, Pareto objective identities, CCTV exclusion semantics, checkpoint discipline and H additive voice-mix mechanics remain otherwise unchanged.

Qualification on 2026-09-08 used the supplied exact ooRexx **5.3.0 r13196** Debian build, SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`. Supplied dependency evidence: API roll-up SHA-256 `aa1709f24b4a8473fcfb99f36c11c4bb718b9ce0e30d7a4f439d5df8cbdfeafb`; sphere roll-up SHA-256 `293cd2a62e04965e7c87134902d0509bb453cbe36618f895444a0af7465fc177`.

Qualification results:

- native C warning-as-error build + Foreign Runtime binding: **PASS**; dev12 native fingerprint `c97554288df6f0d501dca33ba7148d29ba716a10fcfaf74005cfcb3edc7d4c69`; the same fingerprint was reproduced from an alternate installation root, proving path-independent content identity;
- complete Rexx-native local suite: **PASS**, ending `PASS ALL REXX-NATIVE AUDIO SEARCH v0.12-dev12 LOCAL TESTS`; A/B/C/D/E/I, deterministic C replay/final generation, E checkpoint/resume/key binding, Pareto V2, objective calibration, multi-band rejection and H additive voice mix all execute against the four-reference manifest profile;
- `tests/test_prepared_verifier.sh`: **PASS** for valid V2 corpus; byte-identical prepared-reference duplication rejected; zero-alarm fixture rejected; post-seal tamper rejected;
- `tests/test_0945_campaign.sh`: **PASS** for 09:45 arithmetic/camera/quality-target/H-window, H empty-TSV and 17-column guards, CCTV detector/mask/timeline and prepared-fixture admission;
- real local H API/TLS/spool/Observation integration: **PASS**, ending `PASS H API TLS/SPOOL/OBSERVATION/ROLLING/VOICE-MIX node=ed209h windows=3`.

No production Ogg masters or ED209 SSH credentials were present in the chat sandbox, so no remote campaign execution is claimed. The next real boundary remains `prepare_samples.sh` -> inspect exclusion TSVs -> `deploy_all.sh --full --no-prepare --reset-state`.

---

# v0.12-dev10 qualification record

## 09:45 controller hotfix H1 qualification

The post-full-run H submission path exposed two controller-only defects after campaign masters had already been staged successfully: the original H staging helper did not inherit the controller's managed SSH config, and Bash tab-IFS parsing collapsed an empty `reject_bands` TSV column so the processing-chain text shifted into that field. The H API correctly rejected that malformed envelope with `INVALID_REJECT_BANDS`; no H DSP job was started by the rejected request. The earlier real-media preparation attempt also demonstrated the Ogg packet-boundary shortfall (`569.189125` s vs required `570.000000` s) and was blocked before worker launch.

H1 qualification performed here:

- `prepare_samples.sh` now decodes the tp00023/tp00024 pieces before concat and enforces exactly **9,120,000 samples** for the 570 s companion master with `apad,atrim=end_sample=9120000`;
- `stage_h_campaign_audio.sh` inherits a managed SSH config via `ED209H_SSH_CONFIG`, `SSH_CONFIG`, or `$HOME/.ssh/config`, and supports `ED209H_KEY` while retaining `VULTR_KEY` fallback;
- `prepare_h_api_job.sh` converts tabs to a non-whitespace delimiter before Bash `read`, preserving empty TSV fields;
- a deterministic regression constructs a rank-01 candidate whose `reject_bands` field is empty and proves the generated H envelope retains `parent.1.reject_bands=` while the complete processing chain remains in `parent.1.chain`;
- all shell entrypoints pass `bash -n`;
- `tests/test_0945_campaign.sh` passes the arithmetic/camera-role/quality-target/H-window contract plus the new H1 regression;
- the complete Rexx-native local suite was rerun with the supplied exact **ooRexx 5.3.0 r13196** runtime extracted locally and passed through Strategy A/B/C/D/E/I, C replay/final-generation semantics, E checkpoint/restart, Pareto/calibration, multi-band rejection and H additive voice-mix, ending with `PASS ALL REXX-NATIVE AUDIO SEARCH v0.12-dev9 LOCAL TESTS`.

H1 changes controller/campaign plumbing only; worker search/DSP semantics and the resident H API schema remain unchanged.

## Quality-target and 09:45 campaign qualification

Qualification for dev8 must prove exact target hashes, canonical 16 kHz mono PCM16 reference format, no active evt_000071/evt_000597 references, 09:45 primary arithmetic, tp00023->tp00024 companion seam, 540/570-second H masters, 180/210-second A-E parent fixtures, and H starts `0,90,180,270,360`.

Changing the dev8 target set was a calibration break, not an implementation-regression excuse: A-E/H mechanics remained compatible, but dev8 score identity was explicitly bound to `AUDIO-QUALITY-TARGETS-V1` and Pareto set `RECOVERED-AUDIO-PARETO-V2`.


## dev7 H additive voice-mix qualification

Qualified with exact ooRexx 5.3.0 r13196 extracted from the supplied build and the package-owned native source. The complete local Rexx-native suite passed after the change, including A/B/C/D/E deterministic search, ML dev5 GA lifecycle, Pareto export, review/calibration, E checkpoint/replay and multi-band rejection. The new H regression ran the real `AudioTemporalBandRefinement.rex` path and proved:

- top-24 distinct selection pool independent of the ordinary H materialized shortlist;
- primary rank is exactly H rank 1;
- residual rank is selected by measured rendered RMS and is not hard-coded (the synthetic worker fixture selected rank 15);
- `h_voice_mix.wav` and `h_voice_residual.wav` are PCM16 / 16 kHz / mono derived materials;
- additive mix output is byte-distinct from both primary and residual;
- mix metadata is valid JSON under `audio.h.additive.voice-mix/1`;
- parent cancellation strength, RMS, attenuation, selected reject plan, score and PCM hash are retained as evidence;
- final mix uses the standard sample-local `.88/.98` limiter with no whole-wave normalization.

The real H API/TLS/spool integration suite also passed after the change: `PASS H API TLS/SPOOL/OBSERVATION/ROLLING/VOICE-MIX node=ed209h windows=3`. It produced exactly one aggregate H voice-mix record per synthetic parent/window pair while preserving durable job idempotency/conflict behavior and Observation replay.


## Dependency qualification

`oorexx_ml_v0.1-dev5(1).zip` verifies against its supplied manifest. Its full **23-file executable suite was rerun during dev6 sealing under exact ooRexx 5.3.0 r13196 and passed 23/23**. The dev6 vendored ML source is byte-identical to the supplied dev5 source for all ML classes consumed here, including `MLMultiObjective.cls` and `AudioParetoObjectives.cls`.

The latest supplied API roll-up is `oorexxapis(20260906-192211).zip` SHA-256 `aa1709f24b4a8473fcfb99f36c11c4bb718b9ce0e30d7a4f439d5df8cbdfeafb`; the vendored API Client v0.3 and HTTPS Server v0.4.4 were checked against their authoritative nested archives before H integration qualification.

## A-E / native audio qualification

The bounded local regression covers:

- warning-as-error native Foreign Runtime, DSP and fsync-helper build, with the Azure portability exception `-Wno-error=maybe-uninitialized` scoped only to the DSP compile while all other warnings remain fatal;
- `rexxc` compilation of audio search/refinement/control entrypoints under r13196;
- Strategy A native end-to-end execution;
- Strategy B cancellation plus 7 GiB workspace/retention evidence;
- Strategy C `MLGeneticAlgorithm~run()` complete-run semantics and deterministic replay;
- low-budget C planning without unevaluated terminal offspring;
- C production-shape planning at 180 slots: population 30, five breeding steps, six evaluated populations, 180 evaluation slots, final generation evaluated;
- A/B/D -> C shared-domain comparison evidence;
- Strategy D focused cancellation;
- Strategy E deterministic checkpoint/resume, including interrupted-prefix -> resumed replay equivalence and fail-closed identity mismatch;
- native multi-band rejection, including single- and multiple-band suppression and >6-band fail-closed validation;
- no Python candidate execution path.

Every A-E shortlist now emits `pareto_candidates.tsv` using recovered-audio dev5 objectives (`reference_distance`, `pre_limiter_over_fraction`, `post_limiter_clip_fraction`) plus non-dominated rank/crowding evidence. The historical scalar score remains marked experimental pending perceptual calibration.

## H HTTPS / rolling / Observation qualification

The H integration regression uses the **real native API Client v0.3 and HTTPS Server v0.4.4 over TLS**, not curl/Python substitutes. It verifies:

- health endpoint success;
- interceptor rejection of invalid bearer admission with 401;
- durable `POST /v1/jobs` acceptance with 202;
- idempotent replay of identical job content;
- 409 rejection when an existing job id is reused with changed content, without replacing the original durable job;
- PENDING -> COMPLETE status progression through the separate serial spool worker;
- accepted per-job envelope authority bounded by H's node-local hard capability ceilings;
- rolling parent-chain replay and band refinement over synthetic neighbouring windows;
- Observation publish, idempotent replay, conflict rejection, stream replay and restart persistence;
- collected A-E scalar result + Pareto frontier publication as conversation evidence;
- conversation does not itself execute work.

The production H temporal contract remains a 180-second parent window, ±180-second radius and 90-second step, producing starts at `-180,-90,0,+90,+180` relative to the parent.

## Runtime topology

Persistent CPU workers:

- ed209a Oracle / Strategy A
- ed209b Oracle / Strategy B
- ed209c Azure / Strategy C and initial heavier coordinator role
- ed209d AWS / Strategy D
- ed209e GCP standard VM / Strategy E
- ed209h Vultr / stable HTTPS + Observation hub + Strategy H serial rolling refinement

Burst accelerators remain external capability seams:

- ed209f Hugging Face Space / ZeroGPU short calls
- ed209g Colab opportunistic GPU sessions

## Real-data acceptance command

```bash
TP00006_SOURCE=/path/20231010_093912_tp00006_original.ogg \
TP00026_SOURCE=/path/20231010_104209_tp00026_original.ogg \
./deploy_all.sh --qualification
```

A-E qualify over tp00006 4758..4938 with tp00026 alignment material 966..1176 (the exact centred 3-minute companion view is 981..1161). H then pursues promoted voice-positive parents sideways in time rather than restarting broad discovery.

Perceptual acceptance remains intentionally human-grounded: recognizable voice is already reaching the promoted frontier, but clarity/intelligibility and the historical scalar artefact weights remain subject to listening review/calibration.

## 11:00 campaign retarget qualification

The 11:00 campaign changes no search/DSP/ML implementation. Static comparison against the corrected block45 baseline is expected to differ only in campaign docs, A-E job timing, sample preparation/path wiring, and H campaign/thread identifiers. `prepare_samples.sh` and `prepare_h_roll_windows.sh` are exercised on synthetic source material to prove the exact `4758..4938` primary interval, the `966..1176` companion alignment interval, and the five H rolling offsets `-180,-90,0,+90,+180`.


## 11:15 campaign retarget qualification

The 11:15 retarget adds no DSP/ML search semantics. Qualification must
prove: primary source master duration 540 s; companion master duration
570 s; parent source duration 180 s; parent companion duration 210 s;
source and companion H starts `0,90,180,270,360`; exact relative
offsets `-180,-90,0,+90,+180`; and no duplicate one-second primary
overlap at the tp00006/tp00007 handoff. The resident H API schema
remains `audio.h.refinement.control/2`; campaign masters are staged
into its existing audio root before job submission.

### Sealing evidence for this package

A synthetic four-recording Ogg fixture was generated with ffmpeg and run through the real `prepare_samples.sh` and `prepare_h_roll_windows.sh` paths. Results:

- `campaign1115_source_111030_111930.wav`: exactly 540.000 s, PCM16, 16 kHz mono;
- `campaign1115_companion_111015_111945.wav`: exactly 570.000 s, PCM16, 16 kHz mono;
- parent source: exactly 180.000 s;
- parent companion: exactly 210.000 s;
- H rows: `m180=-180:0:0`, `m90=-90:90:90`, `p0=0:180:180`, `p90=90:270:270`, `p180=180:360:360` (relative:source-start:companion-start);
- `prepare_h_api_job.sh` emitted the two synthetic master basenames with base offsets 180 and the unchanged `audio.h.refinement.control/2` schema;
- all shell files passed `bash -n`;
- the search/temporal-refinement/native/ML/H server-worker implementation set is byte-identical to the sealed 11:00 package; only campaign fixture/provenance/wiring changed.

## 11:30 campaign retarget qualification

The 11:30 retarget adds no search or enhancement semantics. Qualification proves the corrected camera authority (`tp00007` primary, `tp00027` companion), source master duration 540 s, companion master duration 570 s, parent source duration 180 s, parent companion duration 210 s, and H starts `0,90,180,270,360` for relative offsets `-180,-90,0,+90,+180`.

The supplied media mapping is fixed as: tp00007 centre `909`, parent `819..999`, H master start `639`; tp00027 centre `1163`, exact centred view `1073..1253`, prepared alignment view `1058..1268`. The tp00007 supplied offset is authoritative even though naive filename-clock subtraction differs by 2 seconds.

### Sealing evidence for this package

A synthetic two-recording Ogg fixture was run through the real `prepare_samples.sh` and `prepare_h_roll_windows.sh` paths using the supplied media-offset contract. Results:

- `campaign1130_source_112530_113430.wav`: exactly 540.000 s, PCM16, 16 kHz mono, sourced from tp00007 media offset 639;
- `campaign1130_companion_112515_113445.wav`: exactly 570.000 s, PCM16, 16 kHz mono, sourced from tp00027 offset 878;
- parent source: exactly 180.000 s at master offset 180, corresponding to supplied tp00007 `819..999`;
- parent companion: exactly 210.000 s at master offset 180, corresponding to tp00027 `1058..1268`;
- H rows: `m180=-180:0:0`, `m90=-90:90:90`, `p0=0:180:180`, `p90=90:270:270`, `p180=180:360:360` (relative:source-start:companion-start);
- `prepare_h_api_job.sh` emitted the unchanged `audio.h.refinement.control/2` schema with source/companion master basenames and base offsets 180;
- all shell files passed `bash -n` and the campaign arithmetic/camera-role test passed;
- the search, DSP, native kernel, ML, H API server/worker and temporal-refinement implementation files are byte-identical to the sealed 11:15 package; only campaign fixture/provenance/wiring files changed.


## 11:22:30 gap-fill qualification

Requires 540 s source master, 570 s companion master, 180 s source parent, 210 s companion parent, H starts 0/90/180/270/360, and exact 09:45 primary/companion mapping in `tests/test_0945_campaign.sh`. Runtime fixture results are recorded during sealing.

### Sealing evidence

Synthetic Ogg fixtures were passed through the real `prepare_samples.sh` and `prepare_h_roll_windows.sh` paths before packaging:

- source master: 540.000 s, PCM16, 16 kHz mono;
- companion master: 569.982 s in the synthetic Vorbis seek fixture (within the package's 30 ms source-excerpt tolerance; requested duration 570 s);
- parent source: 180.000 s;
- parent companion: 210.000 s;
- all five H source windows: 180.000 s;
- H companion windows: four at 210.000 s and the terminal p180 fixture at 209.982 s for the same Vorbis granule tolerance;
- H starts: 0, 90, 180, 270, 360;
- `PASS 11:22:30 gap-fill arithmetic/camera-role/H-window contract`;
- all non-campaign DSP/native/ML/Pareto/H/HTTPS/Observation implementation files are byte-identical to the sealed 11:30 baseline.

## dev8 sealing evidence — 2026-09-08

- Exact ooRexx runtime: 5.3.0 r13196, extracted from the supplied build for qualification.
- `rexxc` compiled all six audio entrypoints after the target/campaign changes.
- Complete Rexx-native local suite: `PASS ALL REXX-NATIVE AUDIO SEARCH v0.12-dev9 LOCAL TESTS`.
- The suite reran A/B/C/D/E search, C deterministic GA replay, E checkpoint/resume/fail-closed identity, MLReview objective calibration, Pareto V2 export, multi-band rejection, and H additive voice-mix derivation against the new quality targets.
- Synthetic Ogg campaign preparation produced source master 540 s, companion master 570 s, source parent 180 s, companion parent 210 s, and H starts `0,90,180,270,360`.
- Production-shaped Strategy A smoke over the prepared 09:45 fixture emitted schema `audio.search.result/rexx-native-0.12-dev9`, source wall clock `09:43:30..09:46:30`, target-set ID `AUDIO-QUALITY-TARGETS-V2`, and Pareto set `RECOVERED-AUDIO-PARETO-V2`.
- H API/TLS/spool semantics were not changed in dev8; the previously qualified dev7 HTTPS/Observation admission path is inherited. H's actual temporal refinement/voice-mix Rexx path was rerun locally against the new target set.

Quality target hashes:

- target 1 prepared: `60cd59d1256db067de6042b6c3fdb4e69525fd2c95c0412697e35bf37aa00e0f`
- target 2 prepared: `2b4d5583ce8e1179e69451ae3321e65e42933dab6c68504f6b98fa06d0c1f3ce`
- separate provenance bundle `audio_quality_targets_v1.zip`: `52e098d2b55750782d60f33fb7ac495eda55b2b15c9bd6840b10c8925ec73045`


## dev9 ED209i qualification delta

Static/package qualification in this build verifies Strategy-I routing/domain, six-node controller wiring, H parent admission, Observation node admission, and RAM/swap/disk preflight contracts. The model build environment does not contain ooRexx, so the new Strategy-I runtime test is intentionally **pending execution on ed209i**; no remote execution is claimed here. Existing dev8 runtime qualification remains the baseline for unchanged A-E/H code.

### Executed local qualification (2026-09-08)

After installing the exact supplied ooRexx 5.3.0 r13196 Debian package into the qualification container, all six Rexx entrypoints compiled with `rexxc` and the complete local Rexx-native suite passed. Strategy I executed 24 synthetic candidates successfully; every retained Strategy-I result used cancellation strength >=0.60. Existing A/B/C/D/E, C deterministic replay/final-generation evaluation, E checkpoint/resume/fail-closed key binding, Pareto V2, objective calibration, multi-band rejection and H additive voice-mix tests also passed. Final suite marker: `PASS ALL REXX-NATIVE AUDIO SEARCH v0.12-dev9 LOCAL TESTS`.

## v0.12-dev10 CCTV alarm exclusion delta

Controller-side qualification added for `CCTV-ALARM-EXCLUSION-V1` and the upstream H TSV parser hardening. All shell entrypoints pass `bash -n`. `tests/test_0945_campaign.sh` passes the 09:45 camera/arithmetic contract, empty-TSV preservation, exact 17-column fail-closed guard, and a synthetic alarm detector/mask/timeline regression.

A production-shaped synthetic Ogg fixture was also prepared through the real `prepare_samples.sh` path. It produced exact sample counts: primary master 8,640,000 (540 s), companion master 9,120,000 (570 s), parent primary 2,880,000 (180 s), parent companion 3,360,000 (210 s). A synthetic near-full-scale alarm in the primary was detected, projected into the parent manifest, and zeroed at the same wall-clock interval in primary and companion without changing duration.

The actual 09:45 source recordings are not bundled in the source archive; the real campaign rerun must therefore occur on the controller with `/srv/space/fcpaphos/...` inputs.
