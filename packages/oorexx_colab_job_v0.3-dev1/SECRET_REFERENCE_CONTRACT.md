# Secret-reference contract

Colab Job v0.2 adds a reference-only credential seam intended for values such as `HF_TOKEN`.

## Authority boundary

`ColabJobSpec` may contain `ColabSecretBinding(environmentName, reference)` objects. The `reference` is an opaque Secret Broker reference; the secret value is not a property of the job specification. `ColabJobRunner` accepts a broker object implementing `acquire(reference)` and refuses a secret-bound job before Colab allocation when that broker is absent or the reference cannot be acquired.

Secret Broker remains authoritative for reference resolution and lease lifetime. Colab Job does not define a second credential store.

## Materialisation path

For each binding the runner:

1. acquires a Secret Broker lease before VM allocation, so missing credentials do not consume Colab resources;
2. allocates/prepares the selected Colab session only after all references are available;
3. reads the secret through `SecretLease~secretForTrustedConsumer`;
4. materialises it into a job-specific local directory created mode `0700`, with the value file mode `0600`;
5. uploads that file to an ordinal path under `<remoteRoot>/.secrets/`, whose parent is created mode `0700`;
6. deletes the local materialisation immediately after the upload call returns;
7. runs generated Python which chmods the remote file `0600`, reads it into the requested process environment variable, immediately unlinks the file, and removes the secret directory when empty;
8. performs best-effort remote secret-directory removal during finalisation even when `retainSession=.true`;
9. redacts known secret values from Colab Job command results, evidence, and the locally exported Colab log before retiring the broker lease;
10. retires every acquired lease on every completion/failure path.

The remote path contains only an ordinal (`s1`, `s2`, ...). The Secret Broker reference itself is not transmitted to the Colab workload.

## Deliberate rejection of `--env` for secrets

Plain non-secret environment variables may continue to use the Colab CLI `--env` surface. Obvious credential names (`*_TOKEN`, `*_SECRET`, `*_PASSWORD`, `*_API_KEY`, `HF_TOKEN`, and `AWS_SECRET_ACCESS_KEY`) are rejected in `ColabJobSpec~environment` and must use `ColabSecretBinding`.

This is deliberate. Current google-colab-cli constructs `--env KEY=VALUE` values into the executed Python source and records executed source/output in its history. A secret value therefore must not be supplied through that flag.

## Evidence and limitations

Safe evidence may contain the environment variable name and opaque reference identity, for example:

`SECRET_ACQUIRE|OK|env=HF_TOKEN;reference=huggingface.primary;value=<REDACTED>`

It must not contain the resolved value.

Colab Job can redact its own result/evidence and the exported history file it retrieves. It cannot prevent a deliberately or accidentally secret-printing workload from first causing a third-party Colab CLI implementation to persist that output in its own internal history. Workloads must therefore treat credentials as non-display data. v0.2 does not claim hardware-backed secret storage, process-memory erasure, or control of Google/Colab server-side telemetry.
