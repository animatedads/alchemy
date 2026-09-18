# ooRexx Cognitive Qwen Space Worker v0.1-dev2

Nearline Queue Fabric consumer for `cognitive.learning.request/2`.

It executes only the allowlisted Hugging Face Space operation `COGNITIVE_QWEN_INTEGRATION_V1` through `HFSpaceJobRunner`. Qwen is an analysis worker: returned `cognitive.learning.result/2` data is proposal-only and cannot directly admit cognitive state.

The model identity is owned by the Space deployment (`COGNITIVE_QWEN_MODEL`); callers cannot choose an arbitrary model through the cognitive request.

Dependencies:
- ooRexx Hugging Face Space Job v0.3-dev1
- API Client v0.3 dependency closure required by that package
- Cognitive Continuity learning request/result v2 contracts

## Result sink

`CognitiveQwenQueueConsumer~new(queueAdapter, worker, resultSink)` may receive a sink implementing `capture(learningRequest, learningResult)`. On successful Qwen execution the consumer invokes the sink before ACK. A rejected capture causes NACK, so a proposal result cannot be silently lost between remote execution and local measurement persistence. Cognitive Continuity dev6 provides request-id idempotency for Queue retry.
