# ooRexx Managed Compute Increment — 2026-09-01

This is an integration handoff, not a new monolithic runtime. Each package remains independently versioned and authoritative for its own responsibility.

## Composition

- `oorexx_api_client_v0.3.zip` — route/session-aware native HTTPS transport over RxSock + Foreign Runtime/OpenSSL, HTTP/1.1 framing, chunked decoding, finite SSE, and synchronous `ApiClient~execute` using the normal route/session/WLU authority path. No curl dependency.
- `oorexx_colab_job_v0.1.zip` — generic ephemeral Colab managed-job lifecycle: validate, allocate, stage, install, execute, retrieve evidence/artifacts, clean remote workspace, release.
- `oorexx_huggingface_space_job_v0.1.zip` — persistent Gradio Space execution target using API Client for discovery, upload, named endpoint submission, SSE completion and same-host artifact retrieval. ZeroGPU is quota-limited endpoint capability, not a dedicated VM assigned by this runner.
- `job_node_allocator_v0.3.zip` — shared hard-eligibility placement seam used by both managed-compute targets in this qualification baseline.
- `oorexx_foreign_runtime_v0.22.5.zip` — native FFI dependency for API Client HTTPS.
- `oorexx_crypto_v0.8.3.zip` — allocator dependency in this baseline.

## Authority boundaries

The general allocator establishes hard execution-target eligibility. API Client remains authoritative for outbound route/egress session selection. Provider runners own their provider-specific lifecycle, file citizenship, evidence and cleanup. Workloads remain provider-neutral.

The Hugging Face runner does not expose an arbitrary remote shell. It requires an explicit `operation_id`; the Space side must allowlist installed operations. Possession of a Hugging Face write-capable token does not grant repository deployment or Space hardware-control authority to a compute job.

ZeroGPU paid-credit spillover is fail-closed by default and requires both site policy and per-job opt-in. The local quota budget does not invent its own daily reset; authoritative/observed quota must refresh it.

## Qualification

Qualified under the user-supplied ooRexx 5.3.0 r13196 Internal Test Version. The Hugging Face end-to-end qualification used a local TLS Gradio fixture and consumed no live Hugging Face Space/ZeroGPU resources. Colab v0.1 also used a fake CLI for lifecycle qualification and consumed no live Colab resource.

This roll-up is deliberately a convergence package. It does not supersede newer independently developed allocator, Crypto, Foreign Runtime, Colab, Hugging Face, or API Client versions if supplied later.
