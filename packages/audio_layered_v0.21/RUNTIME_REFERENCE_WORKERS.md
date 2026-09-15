# Runtime Reference workers - Layered Audio v0.21

Layered Audio owns semantic audio operations; Runtime Reference v0.4 owns implementation/provider selection.

## Existing value operations

The existing PURE operations remain unchanged, including speaker embedding/verification, pitch, music fingerprint/identification, FFmpeg introspection, media audio decode and PCM transform/resample. The preferred local Python ML/processing implementation is ForeignPython; the TCP Python service remains a remote/process-isolated fallback.

`json.cls` and `socket.cls` are ooRexx runtime packages, not external Layered Audio dependencies. `run_tests.sh` resolves them from the active Rexx installation and qualifies the TCP/JSON fallback whenever `RUNTIME_REFERENCE_SRC` is supplied.

## Resident tensor material is not a PURE wire value

`AudioMLTensorBinding` and processing graph intermediates may contain transient process-local `ForeignTensor` capabilities. These are never passed through a PURE TCP/value contract. Persistent meaning remains in the material/tensor descriptors; live handles remain local runtime state.

## Stateful processing streams

Runtime Reference v0.4 also defines `STATE_TRANSFORM`, but Layered Audio v0.21 does not pretend that large resident DSP state (noise-floor arrays, delay history, IIR `zi`, model state) is automatically a detached state-transform value. Instead the processor declares a state-transfer mode:

- `NONE` — no state to carry.
- `CHECKPOINTABLE` — a future implementation may detach and validate complete state values.
- `PROVIDER_AFFINE` — successive blocks require the same selected provider/session placement.

The current ForeignPython adaptive-denoise, echo-persistence and dynamic-filter reference streams are `PROVIDER_AFFINE`. `AudioProcessingStreamDispatchEnvelope` contains only semantic session/checkpoint/block/material references plus placement requirements. A queue/managed-node adapter can therefore enforce session affinity without receiving process-local Python/tensor handles.
