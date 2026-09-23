# ooRexx Managed Compute Increment — 2026-09-01 v2

Shared integration handoff for managed external compute.

## Included

- `oorexx_api_client_v0.3.zip` — native ooRexx HTTPS/HTTP/SSE transport and API egress/session authority.
- `oorexx_colab_job_v0.1.zip` — ephemeral Colab lifecycle: validate -> allocate -> stage -> install -> execute -> retrieve/log -> clean -> stop.
- `oorexx_huggingface_space_job_v0.2.zip` — persistent Space invocation, ZeroGPU quota policy, Gradio AUTO named-v2/introspected-v1 submission, SSE and result FileData retrieval.
- `huggingface_space_managed_endpoint_v0.1.zip` — Space-side allowlisted CPU/ZeroGPU endpoints for an existing Gradio Blocks app.
- `job_node_allocator_v0.3.zip` — exact allocator dependency used for this qualification snapshot.
- `oorexx_foreign_runtime_v0.22.5.zip`
- `oorexx_crypto_v0.8.3.zip`

## Boundaries

```text
                 provider-neutral workload
                         |
                  hard requirements
                         v
                Job-to-Node Allocator
                  /               \
                 /                 \
       Colab Job v0.1          HF Space Job v0.2
         |                         |
   google-colab-cli          API Client v0.3
         |                         |
 ephemeral Colab VM         Gradio Space API
                                   |
                         Managed Endpoint v0.1
                                   |
                      allowlisted installed script
```

Colab and Hugging Face are separate execution personalities. Neither provider owns generic placement authority. API Client retains outbound egress/session authority and is not absorbed into the allocator.

## Resource citizenship

- CPU jobs never acquire a GPU merely because it might be faster.
- Colab GPU/TPU models are explicit hard requirements.
- HF ZeroGPU uses CPU / large / xlarge endpoint tiers; xlarge consumes 2x quota cost in the client budget. Gradio wire compatibility is negotiated without changing the logical endpoint authority.
- HF paid-credit spillover requires explicit site and per-job opt-in.
- Space managed endpoints share concurrency limit 1 and require cleanup evidence.
- Colab cleanup defaults to remote workspace removal + `colab stop`.
- caller repository-write tokens are not propagated into Space workload subprocesses.

## First live acceptance sequence

1. **HF CPU smoke:** deploy the managed endpoint overlay and run `MANAGED_SMOKE_V1` through `job_cpu`. This proves authenticated API Client -> Gradio -> result-bundle retrieval while consuming no ZeroGPU quota.
2. **Colab CPU smoke:** run the existing Colab fixture on a CPU runtime and verify `colab sessions` has no orphan afterwards.
3. **HF GPU acceptance:** only after `train_gemma_oorexx.py` is installed in the Space, run `GEMMA_OOREXX_RECOVERY_V1` on `job_large` with the small 100-step/64K recovery workload.
4. **Colab GPU acceptance:** run the same provider-neutral workload contract through the Colab provider using the explicitly required accelerator model.

The order intentionally proves cleanup and artifact/evidence paths before spending scarce accelerator quota.

## Not performed during qualification

No live Hugging Face repository mutation, live Space invocation, ZeroGPU use, Colab allocation, Git push or token use was performed while sealing this increment. Provider-facing tests use local/fake endpoints and local command substitutes. In addition, the actual managed endpoint package was hosted under local Gradio 6.5.1 over HTTPS and driven end-to-end by the ooRexx HF runner; this used no external compute or real credential.
