# Nearline cognitive learning interface

API: `cognitive.learning/0.1`

Request: `cognitive.learning.request/1`  
Result: `cognitive.learning.result/1`

The scheduler asks Cognitive Continuity for `cognitive.learning.delta`, converts the immutable delta into a learning request, then enqueues it through Queue Fabric. The adapter is compatible with `ObjectQueueManager~put/claim/ack` and intentionally does not own queue creation, provider credentials, compute allocation or worker selection.

Recommended queue: `COGNITIVE.LEARNING`.

Suggested worker capabilities:

- `MULTI_LABEL_CLASSIFICATION`
- `NEIGHBOUR_DISCOVERY`
- `GENERALISATION`
- `LESSON_DISCOVERY`
- `PROCEDURE_DISCOVERY`
- `TOOL_DISCOVERY`
- `PROJECTION_ANALYSIS`

Hugging Face/Colab are compute implementations. Existing `oorexx_huggingface_space_job_v0.3-dev1` and `oorexx_colab_job_v0.3-dev1` remain the provider/job owners. The cognitive package must not absorb their lifecycle or secret semantics.

An hourly trigger processes deltas, not necessarily the full corpus. Budget exhaustion or provider failure leaves durable cognitive state unchanged; work can be deferred/retried through Queue Fabric.
