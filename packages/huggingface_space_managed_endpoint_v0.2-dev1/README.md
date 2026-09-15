# Hugging Face Space Managed Endpoint v0.2-dev1

Space-side companion for `ooRexx Hugging Face Space Job v0.2`.

It adds three named Gradio API endpoints to an existing Space without making the Space an arbitrary remote shell:

- `job_cpu` — no GPU decorator;
- `job_large` — ZeroGPU `large` (48 GiB default tier, quota factor 1);
- `job_xlarge` — ZeroGPU `xlarge` (96 GiB tier, quota factor 2).

All three expose the same logical named parameters (current Gradio can accept them directly through the named v2 call; older Gradio runtimes advertise the same names through `/gradio_api/info` and may use positional v1 submission):

- `request` — operation-specific JSON values;
- `input_bundle` — one uploaded Gradio file; package multiple logical inputs into the bundle;
- `_job` — authoritative managed-job control envelope from the ooRexx runner.

They return two outputs:

1. JSON result/cleanup evidence;
2. a single downloadable result ZIP (`gr.File`).

The common endpoint shape is deliberate: the ooRexx provider layer stays generic while operation implementations remain allowlisted on the Space.

## Good-citizen properties

- unknown `operation_id` fails closed;
- `cleanup_remote=true` is mandatory;
- endpoint tier and declared tier must agree;
- CPU operations cannot run through a ZeroGPU endpoint;
- all managed endpoints share `concurrency_limit=1`;
- uploaded bundle size/member/expansion limits are checked before execution;
- ZIP path traversal and symlink members are rejected;
- arbitrary client command strings, script paths and environment variables are never executed;
- child processes use `stdin=DEVNULL`, a bounded timeout, a minimal environment and no caller `HF_TOKEN` inheritance;
- workspace deletion happens in `finally` and `cleanup=DONE` is emitted only after deletion;
- result files live in a separate bounded/TTL cache and are garbage-collected on later jobs;
- stdout, stderr, output files, input digest and a machine-readable result manifest are returned in one result bundle.

## Credential separation

The caller's Hugging Face bearer token authenticates the Gradio call and accounts ZeroGPU quota. It is **not** injected into the workload subprocess.

If an installed workload needs Hub access to a gated model, configure a distinct Space secret named `HF_MODEL_READ_TOKEN`. Only an operation that explicitly requests it receives that value, mapped to `HF_TOKEN` inside its child process. This lets the Space use a read-only model token without giving training code the caller's repository-write token.

## Install into `rexxapiai/rexxapi`

Copy these files into the Space repository (or another package directory on its Python path):

```text
managed_compute_core.py
managed_space_endpoints.py
managed_smoke.py
```

Then, while building the existing `gr.Blocks` application:

```python
from managed_space_endpoints import attach_managed_endpoints

with gr.Blocks() as demo:
    # existing rexxapi UI
    ...
    attach_managed_endpoints()

demo.queue().launch()
```

Do not create a second independent Gradio application. The endpoints should be attached to the Space's existing Blocks graph.

For ZeroGPU hosting, ensure the Space has the Hugging Face `spaces` module available. `managed_space_endpoints.py` intentionally fails to import on a live deployment if that module is absent; the no-op decorator is available only under explicit test mode.

## Operations

Two operations are registered by default:

### `MANAGED_SMOKE_V1`

CPU-only. Runs the included fixed `managed_smoke.py`, hashes the input bundle and writes a small report. This is the recommended first **live** acceptance operation because it consumes no ZeroGPU quota.

### `GEMMA_OOREXX_RECOVERY_V1`

GPU-only (`large` or `xlarge`). It expects a fixed repository script named `train_gemma_oorexx.py` (override with `GEMMA_OOREXX_TRAIN_SCRIPT`). The endpoint constructs only these supported arguments:

```text
--input <uploaded bundle>
--base <validated model id>
--vocab-target <8192..262144>
--recovery-steps <1..5000>
--output <managed output directory>
```

If the training implementation is not installed, the operation returns `OPERATION_IMPLEMENTATION_MISSING`; it does not fall back to arbitrary execution.

## Qualification

`tests/run.sh` performs Python compilation, pure execution tests and a real Gradio API-graph test that verifies `/job_cpu`, `/job_large`, `/job_xlarge` and their named parameter schema. The companion ooRexx HF Space Job v0.2 defaults to `AUTO`, preferring named v2 and falling back to an introspected positional v1 request on older Gradio runtimes. A local Gradio 6.5.1 HTTPS integration completed that fallback path end-to-end. ZeroGPU is not consumed during qualification.


## v0.2-dev1 result receipt

A successful managed operation now returns `artifact_name`, `artifact_size`, and `artifact_sha256` in the authoritative JSON result alongside the Gradio FileData artifact. The receipt is calculated after the result ZIP is finalized and before the workspace cleanup receipt is returned. HF Space Job v0.3-dev1 verifies those values after download.
