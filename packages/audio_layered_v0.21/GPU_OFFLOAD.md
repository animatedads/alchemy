# GPU and managed-compute placement

Layered Audio v0.21 does not allocate execution nodes.  It exports placement requirements from processor semantics and leaves authoritative eligibility/ranking/lease creation to the Job-to-Node allocation layer.

The current execution vocabulary distinguishes CPU-light, CPU-vector/native-DSP and GPU-optional/preferred/required workloads.  FFT/STFT-heavy coherence, MVDR, eigen/covariance and large spatial scans are marked GPU-preferred where batching can amortize transfer/launch overhead; simple lag/filter/statistics operations remain CPU-suitable.

`AudioProcessingDispatchEnvelope` is deliberately value-only.  It can be placed on Runtime Reference/Queue/managed-compute paths because it contains processor/config ids, parameter values, semantic material references, desired outputs and placement requirements, but no process-local `ForeignBuffer`, `ForeignTensor`, Python proxy or native pointer.

A remote provider should return derived material/evidence references plus execution provenance.  Layered Audio then adds those products as ordinary derived layers; GPU execution does not make one branch more authoritative than a CPU branch.


## Stateful streams

A stateful processor may require provider/node affinity across blocks. `AudioStreamingProfile~stateTransferMode` records whether state is absent, checkpointable as detached values, or provider-affine. Current local ForeignPython adaptive-denoise, echo-persistence and dynamic-filter streams are provider-affine. `AudioProcessingStreamDispatchEnvelope` therefore carries stable session/checkpoint identity and `session_affinity_required=true` in placement requirements; it does not serialize Python objects, `ForeignTensor` handles, filter state arrays or other runtime capabilities. A managed-node/queue adapter may use that requirement to keep successive blocks on one eligible execution lease.
