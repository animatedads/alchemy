# Architecture

```text
ooRexx HFSpaceJobRunner
        |
        | HTTPS / Gradio logical named request
        v
existing rexxapiai/rexxapi Gradio Blocks
        |
        +-- job_cpu ---------------- ordinary CPU
        |
        +-- job_large -------------- @spaces.GPU(duration=dynamic)
        |
        `-- job_xlarge ------------- @spaces.GPU(duration=dynamic,size="xlarge")
                |
                v
       allowlisted operation registry
                |
                +-- MANAGED_SMOKE_V1
                `-- GEMMA_OOREXX_RECOVERY_V1
                         |
                         v
                 fixed local script
```

The endpoint layer owns execution containment, not placement. The ooRexx allocator decides which execution target/tier is eligible before this layer is called. Hugging Face owns the actual ZeroGPU queue and accelerator window around the decorated function.

## Dynamic duration

The ZeroGPU decorator duration is derived only from `_job.expected_gpu_seconds`, clamped to `1..REXXAPI_ZEROGPU_MAX_DECLARED_SECONDS` (default 1200). This makes the requested GPU window explicit and bounded. It does not convert CPU work into GPU work.

## Single-bundle protocol

Managed jobs use one input bundle and one result bundle. That keeps Gradio's fixed endpoint schema stable while permitting arbitrary workload-internal file sets. The client may still use multiple local files in other execution providers such as Colab; the Space deployment contract deliberately chooses a bundle as its transport unit.

## Result authority

The JSON result is authoritative for status and cleanup. The `gr.File` output is merely an artifact transport reference. Workspace cleanup happens before `cleanup=DONE`. The result ZIP survives in a separate bounded cache so Gradio can serve it after the execution workspace has been removed.

## Wire-version boundary

The Space-side operation schema is independent of Gradio queue wire version. `request`, `input_bundle` and `_job` are the authoritative logical parameters. HF Space Job v0.2 `AUTO` uses named v2 where available; after a v2 404/405 it reads `/gradio_api/info` and maps those exact names into the older positional v1 `data` array. The endpoint package itself therefore does not need separate v1/v2 operation implementations.


## Artifact receipt

The result cache artifact is hashed after final ZIP closure. Its basename, byte length and SHA-256 are emitted in the JSON control result. `gr.File` remains only the transport reference; the client must verify the bytes before treating the artifact as materialized.
