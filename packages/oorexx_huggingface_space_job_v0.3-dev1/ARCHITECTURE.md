# Architecture

```text
Generic workload
    |
    v
Job-to-Node Allocator -- hard target eligibility
    |
    v
HFSpaceJobRunner -- quota + job lifecycle
    |
    v
API Client v0.3 -- route/session/WLU + native HTTPS
    |
    v
Gradio Space
  job_cpu | job_large | job_xlarge
    |
    v
allowlisted operation implementation
```

Allocator eligibility, API egress authority, ZeroGPU quota accounting and Space operation authority are intentionally separate.

## Failure ordering

1. local file validation;
2. endpoint/tier eligibility;
3. ZeroGPU quota preflight;
4. upload;
5. quota reservation;
6. authenticated submission;
7. SSE completion;
8. cleanup evidence;
9. artifact retrieval.

A scoring preference cannot override hard ineligibility, and paid quota cannot be silently enabled by a transport success.

## Result forms

v0.2 accepts:

- a single JSON result object;
- a one-element array containing that object;
- `[result-json, FileData, ...]`, where the first object is authoritative and FileData outputs are downloadable artifacts;
- the v0.1 `result.artifacts[]` form.

This supports ordinary Gradio `gr.JSON` + `gr.File` endpoint outputs without teaching the runner operation-specific schemas.


## Gradio wire compatibility

`HFSpaceEndpoint` defaults to `AUTO` mode. The logical endpoint contract remains named (`request`, `input_bundle`, `_job`) while the adapter negotiates the wire shape:

1. try current named `/gradio_api/call/v2/<endpoint>`;
2. only on HTTP 404/405, read `/gradio_api/info`;
3. map the named payload into the endpoint's advertised parameter order;
4. submit `{"data":[...]}` to `/gradio_api/call/<endpoint>`.

This is a compatibility negotiation, not a second authority path: the same allowlisted endpoint, operation id, control object, credential, route and evidence rules apply. Missing or malformed API metadata fails closed rather than guessing an order.

## Result integrity in v0.3-dev1

The Space-side companion is authoritative for the result artifact receipt (`artifact_name`, byte length and SHA-256) after it has built the result bundle. The ooRexx runner is authoritative for verifying the locally materialized bytes against that receipt. Transport success alone is not completion evidence. Storage Fabric promotion remains a separate post-job durability decision.
