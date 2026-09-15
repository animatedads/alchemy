# ooRexx Hugging Face Space Job v0.3-dev1

Generic managed execution of authorised workload endpoints hosted by Hugging Face Gradio Spaces.

It remains a sibling of Colab Job rather than a replacement:

- **Colab:** allocate -> stage -> execute -> retrieve -> release.
- **HF Space:** discover -> upload -> invoke allowlisted endpoint -> consume finite SSE result -> retrieve artifact -> require cleanup evidence.

The runner contains no Gemma/QLoRA/tokenizer implementation and no repository deployment authority.

## v0.3-dev1 verified artifact materialization

For the managed companion protocol, terminal result JSON may now carry `artifact_name`, `artifact_size`, and `artifact_sha256`. When an output directory is requested, `HFSpaceJobRunner` downloads the matching `gradio.FileData`, recomputes its SHA-256 locally with ooRexx Crypto, verifies the byte count, and records an `HFArtifactReceipt`. A malformed receipt, hash/size mismatch, or failure to materialize the named artifact fails closed.

The runner also rejects input-file parameter names that collide with the target's payload or control parameters before upload, preventing a workload file from overwriting `request` or `_job`.

The existing API Client v0.3 transport, ZeroGPU quota, endpoint allowlist, cleanup evidence and allocator authority boundaries are unchanged.

## v0.2.1

v0.2.1 is a dependency/qualification rebase only: the public HF Space job API and Space endpoint protocol are unchanged from v0.2. The allocator seam is now qualified against Job-to-Node Allocator v0.6.

## v0.2

v0.2 adds the stable Space-side companion protocol used by `Hugging Face Space Managed Endpoint v0.1`:

- optional `HFSpaceTarget.payloadParameter` nests operation-specific values under a fixed named JSON parameter (for the companion endpoint use `request`);
- terminal Gradio output may be `[result-json, FileData]` rather than only a single result object;
- additional `gradio.FileData` outputs are downloaded as artifacts while the first JSON object remains authoritative for status and cleanup;
- existing v0.1 flattened payload and embedded `artifacts[]` result forms remain supported.

## Transport

All network operations use ooRexx API Client v0.3. No `curl` or `gradio_client` subprocess is used.

The implemented Gradio contract is:

1. optional Hub discovery `GET https://huggingface.co/api/spaces/<namespace>/<repo>`;
2. `POST /gradio_api/upload` multipart upload;
3. submit in `AUTO` mode: prefer named `POST /gradio_api/call/v2/<endpoint>`; on HTTP 404/405, read `/gradio_api/info` and assemble the advertised positional `POST /gradio_api/call/<endpoint>` request;
4. `GET /gradio_api/call/<endpoint>/<event_id>` finite SSE;
5. terminal `event: complete` parsing;
6. exact-same-Space artifact retrieval.

`apiInfo`, `openApi` and `agentsMarkdown` remain available for introspection.

## Credential boundary

`HFTokenCredential` requires a token file with exact Unix mode `0600` (`-rw-------`), reads it only when constructing the Authorization header, and redacts credential-like evidence. It provides no Git/push/Space-settings/hardware-mutation capability.

A write-capable token therefore authenticates the call but does not grant the workload repository-write authority.

## ZeroGPU

ZeroGPU is a quota-limited function capability, not a dedicated VM assigned by this runner.

- CPU -> no GPU quota;
- up to 48 GiB -> `ZEROGPU_LARGE`, factor 1;
- >48 GiB and <=96 GiB -> `ZEROGPU_XLARGE`, factor 2;
- >96 GiB -> ineligible.

`HFZeroGpuQuotaBudget` defaults to zero. A nominal PRO included budget can be established explicitly as 2400 seconds, and paid-credit spillover requires both site-level and job-level opt-in. The budget never invents a midnight reset; `resetFromAuthority` refreshes it from observed/authoritative state.

## Companion endpoint shape

For `huggingface_space_managed_endpoint_v0.1`, construct the target with `payloadParameter="request"`:

```rexx
route=.ApiRouteRequirement~new('', '', 'PUBLIC', 'DIRECT')
target=.HFSpaceTarget~new('rexxapiai/rexxapi', '', route, .nil, .nil, .nil, '_job', 'request')
```

The runner's logical request is named and stable. On Gradio runtimes with the v2 API it is emitted directly as:

```json
{
  "request": {"steps": 100, "vocab_target": 65536},
  "input_bundle": {"path": "...", "meta": {"_type": "gradio.FileData"}},
  "_job": {
    "job_id": "...",
    "operation_id": "GEMMA_OOREXX_RECOVERY_V1",
    "cleanup_remote": true,
    "tier": "ZEROGPU_LARGE",
    "expected_gpu_seconds": 100,
    "checkpointable": true
  }
}
```

## File citizenship

Local inputs are validated before quota/network use. Uploads are bounded (default 256 MiB per file in this increment), artifact names are sanitized, and downloads are restricted to the exact Space host. The companion protocol uses a single input bundle and a single result bundle so the Gradio endpoint schema remains fixed.

Endpoint mode defaults to `AUTO`. `V2_NAMED` and `V1_DATA` can be pinned explicitly when a deployment requires a fixed wire contract. The v1 fallback never guesses parameter order: it uses `/gradio_api/info` and fails closed if the advertised endpoint/parameter metadata is missing or inconsistent.

Multi-GB transfer is not represented as solved by in-memory v0.2 upload. A later streaming source/sink or authorised Hub dataset/model/bucket path remains the correct large-artifact increment.

## Allocator seam

`HuggingFaceAllocatorAdapter.cls` maps provider requirements to Job-to-Node Allocator v0.6 hard eligibility. CPU work never gains a GPU requirement; GPU work requires the appropriate HF ZeroGPU tier tag. API Client egress routing remains a separate authority plane.

## Qualification

Qualified under ooRexx 5.3.0 r13196 Internal Test Version against:

- API Client v0.3
- Foreign Runtime v0.22.5
- Job-to-Node Allocator v0.6
- Crypto v0.8.3

No live Space was modified and no live ZeroGPU time was consumed. The packaged HTTPS fixtures exercise both native named-v2 submission and `AUTO` v2-to-v1 introspected fallback, plus multipart upload, chunked SSE `[result-json, FileData]`, artifact download, cleanup evidence and API Client session release. A separate local integration drove the actual companion endpoint under Gradio 6.5.1 over HTTPS and completed the same upload -> queue -> SSE -> FileData lifecycle through the fallback path.

See `REAL_GRADIO_VALIDATION.txt` for the actual local Gradio 6.5.1 interoperability proof.
