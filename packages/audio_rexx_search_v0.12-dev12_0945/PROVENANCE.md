# Provenance — v0.12-dev12

## v0.12-dev12 — manifest-backed quality corpus

The user requested substantially better quiet/high-register voice reference coverage. The supplied `WhatsApp Audio 2026-09-08 at 17.15.39.mp4` (SHA-256 `a3cb001a35a1567cdfc91d076a8c3ce7f062c189c31021f2b205c5add583c2bb`) contributes two sample-exact 48-second derived references: 489..537 s and 765..813 s. They are decode/downmix/resample-only PCM16/16 kHz/mono material; level differences are preserved.

The separately uploaded `24 August Threats ... 1(2).mp3` is SHA-256-identical to the already represented target 01 (`f59b6f88ac7693655d0a1610e8380442853afcb6a94534d2d28b48a45c17c867`) and is therefore not duplicated in the corpus. `verify_prepared_samples.sh` independently rejects duplicate prepared-reference hashes.

The scoring ABI is generalized with `as_context_new_corpus`: `reference/QUALITY_CORPUS.tsv` may list 2..32 distinct references. Global/temporal profile statistics are robust across reference files and the nearest-window objective searches all reference windows. Pre-v2 reference-distance/scalar scores are calibration-incompatible with v2.

During clean-root qualification, dev12 also corrected the native build fingerprint so it hashes source/header content hashes and the build contract rather than `sha256sum` output containing absolute installation paths. Identical source now produces the same build identity across package roots (`c97554288df6f0d501dca33ba7148d29ba716a10fcfaf74005cfcb3edc7d4c69`).

## v0.12-dev11 — fail-closed prepared-fixture admission

The dev10 campaign policy required the known CCTV alarm to be excluded but the controller only reported the detector interval count; it could continue with zero matches. Separately, `deploy_all.sh --no-prepare` required only the existence of `SAMPLES.sha256` and did not re-verify its contents. dev11 closes both gaps before any remote node contact.

`verify_prepared_samples.sh` verifies sealed hashes, exact sample counts, alarm-mask schema/order/range, nonzero alarm detection by default, and the derived parent-source/parent-companion exclusion manifests. Both preparation and deployment invoke this authority. `CCTV_ALARM_REQUIRE_MATCH=0` is retained solely for explicit diagnostic use. Search/DSP/ML/Pareto/H semantics are unchanged from dev10.

Input continuation baseline: `audio_rexx_search_v0.12-dev10_0945(3).zip` SHA-256 `e2b10d690efc5b830db849d18a05d4092afa159ae398d94f544cd56fb83d780b`.

## v0.12-dev10 — CCTV alarm hard exclusion + H TSV parser baseline

The user established that internal CCTV alarm sections are exceptionally loud and visually obvious on the untouched waveform, while the recovery target is the quiet material that is not visible. dev10 therefore introduces `CCTV-ALARM-EXCLUSION-V1`: repeated near-full-scale alarm clusters are detected only on original/unamplified primary PCM, projected to the same wall-clock interval on the companion, and zeroed before all search/refinement while preserving timeline. The generated exclusion manifests are hashed with the prepared samples.

The prior H controller hotfix is promoted into baseline: candidate TSV rows must contain exactly 17 columns, then tabs are converted to a non-whitespace delimiter before Bash `read`, preserving empty `reject_bands`.


## 09:45 controller hotfix H1

Post-run controller qualification exposed three transport/fixture issues without changing worker search semantics: an Ogg splice produced 569.189125 s instead of the required 570 s; H staging needed the managed SSH config on the controller; and Bash tab-IFS parsing collapsed an empty `reject_bands` field, shifting the processing chain and causing H to reject the envelope with `INVALID_REJECT_BANDS`. H1 makes the 570 s companion master sample-exact at 9,120,000 samples, uses the managed SSH config/key seam for H staging, and preserves empty TSV columns before constructing the H API envelope.

## v0.12-dev9 — ED209i joins the pool

