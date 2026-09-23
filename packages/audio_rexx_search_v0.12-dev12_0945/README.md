# Campaign override: 09:45 + quality target set v2

v0.12-dev12 preserves the dev11 controller admission invariants and extends the quality-reference side from a fixed two-reference pair to manifest-backed `AUDIO-QUALITY-TARGETS-V2`. The native scorer now consumes `reference/QUALITY_CORPUS.tsv` (2..32 references) and the active corpus adds quiet/high-register voice coverage from the user-supplied 2026-09-08 WhatsApp recording without duplicate-weighting the separately uploaded byte-identical 2022 threat file.

```bash
TP00006_SOURCE=/srv/space/fcpaphos/20231010_093912_tp00006_original.ogg \
TP00023_SOURCE=/srv/space/fcpaphos/20231010_090927_tp00023_original.ogg \
TP00024_SOURCE=/srv/space/fcpaphos/20231010_094521_tp00024_original.ogg \
./run_campaign.sh --qualification
```

Then `./run_campaign.sh --full` and promote parents with `./submit_h_campaign.sh collected_results rank_01.wav`.

Scores from dev12 are not numerically comparable with pre-V2 runs because the active quality-reference profile changed from a fixed pair to the manifest-backed V2 corpus.

# Rexx-native recovered-audio search v0.12-dev12

v0.12-dev12 is the current ED209 recovered-audio search/refinement generation. ooRexx remains the search and evidence authority; native C/C++ executes the sample-heavy path through Foreign Runtime. There is no Python execution path in the package.

The package is built for exact **ooRexx 5.3.0 r13196** and is rebased onto **ooRexx ML v0.1-dev5**. dev5 preserves the existing deterministic GA/review contracts and adds explicit multi-objective/Pareto evidence for recovered audio.

## Pool topology

Persistent CPU/search/refinement nodes:

- `ed209a` — Oracle Linux, Strategy A dense control search.
- `ed209b` — Oracle Linux, Strategy B broad cross-camera cancellation laboratory, 7 GiB workspace.
- `ed209c` — Azure, Strategy C heavier deterministic ooRexx-ML GA; first natural coordinator / “bigger monkey”.
- `ed209d` — AWS, Strategy D focused cancellation lane. AWS SSH key default remains `~/.ssh/AMAZON.pem`.
- `ed209e` — GCP standard VM, Strategy E deterministic checkpointed exploration.
- `ed209i` — Azure 1 GiB-class VM, Strategy I high-cancellation voice-residual specialist; 5 GiB workspace, >=850 MiB RAM and >=1.5 GiB swap preflight.
- `ed209h` — Vultr Atlanta, Ubuntu 26.04.1, 1 vCPU / 4 GB class: stable public HTTPS ingress, durable Observation hub and serial Strategy H rolling voice-frontier refinement.

Burst accelerators are deliberately not treated as ordinary SSH workers:

- `ed209f` — Hugging Face Space / ZeroGPU: short learned enhancement, separation, embedding, ASR or intelligibility calls.
- `ed209g` — Colab: opportunistic GPU sessions for bounded larger experiments.

## Current audio interval

09:45 campaign: primary tp00006 source master `09:40:30..09:49:30`, parent `09:43:30..09:46:30`; companion tp00023->tp00024 stitched master `09:40:15..09:49:45`, parent alignment view `09:43:15..09:46:45`. H starts remain `0,90,180,270,360` within those masters. See `CAMPAIGN.md`.

Active quality targets are `AUDIO-QUALITY-TARGETS-V2`: four canonical 16 kHz mono PCM16 references listed by `reference/QUALITY_CORPUS.tsv`, including quiet/high-register voice coverage. The manifest-backed profile can grow to 32 distinct references without changing the Rexx/Foreign Runtime ABI.


## CCTV alarm exclusion

