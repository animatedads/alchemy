# Source provenance — ooRexx LLM Personal Assistant v0.1-dev8

This cut continues `oorexx_llm_pa_v0.1-dev7.zip` (SHA-256 `e9a196cec12fce9a35e7e4a9d819daed48a9c7b24dd3bb1b4999754623c9de6c`) and the exact user-supplied dev2 lineage, authored against the user's ooRexx framework snapshot dated 2026-09-12.

Exact continuation/runtime inputs:

- `oorexx_llm_pa_v0.1-dev2.zip`
  - SHA-256 `e363f5804c199482324867bfc53dffa7c5a711f4c9938c66bd70b4d6cf6098f9`
- `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(20260912-113740).deb`
  - SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`
- `oorexxapis(20260912-113803).zip`
  - SHA-256 `aa1709f24b4a8473fcfb99f36c11c4bb718b9ce0e30d7a4f439d5df8cbdfeafb`
- `sphere(20260912-113802).zip`
  - SHA-256 `293cd2a62e04965e7c87134902d0509bb453cbe36618f895444a0af7465fc177`
- `llm_gopher_v0.21-dev1.zip` (extracted byte-for-byte from the same current API roll-up)
  - SHA-256 `6fc0114f730a64470a4e4a819832f933bfc5e628af19bb8b920d860b205fe477`

Framework artifacts inspected/exercised from that API snapshot:

- Object Queue Fabric v0.9-dev5 — `05b3cbc92aff353dc3a44eb0373d7efb1e49a5e81071892b410a8b8f63fa2262`
- Alchemy Objects v0.8 — `7683ed56ea99097226ea2f13f73305fb49919ba2ec822df2253ccfff59c6c073`
- Queue Fabric Web Gateway v0.2 — `83118442d7c734e4a194598b0709311de7a055ae33fb4e094cccf3686b7ffcf8`
- AI Access v0.6 — `40dfae56dfde682b78fd55f919566bf4092ca8724e759a9098257660a8a4b745`
- API Client v0.3 — `07a22f3d4c04f0589c7f6453c555f8fe8e4176b077c934d276648774dd4adfbc`
- AI Tool Orchestrator v0.3 — `d2499fa97a91b8eb3f27c36bfc816b0a8be728b90c9273da207d5008e5064ae8` (optional execution-authority seam)

The user's Codex transcript supplied additional target-host evidence: local Ollama had `gemma2:2b`, a live PA inference succeeded, and the existing experimental provider adapter still used `OpenAICompatCurlTransport`. dev3 therefore replaces that transport with an `ApiClient` `ApiTransport` implemented with RxSock and constrains it to loopback HTTP.

The delayed-reminder implementation continues the native ooRexx Alarm / AlarmNotification pattern qualified in dev2. Alarm expiry remains a queue-production event, not model or tool authority.

The ED209 seed utility is derived from the operational fleet facts in the user's Codex transcript. It deliberately writes them through the PA's normal Queue Fabric `remember` path instead of modifying `memory.journal` directly.

dev8 deliberately bundles the exact, unmodified LLM Gopher v0.21-dev1 tree and the exact external sphere ZIP members from the supplied sphere collection so the PA has a self-contained read-only evidence path. Those artifacts are not source-modified or granted execution authority. Other runtime framework dependencies remain separate packages supplied by the user's framework.

## dev4 target-host correction

The user's Codex target-host run identified a strict Ollama request-type defect in dev3: the PA serialised Rexx `.false` as numeric JSON `0` for `ChatCompletionRequest.stream`, and Ollama rejected the request because the Go field is Boolean. The runtime `json.cls` supplied with ooRexx 5.3.0 r13196 documents `.JSON~false` / `.JsonBoolean` as the Boolean-preserving representation. dev4 adopts that representation and adds a strict regression fixture.

## dev5 calendar / eventable one-shot contract

The user established that native ooRexx `Alarm` is one-shot: once triggered it ends and cannot represent hidden recurrence. dev5 makes that lifecycle visible through a read-only `calendar` capability and injects the same authoritative armed-alarm snapshot when Gemma is asked about current reminders. A repeated check-until workflow must be represented as a chain of explicit one-shot decisions: Alarm -> Gemma/tool check -> final, or a newly armed Alarm.


## dev6 Gemma-authored memory index

The user observed a live retrieval failure after remembering the free-form fact `for ssh we have a configured script ./sshnode.sh`: Gemma later answered generic SSH questions because the original memory key was the entire sentence. dev6 keeps the original fact intact but adds a separate lookup-key index. When a live orchestrator is present, Gemma authors the short key list during `remember`; deterministic/no-model runs use a clearly marked fallback. Historical five-field journal rows remain readable and are not rewritten.

## dev7 local knowledge / Gemma initial-timing contract

The user then demonstrated two live-model limitations. First, Gemma could retrieve ED209E/SSH memories but embellished them with unsupported role descriptions and guessed command syntax. dev7 therefore adds a bounded read-only local knowledge catalogue and removes lookup-key metadata from ordinary answer prompts; memory and local documentation are supplied with provenance and strict grounding instructions.

Second, the live command `-remind {10 secdonds time, what is ed209e}` was treated as immediate memory recall because earlier CLI logic only recognised the literal `IN ...` syntax. The user explicitly directed that Gemma determine the time for the initial Alarm. dev7 therefore sends natural `remind` text plus the PA-host local timestamp to Gemma under a constrained three-outcome contract (`RECALL`, `SCHEDULE|seconds|text`, `UNRESOLVED|reason`). ooRexx validates any proposed delay and owns construction of exactly one one-shot native Alarm. No recurrence is created by this interpretation step.

The target host shown by the user is using ooRexx API Client v0.4.1. The framework snapshot supplied in this conversation contains v0.3; dev7's loopback transport returns a writable `LlmPaApiResponse` subclass so deterministic qualification also works against that older snapshot while preserving the v0.4.1 elapsedMs contract on the target.

## dev8 LLM Gopher evidence contract

At the user's direction to "give Gemma the Gopher", dev8 adds a controlled read-only adapter over exact LLM Gopher v0.21-dev1. The PA bundles the exact Gopher artifact plus 53 external sphere archives extracted from the exact supplied `sphere(20260912-113802).zip`; `deps/gopher_catalog.tsv` contains 54 routable catalogue rows including Gopher built-ins.

The adapter exposes only evidence/navigation behavior. User text is locally scored against the catalogue; Gopher receives only validated sphere/article identifiers and exact known archive paths. The PA does not expose Gopher `exec`, source editing, sphere editing, package staging, or other mutating command surfaces. Returned evidence is stamped `READ_ONLY` / `EVIDENCE_ONLY`, flattened into Queue Fabric-persistable detached data, and treated by Gemma as project documentation rather than live state or authority.

Deterministic qualification opens the exact `queue-fabric.queue-authority` article and verifies its provenance against Queue Fabric v0.9-dev5 SHA-256 `05b3cbc92aff353dc3a44eb0373d7efb1e49a5e81071892b410a8b8f63fa2262`. Production daemon startup probes Gopher before declaring READY.


## 0.1-dev9-package-release-candidate1 package-release work

This candidate is based on the user-supplied in-progress Codex working archive
`oorexx_llm_pa_v0.1-dev8(4).zip`, SHA-256
`bc017f30ba4a564653044b97f1c8840b5ce9a3121a8ab86bf85a6a66f6806828`.
The input archive is treated as a WIP snapshot, not as a sealed dev8 provenance
anchor. The package-release work adds governed release semantics and deliberately
filters execution detritus observed in that working tree.

## 0.1-dev9-cognitive-abilities-candidate4 Cognitive Continuity integration

Candidate4 consumes the exact user-supplied `oorexx_cognitive_continuity_v0.1-dev2-exp1(1).zip`, SHA-256 `0e5d3fca25455afa76e0c7742c345fc492c1c7a86353cf95ef0a921bc791708c`.

That package is vendored unchanged under `deps/oorexx_cognitive_continuity_v0.1-dev2-exp1/` for sealed delivery.  LLMPA uses its `CognitiveContinuityService`, `CognitiveJsonlJournal`, `CognitiveAccessPolicy`, deterministic baseline classifier, context projection/export operations, and `LlmPaCognitiveAdapter`.  LLMPA does not claim authority over or fork those semantics.

The package's own documentation explicitly treats `CognitiveResult` and `CognitiveStructuredResponseBridge` as experimental compatibility outcomes rather than the estate Structured Response authority. Candidate4 preserves that boundary.
