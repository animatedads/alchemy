# Local knowledge catalogue

`v0.1-dev7` separates three kinds of context:

1. **Durable PA memory** — facts Codex explicitly told Gemma with `remember`.
2. **Local knowledge** — operator-approved procedure/documentation files describing this installation.
3. **Live state** — information obtained only from authorised live tools; neither memory nor documentation implies live state.

The production daemon reads local knowledge only from `LLMPA_KNOWLEDGE_ROOT`. If unset, this defaults to:

    $LLMPA_STORE_ROOT/knowledge.d

Only direct `.md`, `.txt`, and `.help` files are searched. The PA does not receive an arbitrary path-reading function.

Example deployment pattern (the content must be verified locally; these are placeholders, not claimed syntax):

    mkdir -p "$LLMPA_STORE_ROOT/knowledge.d"
    cp /approved/docs/sshnode.md "$LLMPA_STORE_ROOT/knowledge.d/sshnode.md"
    cp /approved/docs/gcloud-pa.md "$LLMPA_STORE_ROOT/knowledge.d/gcloud-pa.md"

Codex can inspect catalogue matches without asking the model:

    rexx bin/llmpa.rex '-knowledge "sshnode"'
    rexx bin/llmpa.rex '-next'

A normal `-ask` searches both durable memory and the read-only local catalogue. Gemma receives source provenance and is instructed not to invent command syntax, roles, paths, capabilities, or live status beyond the supplied material.

Lookup keys created during `remember` remain retrieval metadata. They are visible in the remember acknowledgement but are no longer inserted into ordinary Gemma answer prompts.
