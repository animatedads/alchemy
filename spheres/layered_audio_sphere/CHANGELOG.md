# Changelog

## 0.4
- Added `arch.layered-audio.speech-integration` documenting the authority boundary between Layered Audio and provider-neutral ooRexx TTS/STT.
- Recorded the qualified Speech dev10 batch/streaming, Azure Macrospace, telephony PCM, Audio execution bridge, local audio controller and duplex-session baseline.
- Recorded dev11 dynamic Speech intention discovery: each discovery re-reads the live `SpeechRuntime`, retains exact channel objects and removes duplex availability while a required lane is busy.
- Recorded that Audio/Storage execution may expose transient `localPath` while durable `identityKey` remains authoritative lineage; Speech must not flatten that distinction.
- Reaffirmed that SIP/RTP/device authority remains outside Speech and that ASR hypotheses do not become Layered Audio evidence truth.
- Kept exact r13196 runtime status honest: dev11 static standards PASS is recorded, while the new intention regression is pending runtime execution in the current container.
- Advanced `arch.layered-audio.intentions` to the v0.22-dev9 authority/feasibility boundary.
- Recorded that denied semantic capabilities remain observable as `UNAVAILABLE` with native Audio objects and gate evidence intact.
- Recorded fail-closed handling for malformed live gates and mandatory gate revalidation before composite READY.
- Recorded the Rasen Falcon `layered-audio-intentions` lane and independent CODEX-PC runtime-test request as coordination evidence, not runtime proof.

## 0.3
- Added `arch.layered-audio.intentions` for live, object-bound Audio intention discovery and Management federation.
- Recorded that AudioRecording, AudioElement, AudioView and compound selections remain native ooRexx objects across intention boundaries; IDs, paths and prose are not substitute domain objects.
- Recorded Intention Service as interpretation/clarification/READY authority and Management Intention Discovery as federation/traversal authority, while Audio retains Audio truth.
- Recorded Audio-owned relationship edges for recording/element/view, derived lineage, view evidence sources and the Audio-to-Storage binding seam.
- Recorded the rule that Storage intention surfaces remain Storage-owned and may only be reached as separately supplied related authority surfaces.
- Recorded `AudioManagementInstaller` as the canonical Management composition seam for the v0.22-dev8 intentions overlay.
- Added durable lessons and continuation checks for dynamic appearance/disappearance, ambiguity, exact object preservation and cross-domain authority separation.
- Updated qualification continuity with the dev8 static/package PASS and explicit pending fresh ooRexx r13196 runtime execution.

## 0.2
- Added `arch.layered-audio.memory-local-execution` for the Audio V9 / Memory Fabric adaptive-horizon execution model.
- Recorded the authority split: Memory Fabric owns resident block identity/fencing, Job-to-Node owns admission/placement, Queue Fabric carries runner/control state, Storage Fabric owns durable material identity, and Audio remains cluster-unaware.
- Recorded the commit ordering rule: destination MOVE acknowledgement precedes Memory Fabric cursor advance and horizon-demand satisfaction.
- Recorded fail-closed cases for missing residency, stale block/provider epochs, unverified placement and uncertain Queue Fabric delivery.
- Added durable lessons for execution-to-memory locality and handoff commit ordering.
- Updated qualification continuity to the October 2026 Memory Fabric dev10 / RTO2 Grid dev14 / Storage Fabric dev21 estate and the candidate20 Autobuild submissions, without claiming pending r13196 cross-package runtime qualification.

## 0.1
- Added explicit allocator-boundary retrieval lesson and qualification search.
- Initial authoritative Layered Audio / Audio Processing Toolkit continuity sphere from implementation v0.23 and historical processing-method corpus.
- Initial sphere scaffold.
