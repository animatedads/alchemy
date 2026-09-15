# workspace-gpt sphere v0.1

Requires LLM Gopher v0.18-dev1 or later, because the bounded workspace capabilities live in the common engine/core pack.

Purpose: operational memory for ephemeral coding workspaces: byte/inode headroom, materialisation readiness, ZIP expansion preflight, handover framing, and context recoverability.

Start:

    ./gopher --profile workspace-gpt context workspace-gpt --full
    ./gopher --profile workspace-gpt workspace inspect
    ./gopher --profile workspace-gpt workspace preflight-zip input.zip --workspace-limit-bytes 62914560
