# Live acceptance checklist

## Hugging Face Space

Before any GPU call:

- token file is owner-only (`0600`);
- existing Space app imports and calls `attach_managed_endpoints()` inside its existing Blocks graph;
- `/gradio_api/info` exposes `job_cpu`, `job_large`, `job_xlarge` with logical parameters `request`, `input_bundle`, `_job`; the caller may use named v2 directly or AUTO-map those advertised names into older positional v1;
- `MANAGED_SMOKE_V1` completes through `job_cpu`;
- returned result reports `cleanup=DONE`;
- result ZIP contains `job-result.json`, logs and the smoke output;
- no ZeroGPU quota was consumed for CPU smoke.

For Gemma recovery, require the installed fixed `train_gemma_oorexx.py`; do not substitute arbitrary shell execution. Start on `job_large` unless the hard VRAM requirement exceeds 48 GiB.

## Colab

Before GPU acceptance:

- run CPU job first;
- confirm local files validate before allocation;
- confirm uploads, outputs and logs are captured;
- confirm remote workspace removal;
- confirm `colab stop` succeeds;
- confirm `colab sessions` shows no orphan.

Only request a GPU/TPU when the job's hard requirement explicitly requires one.