The 09:45 rerun uses `CCTV-ALARM-EXCLUSION-V1`. `prepare_samples.sh` first creates exact-sample unamplified masters, detects repeated near-full-scale alarm clusters on the primary original, preserves the absolute timeline, and zeroes those intervals in both primary and wall-clock-equivalent companion material before any A/B/C/D/E/I/H processing. See `EXCLUSION_POLICY.md`.

This is intentionally about ignoring what is visually obvious on the waveform so the search budget remains focused on the quiet material that is not.

## A-E + I broad/specialist search

A-E continue the qualified broad search unchanged. Strategy I is additive: it deliberately searches the strong-cancellation residual domain for quiet voice-bearing material that complements H's rank-1-plus-residual mix. v0.12-dev12 does **not** change the A-E search-space mechanics or inject arbitrary rejected-band genes into every first-stage candidate.

Qualification/full candidate budgets remain:

| node | strategy | qualification | full |
|---|---:|---:|---:|
| ed209a | A | 90 | 1800 |
| ed209b | B | 90 | 1800 |
| ed209c | C | 180 | 3600 |
| ed209d | D | 60 | 900 |
| ed209e | E | 60 | 900 |
| ed209i | I | 60 | 900 |

The controller stages/launches nodes independently so a slow or unavailable node cannot serialize the rest of the pool.

Prepare and qualify:

```bash
TP00006_SOURCE=/path/20231010_093912_tp00006_original.ogg \
TP00023_SOURCE=/path/20231010_090927_tp00023_original.ogg \
TP00024_SOURCE=/path/20231010_094521_tp00024_original.ogg \
./deploy_all.sh --qualification
```

A full continuation can reuse a prepared fixture, but dev12 retains the dev11 verification of `SAMPLES.sha256`, exact sample counts, the alarm-mask schema/geometry, and both parent-local exclusion projections before deployment:

```bash
./verify_prepared_samples.sh
./deploy_all.sh --full --no-prepare
```

For the clean 09:45 production rerun boundary, prepare once, inspect the generated exclusion TSVs, then launch a fresh full search without regenerating the reviewed fixture:

```bash
./prepare_samples.sh
./verify_prepared_samples.sh
# inspect exclusions/campaign0945_cctv_alarm_source_master.tsv and parent projections
./deploy_all.sh --full --no-prepare --reset-state
```

The campaign is fail-closed if the known CCTV alarm detector returns zero intervals. `CCTV_ALARM_REQUIRE_MATCH=0` exists only as an explicit diagnostic override; it is not the production 09:45 policy.

## Strategy C and ooRexx ML dev5

Strategy C uses the ML library directly:

- `MLObjective` / `MLObjectiveFitnessAdapter` own objective direction and fitness adaptation;
- `MLGABudgetPlan` plans evaluated populations;
- named `MLGeneticPolicy` carries mutation/crossover/elitism policy;
- `MLGeneticAlgorithm~run()` guarantees the final bred population is evaluated;
- deterministic RNG/checkpoint/generation evidence remains replayable.

C's shared gain/filter/denoise domain is an explicit superset of the shared A/B/D boundaries. Search-space relations are emitted in `results.json` rather than being implicit.

## Pareto evidence: do not hide trade-offs

Every A-E/I shortlist now exports `pareto_candidates.tsv` using `RECOVERED-AUDIO-PARETO-V2`. The independent MINIMIZE objectives are:

1. `reference_distance` — `0.35*global + 0.40*window_median + 0.10*window_p25 + 0.15*temporal`;
2. `pre_limiter_over_fraction`;
3. `post_limiter_clip_fraction`.

The historical scalar score is retained for continuity, but `results.json` explicitly labels it:

```text
EXPERIMENTAL_UNTIL_PERCEPTUAL_CALIBRATION
```

The Pareto frontier and crowding evidence are therefore available to the coordinator/human reviewer without inventing another hidden weighted scalar. Human listening remains the deciding evidence among non-dominated trade-offs when needed.

Each shortlist also exports:

