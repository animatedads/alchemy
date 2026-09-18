# Changelog

## 0.1-dev6-exp1

- Add durable **measurement-only** capture of `cognitive.learning.result/2` from Qwen/nearline workers.
- Require exact request id and scope correlation between the learning request and result.
- Reject nested provider-supplied authority/admission fields.
- Require every non-empty proposal item to carry `basisRefs`, and reject basis refs not present in the exact learning request's cognitive records or measurements.
- Add `COGNITIVE.LEARNING.RESULT.RECORD` and read-only `COGNITIVE.LEARNING.RESULTS` native operations.
- Learning results are deliberately excluded from subsequent learning bundles by default, preventing automatic self-training feedback loops.
- Preserve all dev5 real-dog-food and task-aware projection behaviour.

## 0.1-dev5-exp1

- Add evidence-bound external dog-food observations as measurement-only evidence.
- Forward dog-food observations in `cognitive.learning.request/2`.
- Add the real Safety29/Codex dog-food qualification case.
