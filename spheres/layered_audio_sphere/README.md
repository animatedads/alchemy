# Layered Audio LLM Gopher sphere v0.2

Authoritative continuity sphere for Layered Audio and the second-generation Audio Processing Toolkit.

Start with:

    gopher --profile layered-audio context layered-audio --full
    gopher --profile layered-audio search streaming --sphere layered-audio
    gopher --profile layered-audio search memory-horizon --sphere layered-audio
    gopher --profile layered-audio search resident --sphere layered-audio
    gopher --profile layered-audio search downmix --sphere layered-audio
    gopher --profile layered-audio search quantization --sphere layered-audio

The implementation and this sphere are separate artifacts. The sphere preserves architecture, durable lessons, method doctrine, runtime/streaming boundaries, precision/offload semantics, memory-local execution, provenance and qualification continuity; it does not replace source code or executable tests.

## Current memory-local execution continuity

The October 2026 cluster-memory work adds an explicit cross-stack rule: when the next Audio working set is already resident elsewhere, execution follows the fenced Memory Fabric block rather than dragging the block to the current runner. Memory Fabric owns residency and adaptive-horizon demand; Job-to-Node owns placement/admission authority; Queue Fabric carries the compact runner/control envelope; Storage Fabric retains durable material identity; Audio owns acoustic semantics and compact continuation state.

See `arch.layered-audio.memory-local-execution`.

The current candidate20 source/contract package is published to Alchemy Autobuild as submission `20261023T154600Z-CHATGPT-audio-v9-cluster-memory-c20-1b3088`. Its full r13196 cross-package runtime qualification remains pending; the sphere records that limitation rather than promoting source qualification into runtime evidence.
