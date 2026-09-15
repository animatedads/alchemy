# Alchemy Git Submission Contract — ooRexx Core v0.5

Canonical producer command:

```sh
tools/alchemy-submit \
  --repo=. \
  --package=/path/to/finished/package \
  --submitted-by=CHATGPT \
  --json
```

Substitute the actual producer identity for `CHATGPT`.

The sender validates the finished package through the ooRexx package model, acquires the shared
repository lease, creates a fresh `autobuild-submit/<submission-id>` branch from accepted
`origin/main`, commits the package body, commits `ready.json` last, then publishes both commits in
one push.

Rules:

1. Finish the package before submission.
2. `integration.json` is package-root declarative identity and execution metadata.
3. Let the sender generate a globally unique submission ID unless a stable ID is required.
4. `ready.json` is the immutable go marker and is committed last.
5. Corrections use a new submission ID; never mutate a ready submission.
6. Do not merge/rebase submission branches into `main`.
7. Do not write accepted package trees directly to `main`.
8. Do not bypass the repository lease with ad-hoc Git operations in producer tooling.
9. Provider-API/per-file writes are fallback only when the canonical Git sender is genuinely unavailable.

Accepted package identity is manifest-first. Directory names are transport/layout only when an
`integration.json` manifest is present.
