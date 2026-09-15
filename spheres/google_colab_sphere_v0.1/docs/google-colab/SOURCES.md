# Sources and evidence boundary

Observed as of: 2026-09-02

## Public references

1. Google Colab CLI upstream repository and README
   https://github.com/googlecolab/google-colab-cli

   Current upstream documents named sessions, `colab new`, `exec`, `upload`, `download`, `stop`, GPU selectors, and (on current main) `--high-mem`.

2. Google Colab CLI operator skill
   https://github.com/googlecolab/google-colab-cli/blob/main/skills/colab-operator/SKILL.md

   Current operator workflow recommends explicit session names and documents provisioning/execution behavior.

3. google-colab-cli on PyPI
   https://pypi.org/project/google-colab-cli/

   Version 0.6.0 was released 2026-06-16. Public package metadata is release evidence, not proof that upstream main has the same command surface.

4. Google Colab local runtime security notes
   https://research.google.com/colaboratory/local-runtimes.html

   Used only for the general principle that code running through a Colab frontend/runtime has the authority of that runtime and must be trusted accordingly.

## Qualified project incidents

The following are exact observations from the Gemma-ooRexx managed-compute work on 2026-09-01/02 and are not claimed as universal Colab guarantees:

- `google-colab-cli==0.6.0` initially failed because `jupyter_kernel_client.KernelClient` was absent; installing `jupyter-kernel-client==0.9.0` in the exact uv tool environment restored the required API.
- The qualified 0.6.0 `colab exec` rejected `--env`.
- The qualified 0.6.0 `colab new -h` did not expose `--high-mem`; the adapter omitted the unsupported flag and preserved the host-memory requirement for worker-side verification.
- A T4 allocation exposed 14,912 MiB CUDA memory and a 12,975 MiB host. Worker gates were calibrated to observed usable resources rather than nominal marketing numbers.
- `Connection was lost` during dependency installation proved recoverable with narrow same-session retry; deterministic package errors remain fail-fast.
- A 480,178,064-byte regrade archive failed during upload. A locally verified 77,062,608-byte compact payload succeeded. This does not establish a universal upload-size limit.
- Secret values were staged separately and evidence logged only the secret reference plus `<REDACTED>` retirement.
- Completed model training and successful infrastructure did not imply promotion: r13196 compile grading remained an independent decision gate.

## Interpretation rule

Where public upstream documentation and a pinned installed CLI disagree, the installed binary/help output is authoritative for execution. Record the discrepancy and adapt by capability detection rather than pretending one side never existed.