- `review_candidates.tsv` for blind pairwise listening;
- `candidate_configs.tsv` for exact machine-readable replay of the winning chain;
- ranked WAV material and detailed result evidence.

## Native multi-band rejection

The native DSP path accepts up to six rejected frequency intervals per processing chain, for example:

```text
reject_bands=0-80;950-1250;5200-7900
```

Interior bands use cascaded band-stop sections; intervals touching an edge become the appropriate high/low-pass edge rejection. More than six bands fail closed.

The first-stage A-E search remains unchanged when `reject_bands` is empty. Band removal is principally a **second-stage refinement operation** on voice-positive material.

`AudioBandRefinement.rex` can refine an already-rendered candidate. `AudioTemporalBandRefinement.rex` is used by H to replay the original parent chain on neighbouring raw source/companion material before testing additional rejected bands.

## Strategy H: rolling voice pursuit

H is deliberately not another blind million-candidate lane. For each promoted strong A-E parent, H replays the exact parent processing configuration across the raw audio surrounding the parent interval.

Production defaults are a 3-minute parent window, ±3-minute temporal radius and 50% overlap:

```text
relative -180: T-180 .. T
relative  -90: T-90  .. T+90
relative    0: T      .. T+180
relative  +90: T+90  .. T+270
relative +180: T+180 .. T+360
```

The companion recording is materialized at the corresponding relative offset. Alignment/cancellation is then recomputed for each window. H crosses promoted parent configurations with these shared rolling windows and its conservative band-rejection catalogue, retaining bounded review material only.

H's node-local capability policy is authoritative for hard ceilings. An admitted API job may request less work but cannot enlarge H beyond those limits.

### H additive voice mix (dev7)

For every H parent/window, the ordinary H ranking remains untouched. H additionally examines the **top 24 distinct H candidates by the existing score**, measures their actual rendered RMS, and selects the quietest distinct residual beside rank 1. The rank is not hard-coded; on current material it often lands around 15/16. H then creates:

- `h_voice_mix.wav` — unity-gain additive sum of H rank 1 plus the selected quiet residual;
- `h_voice_residual.wav` — the selected quiet residual alone for audit/listening;
- `voice_mix.tsv` — per-window lineage and RMS/selection evidence;
- `H_VOICE_MIX.tsv` — job-level aggregate over all parent/window pairs.

The residual inherits the promoted parent cancellation chain and H's added reject-band processing. Selection is based on **measured output quietness**, not an assumed rank number. The additive sum receives the standard sample-local `.88/.98` limiter; there is **no whole-wave peak normalization**. The mix is explicitly a new derived material and does not replace rank 1, the residual, or source evidence.

## H HTTPS control plane

H is the stable public ingress for the pool. Ordinary instructions use the existing ooRexx libraries rather than SSH wrappers:

```text
controller
   -> ApiRequest / ApiClient v0.3
   -> verified native HTTPS
   -> ooRexx HTTPS Server v0.4.4 on ed209h
   -> authorization interceptor
   -> durable spool / Observation journal
```

SSH is deployment/bootstrap/recovery only. DSP is never run inside the HTTPS request handler.

Endpoints:

```text
GET  /v1/health
GET  /v1/capabilities
POST /v1/jobs
GET  /v1/status?job_id=...
POST /v1/observations
GET  /v1/observations?node_id=...&after=...&max=...
GET  /v1/streams
```

`POST /v1/jobs` returns quickly after validation and durable commit. The separate `h_api_worker.sh` owns the single serial refinement worker. Identical job replay is idempotent; changed content under an existing job ID is rejected.

The accepted `audio.h.refinement.control/2` envelope is per-job authority for its bounded window/shortlist/workspace request. H's local node configuration remains the hard capability ceiling.

For the 09:45 campaign, `submit_h_campaign.sh` stages the two generated campaign masters into H's existing `H_AUDIO_ROOT`, verifies SHA-256, then submits the unchanged v2 job envelope.

## Content-addressed native build