ED209i is an Azure x86-64 worker at 20.114.63.150, login `azureuser`, verified externally with exact ooRexx 5.3.0 r13196 and `/usr/local/bin/rexx` + `rexxc`. Reported capacity is 891 MiB RAM, persistent 2 GiB swap and about 59 GiB free root disk. Strategy I is a new bounded high-cancellation voice-residual lane; A-E and H DSP semantics remain unchanged. The deployment controller defaults `ED209I_KEY` to `~/.ssh/id_ed25519` and permits host/user override through `ED209I_HOST`/`ED209I_USER`.


## v0.12-dev9 — quality target replacement + 09:45 campaign

This package derives from sealed `audio_rexx_search_v0.12-dev7_112230.zip`. It preserves the dev7 native DSP/search engine, ML dev5 lifecycle, H rolling geometry, HTTPS/Observation boundary and H additive voice mix. Two intentional semantic changes are introduced:

1. active scoring references are replaced by `AUDIO-QUALITY-TARGETS-V1`, exact deterministic 16 kHz mono PCM16 derivatives of the two user-supplied clean speech recordings;
2. campaign media is retargeted to 09:45 with primary tp00006 and a tp00023->tp00024 companion splice at 09:45:21.

The quality-target source files are immutable provenance in the separately sealed `audio_quality_targets_v1.zip`; this search package carries only the canonical prepared references plus their target metadata. The historical evt_000071/evt_000597 references are retired from the active package. dev8 search scores are therefore not numerically comparable with dev7/earlier scores. Pareto objective-set identity advances to `RECOVERED-AUDIO-PARETO-V2`.

The Layered Audio Gopher doctrine was retained: source evidence is not mutated; preparation produces derived material with explicit lineage; materially different derived views remain independently traceable.


## v0.12-dev7 — H additive voice-mix derivation

This package is derived from the sealed v0.12-dev6 11:22:30 gap-fill package. A-E search, ML dev5, Pareto semantics, campaign timing, H rolling geometry, HTTPS admission/spool semantics and Observation authority are unchanged. dev7 changes only H's derived audio materialization/evidence path.

For each H parent/window, the existing band-refinement catalogue is scored and de-duplicated exactly as before. A separate top-24 pool is formed from that ordering. Rank 1 is retained as the primary view; H measures the rendered RMS of the other pool members and selects the quietest distinct residual (rather than assuming rank 15/16). It emits `h_voice_mix.wav` as a unity-gain additive sum of primary + residual with the standard sample-local `.88/.98` limiter and no whole-wave peak normalization. `h_voice_residual.wav`, per-window `voice_mix.tsv`, job-level `H_VOICE_MIX.tsv`, RMS values, selected ranks, reject-band plan, inherited parent cancellation strength, mix score and PCM hash preserve lineage.

This follows the Layered Audio Gopher evidence doctrine: the mix is a new derived material with provenance; it does not mutate or replace the ranked views or source evidence. The ordinary H ranking and `review_candidates.tsv` remain unchanged.

Native implementation additions are `as_output_rms_db`, `as_evaluate_additive_mix` and `as_render_additive_mix`, exposed through the existing Foreign Runtime bridge and `AudioSearchNativeContext`. The native source fingerprint changes, so `ensure_native_runtime.sh` rebuilds H's DSP library exactly once on first use of dev7 and then resumes normal content-addressed reuse.


## Current supplied baselines

- `oorexx_ml_v0.1-dev5(1).zip` — SHA-256 `b9aa9b80031743508b025c69d3819f00ea2a8e93aeb00f7ccc22691a0866c122`.
  - v0.1-dev5 adds first-class multi-objective/Pareto search, Pareto retention, deterministic Pareto GA, recovered-audio Pareto objectives, and retains dev4 review/calibration plus the dev3 complete-GA-run repair.
  - The supplied dev5 archive contains 23 executable tests and records qualification under ooRexx 5.3.0 r13196.
  - The vendored ML source in `lib/` is byte-identical to the supplied dev5 source for `OorexxML.cls`, `MLCore.cls`, `MLEvolution.cls`, `MLTraining.cls`, `MLValidation.cls`, `MLStandard.cls`, `MLSearch.cls`, `MLReview.cls`, `MLMultiObjective.cls` and `AudioParetoObjectives.cls`.
