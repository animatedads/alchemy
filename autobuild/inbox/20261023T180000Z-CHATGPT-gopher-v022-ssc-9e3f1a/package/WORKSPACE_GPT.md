# workspace-gpt

This sphere exists because ephemeral coding workspaces fail in boring, predictable ways.

Use:

    ./gopher --profile workspace-gpt workspace inspect
    ./gopher --profile workspace-gpt workspace materialize-check --path /mnt/data/input.zip --expected-bytes 31457280
    ./gopher --profile workspace-gpt workspace preflight-zip /mnt/data/input.zip --destination /mnt/data
    ./gopher --profile workspace-gpt workspace recoverability

The ZIP preflight never extracts the archive. It uses the central directory to calculate the total uncompressed footprint and member count, then compares those with free bytes/inodes and a safety reserve. A compressed archive fitting on disk does not imply that extraction fits.

`HANDOVER_ADVISED` means stop the planned file-heavy operation in this workspace and preserve continuity before moving to a larger/fresh session.


## Session quotas

Physical `df` output is not always the real LLM-session limit. Set either:

    LLM_GOPHER_WORKSPACE_LIMIT_BYTES
    LLM_GOPHER_WORKSPACE_LIMIT_INODES

or pass `--workspace-limit-bytes` / `--workspace-limit-inodes` to ZIP preflight.

The effective free space is the smaller of physical filesystem headroom and the declared session quota remaining after current workspace usage.


## Handover frame

`workspace handover-frame` is read-only. It gathers the current environment, active sphere provenance and an optional materialised artifact SHA-256, then lists the continuity fields still missing. It does not save, transmit, or invent an unavailable artifact path.
