# Layered Audio LLM Gopher sphere v0.4

Authoritative continuity sphere for Layered Audio and the second-generation Audio Processing Toolkit.

Start with:

    gopher --profile layered-audio context layered-audio --full
    gopher --profile layered-audio search intentions --sphere layered-audio
    gopher --profile layered-audio search speech --sphere layered-audio
    gopher --profile layered-audio search Management --sphere layered-audio
    gopher --profile layered-audio search object-preserving --sphere layered-audio
    gopher --profile layered-audio search memory-horizon --sphere layered-audio
    gopher --profile layered-audio search streaming --sphere layered-audio
    gopher --profile layered-audio search downmix --sphere layered-audio

The implementation and this sphere are separate artifacts. The sphere preserves architecture, durable lessons, method doctrine, runtime/streaming boundaries, precision/offload semantics, memory-local execution, object-bound intention semantics, Speech TTS/STT composition boundaries, provenance and qualification continuity; it does not replace source code or executable tests.

## Object-bound intentions and Management federation

Layered Audio intentions are projections of the live Audio object graph, not a permanent command catalogue. `AudioRecording`, `AudioElement`, `AudioView`, boundaries and compound selections remain the original ooRexx objects across discovery and proposal boundaries. Intention Service interprets, clarifies and READY-gates those proposals. Management Intention Discovery may federate Audio with related authorities through Audio-owned relationships, but it does not become authoritative for Audio or Storage.

The v0.22-dev8 intentions overlay adds the canonical Management installer. It registers the Audio self-assessing source and Audio relationship source through Management's public contracts, then builds related-surface discovery and the Management explorer. Storage may be supplied as a separate related intention source; Audio does not copy Storage vocabulary or materialisation authority.

See `arch.layered-audio.intentions`.

## Speech TTS/STT composition

Speech is a sibling semantic service, not a replacement Audio layer. `oorexx_speech` owns TTS/STT channels, streaming sessions and speech-provider orchestration. Layered Audio keeps authoritative Audio objects, acoustic evidence and processing lineage. Storage keeps durable material identity; SIP/RTP and local device systems keep signalling, packetization and device authority.

The bridge may use a transient Audio execution binding's `localPath` while carrying the exact durable `identityKey` as lineage metadata. The path never becomes the Audio identity. Speech dev11 also follows the same dynamic-intention doctrine: every discovery re-reads the current `SpeechRuntime` and retains the exact live channel objects.

See `arch.layered-audio.speech-integration`.

## Current memory-local execution continuity

The October 2026 cluster-memory work adds an explicit cross-stack rule: when the next Audio working set is already resident elsewhere, execution follows the fenced Memory Fabric block rather than dragging the block to the current runner. Memory Fabric owns residency and adaptive-horizon demand; Job-to-Node owns placement/admission authority; Queue Fabric carries the compact runner/control envelope; Storage Fabric retains durable material identity; Audio owns acoustic semantics and compact continuation state.

See `arch.layered-audio.memory-local-execution`.

The current candidate20 source/contract package is published to Alchemy Autobuild as submission `20261023T154600Z-CHATGPT-audio-v9-cluster-memory-c20-1b3088`. Its full r13196 cross-package runtime qualification remains pending; the sphere records that limitation rather than promoting source qualification into runtime evidence.