- `oorexx_ml_gopher_sphere_v0.1-dev5(1).zip` — SHA-256 `6ee74a3b454bded3a0a01e114b8d301bf047425d186a55400fdac769042b72a1`.
- `oorexxapis(20260906-192211).zip` — SHA-256 `aa1709f24b4a8473fcfb99f36c11c4bb718b9ce0e30d7a4f439d5df8cbdfeafb`.
  - API Client v0.3 authoritative nested archive — SHA-256 `07a22f3d4c04f0589c7f6453c555f8fe8e4176b077c934d276648774dd4adfbc`.
  - HTTPS Server v0.4.4 authoritative nested archive — SHA-256 `aad4305c2495b13145a71938c59af86bc8d128be8d466aaf7b3548468a252d56`.
  - Observation v0.5 authoritative nested archive — SHA-256 `0f604f78d5d198190ae209c813fd287967f94ddaf6116dfa83b4e1904a9f6ed7`.
- Current supplied sphere roll-up `sphere(20260906-192208).zip` — SHA-256 `b6f49ddfd0864bb2b47e7a9e608a56fd68d530d9ff77dc3d5ff80f14e7e075f2`.
- Gopher-derived browser/API-access sphere snapshot used during H control design — SHA-256 `eecb60b50b6f469a8438842eeca4305f45dfdd080947107613b62b3b26a32c75`.
- Gopher-derived HTTPS Server sphere snapshot — SHA-256 `23e2117e83bc693460ebd3aefc0c361f9bc4f6f9fe7754006122452e89a2ef5b`.

The exact ooRexx execution baseline remains **5.3.0 r13196**, 64-bit, build date 3 Aug 2026, installed on the persistent ED209 CPU workers.

## ooRexx ML dev5 adoption

v0.12-dev6 vendors the supplied dev5 ML source. Strategy C continues to use `MLGABudgetPlan`, named `MLGeneticPolicy`, `MLObjectiveFitnessAdapter` and `MLGeneticAlgorithm~run()`, so the final bred population is evaluated and score direction is owned by ML Core.

Dev5 is additionally consumed for recovered-audio multi-objective evidence. Every A-E shortlist publishes independent MINIMIZE objectives for quality-target distance, pre-limiter over-range and post-limiter clipping, with non-dominated rank and crowding evidence. The historical scalar score remains available only as an explicitly experimental continuity ranking pending perceptual calibration.

## Native implementation provenance

- Foreign Runtime source snapshot: `native/foreign_runtime_v0.22.6.cpp` — SHA-256 `bb91aa94ddc23be928112768d3dddf41aa0639197597dce8cd688cc93bcc7dff`.
- `native/audio_search_native.c` and `native/audio_checkpoint_fsync.c` are package-owned manifest-protected source.
- Generated `.so` files, compiled `.orx` files, build fingerprints, test work, run logs and result material are deliberately excluded from the authoritative source archive.
- Each worker builds native components against its own host ABI. `ensure_native_runtime.sh` now uses a content fingerprint over native source, the ooRexx API header and build contract, then validates reusable binaries with `ldd -r` rather than rebuilding Foreign Runtime on every H server restart/job.

## A-E retained search repairs

- C shared gain/filter/denoise choices contain the A/B/D shared boundaries; `MLSearchSpaceComparison` reports those relations explicitly.
- Azure warning-as-error portability initialization remains retained. The DSP compile contract keeps `-Werror` globally but adds `-Wno-error=maybe-uninitialized` for `audio_search_native.c`, because Azure GCC can emit a conservative `maybe-uninitialized` diagnostic for the qualified code path; all other warning classes remain fatal.
- A-E staging/launch is parallel and failure-isolated.
- ed209b keeps its 7 GiB workspace contract and a separate tree from any historical Python run.
- ed209e is a standard/non-Spot GCP worker; deterministic checkpoint/resume remains as general restart resilience.
- E numeric checkpoint identity is canonicalized so fresh and restored parameter values do not create false-distinct cache identities.

## Multi-band rejection and Strategy H

The native `ASParams` contract accepts up to six rejected intervals. Interior intervals use cascaded RBJ band-stop sections; edge intervals become appropriate high/low-pass rejection. The earlier split-branch prototype was rejected after insufficient centre attenuation. The retained implementation qualified at about 28 dB attenuation of a 500 Hz component for a 450-550 Hz rejected band while preserving an unrelated 2 kHz component.