Native libraries are built on each host so Oracle/Amazon/Debian/Ubuntu versions do not share a glibc ABI assumption. The dev6 content-addressed build/reuse discipline remains in v0.12-dev12, with one portability repair: the build fingerprint now hashes content identities rather than absolute `sha256sum` path text, so identical source installed under different roots reuses the same identity. Native DSP source otherwise changes only to generalize reference-profile construction from two fixed WAVs to a manifest-backed 2..32-reference corpus; candidate DSP/search mechanics are unchanged. A new deployment tree may build the native runtime once, after which normal fingerprint reuse applies.

`ensure_native_runtime.sh` fingerprints:

- `foreign_runtime_v0.22.6.cpp`;
- `audio_search_native.c`;
- `audio_checkpoint_fsync.c`;
- the host `oorexxapi.h`;
- the warning-as-error build contract.

A matching runtime is reused only after `ldd -r` and fsync-helper checks. Changed source/header input causes a rebuild. The fingerprint and resulting binaries are host-generated runtime state and are not shipped in the source archive.

For Azure/GCC portability, the DSP build retains `-Wall -Wextra -Werror` and scopes `-Wno-error=maybe-uninitialized` to `audio_search_native.c`. This demotes only that conservative diagnostic; every other warning remains a build failure.

## Pool conversation: the monkeys can talk

The pool conversation is durable **evidence**, not implicit execution authority. H hosts Observation-v0.5-backed streams for A-H/controller/reviewer messages such as:

```text
RESULT
VOICE_DETECTED
FRONTIER
HYPOTHESIS
REQUEST
REPLY
CAPABILITY
REVIEW
WARNING
STATUS
```

After collection, `publish_collected_observation.sh` can publish two observations for a node:

1. the historical scalar-ranked `RESULT`, explicitly described as experimental;
2. a `FRONTIER` report describing the non-dominated Pareto candidates and referencing `pareto_candidates.tsv`.

A coordinator — initially controller/ed209c — can compare evidence, ask F/G for a short GPU judgement, propose another experiment, or submit an explicit H job. A conversational `REQUEST` never executes work by itself.

See `POOL_CONVERSATION.md` for the wire envelope and trust boundary.

## Trust boundary

The current HTTPS bearer establishes ingress authentication/admission for the controller connection. It does **not** make `node_id=ed209a` inside an Observation cryptographic proof that A produced it.

This is deliberate and follows the Gopher-authoritative architecture:

- Observation producer `proofRef` fields are integration seams, not self-validation;
- authentication proves attribution/integrity, not Access Control or Permission authority;
- producer-specific proof should plug into the common trust/Permissions architecture rather than being reimplemented privately in this audio package.

Controller-proxied observation publication is therefore supported now. Direct autonomous per-worker producer proof remains an explicit future common-trust integration seam.

## H control commands

With H endpoint/CA/token configured:

```bash
./h_api.sh health -
./h_api.sh streams -
./h_api.sh observe /path/message.obs
./h_api.sh replay ed209c:0:50
./h_api.sh submit /path/h-job.txt
./h_api.sh status JOB-ID
```

Create the normal ±180/180/90 rolling job from collected A-E candidates:

```bash
./prepare_h_api_job.sh collected_results rank_01.wav run/controller/h-api-job.txt
./h_api.sh submit run/controller/h-api-job.txt
```

## Qualification

Local qualification is intentionally split so a single long synthetic command cannot obscure the failing boundary:

```bash
./tests/run_local.sh
./tests/run_h_api.sh
```

`run_h_api.sh` uses the **real API Client v0.3 and HTTPS Server v0.4.4 over a verified local TLS certificate**, then runs a bounded synthetic job through the durable H spool and serial rolling-refinement worker. dev7 additionally proves one `h_voice_mix.wav` plus auditable mix evidence per parent/window pair. Production timing defaults are separately asserted as ±180 / 180-second window / 90-second step.

See `QUALIFICATION.md` for the sealed-build evidence after final packaging.
