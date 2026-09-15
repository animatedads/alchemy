# Managed Space Job Contract v0.2

Compatible Spaces expose three configurable named endpoints:

- `job_cpu`
- `job_large`
- `job_xlarge`

The recommended companion endpoint has the logical named parameters `request`, `input_bundle`, `_job` and returns `result`, `artifact`. The ooRexx adapter defaults to `AUTO`: it uses the named v2 call when available, or derives the older positional v1 request from `/gradio_api/info` after a v2 404/405. It never hard-codes or guesses the v1 parameter order.

`_job.operation_id` is mandatory and must map to a server-side allowlist. Unknown operations fail closed. Arbitrary command strings, script paths and environment injection are outside the contract.

The server owns a job-specific workspace and cleans it in a `finally` path. `cleanup="DONE"` is only valid after that execution workspace is removed. A separately bounded result cache may retain the artifact long enough for Gradio to serve it.

The terminal SSE `complete` data may be:

```json
[
  {"status":"COMPLETED","cleanup":"DONE","operation_id":"MANAGED_SMOKE_V1"},
  {"path":"...","url":"https://<same-space>/...","orig_name":"result.zip","meta":{"_type":"gradio.FileData"}}
]
```

The ooRexx runner restricts artifact retrieval to the exact resolved Space host.