ed209h (Vultr Atlanta, Ubuntu 26.04.1, 1 vCPU / 4 GB class, ooRexx r13196) is the stable public HTTPS ingress, durable Observation/conversation hub and serial rolling voice-frontier refinement worker. For a promoted parent, H replays the exact parent configuration across five overlapping three-minute windows spanning three minutes before through three minutes after the parent (`-180,-90,0,+90,+180` second starts with a 180-second window and 90-second step), then applies bounded band-refinement plans.

## H HTTPS / conversation authority

Gopher was used to select the existing common seams rather than inventing an audio-specific transport:

- outbound instruction submission is owned by API Client v0.3;
- inbound TLS/routing/interceptors are owned by HTTPS Server v0.4.4;
- authentication is performed at the HTTPS interceptor boundary;
- the route durably commits and returns quickly; DSP never executes inside the request handler;
- a separate serial worker drains H's spool;
- Observation v0.5 backs replayable pool evidence/conversation.

Conversation is evidence, not execution authority. Worker `RESULT`, `VOICE_DETECTED`, `FRONTIER`, `HYPOTHESIS`, `REQUEST`, `REPLY`, `REVIEW`, `WARNING` and similar observations may inform the coordinator, but only a separately admitted job changes execution. Observation `proofRef` remains a common trust integration seam; this package does not invent private per-node permission semantics.

## 11:00 campaign retarget

This campaign is derived from the corrected `audio_rexx_search_v0.12-dev6_block45.zip` baseline. Search/DSP/ML/HTTPS/Observation implementation files are unchanged; only campaign timing/source identity, A-E job timing, H campaign/thread identifiers, and campaign documentation are retargeted.

Primary: `20231010_093912_tp00006_original.ogg`, `4758..4938` seconds, wall clock `10:58:30..11:01:30`.
Companion: `20231010_104209_tp00026_original.ogg`; exact centred 3-minute view `981..1161`; prepared alignment view `966..1176` seconds to preserve the established ±15-second margin.


## 11:15 campaign retarget

The 11:15 campaign is derived from the sealed 11:00 v0.12-dev6
campaign. DSP, native-kernel, ML dev5, ranking, Pareto, HTTPS,
Observation and H temporal-refinement implementation remain unchanged.
The only functional extension is deterministic **fixture stitching**
across sequential camera files because the requested wall-clock parent
crosses the tp00006/tp00007 boundary and H's earliest companion roll
crosses the tp00026/tp00027 boundary.

Primary provenance: tp00006 `5478..5737`
(`11:10:30..11:14:49`) + tp00007 `0..281`
(`11:14:49..11:19:30`). Parent source: campaign-master `180..360`
= `11:13:30..11:16:30`.

Companion provenance: tp00026 `1686..1708`
(`11:10:15..11:10:37`) + tp00027 `0..548`
(`11:10:37..11:19:45`). Parent companion: campaign-master
`180..390` = `11:13:15..11:16:45`.

## 11:30 campaign retarget

The 11:30 campaign derives from the sealed 11:15 v0.12-dev6 campaign and changes no DSP, native-kernel, ML dev5, Pareto, HTTPS, Observation or H temporal-refinement semantics.

Camera authority is preserved: the primary sequence is tp00006 -> tp00007 and the companion sequence is tp00026 -> tp00027.

Primary provenance: `20231010_111449_tp00007_original.ogg`, campaign-master source offset `639..1179` (`11:25:30..11:34:30`), A-E parent offset `819..999` (`11:28:30..11:31:30`).

Companion provenance: `20231010_111037_tp00027_original.ogg`, campaign-master offset `878..1448` (`11:25:15..11:34:45`), exact centred 3-minute view `1073..1253`, prepared parent alignment view `1058..1268` (`11:28:15..11:31:45`).


## 11:22:30 gap-fill retarget

Derived from the sealed 11:30 v0.12-dev6 package with search/refinement implementation unchanged. Primary tp00007 source master uses media offset 189..729, derived from the authoritative 11:30 centre 909. Companion tp00027 master uses 428..998. Parent base offset is 180 in both masters.