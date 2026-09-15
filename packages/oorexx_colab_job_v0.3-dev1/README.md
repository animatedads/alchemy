# ooRexx Colab Job v0.3-dev1

Generic managed-job wrapper around `google-colab-cli`. Colab is an ephemeral execution target, not an AI-provider abstraction and not workload-specific logic.

Lifecycle: validate locally -> resolve required secret references -> allocate least-required resource -> prepare isolated workspace -> privately stage secret material -> stage ordinary files -> install declared dependencies -> execute generated driver -> retrieve declared outputs and Colab history -> redact locally owned evidence -> clean secret/workspace state -> stop/release session.

Resource citizenship is fail-closed: CPU/GPU/TPU is a hard requirement. A CPU job emits no accelerator request. GPU/TPU jobs must explicitly name the required accelerator; ranking happens only after eligibility. Local input and credential-reference validation happens before any VM allocation. The default is teardown; retaining a session requires an explicit `retainSession=.true` job spec, and secret storage is still removed even from a retained session.

Main classes: `ColabJobRequirement`, `ColabInputFile`, `ColabOutputFile`, `ColabSecretBinding`, `ColabJobSpec`, `ColabCliAdapter`, `ColabJobRunner`, `ColabJobEvidence`, `ColabArtifactReceipt`, `ColabJobResult`, `ColabAllocatorAdapter`.

## v0.3-dev1 result citizenship

The provider object now owns result integrity as part of the managed lifecycle. Declared remote input/output names must be safe relative paths; absolute paths, backslashes, empty components and `.`/`..` traversal are rejected before allocation.

After the workload completes, the generated Colab driver computes SHA-256 and byte length for every declared output that exists and writes a controller-only result receipt. The runner downloads that receipt first, downloads each declared output, recomputes SHA-256 locally with ooRexx Crypto, verifies byte length, and only then exposes a `ColabArtifactReceipt` in `ColabJobResult~artifacts`. A required output without a receipt, or any size/hash mismatch, fails the job before `COMPLETED`.

This deliberately stops at verified controller-owned materialization. Promotion into Storage Fabric is an upper-layer durability decision and does not give Colab Job storage-policy authority. ooRexx Crypto v0.8.3 is therefore a runtime dependency for v0.3-dev1.

## Secret Broker seam

v0.2 adds a reference-only secret contract for values such as `HF_TOKEN`. The job spec carries only an opaque reference, for example:

```text
ColabSecretBinding("HF_TOKEN", "huggingface.primary")
```

`ColabJobRunner` must be constructed with a Secret Broker for any secret-bound job. It acquires a short-lived lease, privately materialises the value into 0700/0600 local storage, uploads to an ordinal file under a 0700 remote secret directory, and the generated driver loads the value into `os.environ` before immediately unlinking the remote file. The resolved secret is never placed in the job spec, CLI argv, generated driver source, or Colab Job evidence. See `SECRET_REFERENCE_CONTRACT.md`.

Obvious credential environment names are rejected if supplied through the ordinary `environment` Directory. Non-secret environment variables such as `HF_HOME` still use the CLI environment surface.

Secret Broker v0.2 is an optional runtime dependency for ordinary Colab jobs and a mandatory dependency when `secretBindings` is non-empty. Colab Job uses the broker's public `acquire(reference)` / `SecretLease~secretForTrustedConsumer` / `retire` contract rather than defining its own secret store.

## Colab CLI assumptions

This version targets the September 2026 `googlecolab/google-colab-cli` surfaces `new`, `upload`, `download`, `install`, `exec`, `log`, `rm`, `status`, and `stop`. Current CLI `--env` support is intentionally used only for non-secret environment values because the CLI builds environment values into executed Python source and records executed source/output in its history.

Authentication remains owned by the Colab CLI/account session. The wrapper never manipulates OAuth tokens/browser cookies, calls `pay`, changes subscription state, or probes accelerators merely to see what is available.

## Allocator compatibility

The allocator adapter is qualified against Job-to-Node Allocator v0.6. It maps `COLAB_EXECUTION`, `GPU`/`TPU`, exact accelerator tags, memory and disk into hard eligibility requirements. It deliberately does not score or choose accelerators.

## Qualification

The packaged suite uses a fake command executor, so qualification consumes no live Colab compute. v0.2 retains the original lifecycle/resource and allocator regressions and adds Secret Broker tests proving:

- literal `HF_TOKEN` is rejected before allocation;
- a reference-bound job requires Secret Broker;
- an unavailable reference burns no Colab VM time;
- local secret materialisation is `0700` directory + `0600` file;
- resolved secret value is absent from CLI argv and generated driver source;
- the opaque secret reference is not transmitted to the driver;
- execution results, evidence and exported log are redacted;
- broker leases retire on success/failure;
- retained sessions still trigger remote secret-directory cleanup.
