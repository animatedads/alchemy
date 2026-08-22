# Direct Git submissions to Alchemy Autobuild

Use the repository's canonical sender whenever a local Git checkout is available.
Do **not** hand-upload package files one by one, base64-split archives, create a pull
request, or merge a submission branch into `main`.

## Canonical AI command

From any local clone of `animatedads/alchemy`:

```sh
python3 tools/alchemy_submit.py \
  --repo . \
  --package /path/to/finished/package \
  --submitted-by CHATGPT \
  --json
```

Replace `CHATGPT` with the actual producer identity (`CLAUDE`, `GEMINI`, etc.).
The package directory must contain `integration.json` at its root.

For a preview that performs no fetch, commit, branch creation or push:

```sh
python3 tools/alchemy_submit.py --repo . --package /path/to/package \
  --submitted-by CHATGPT --dry-run --json
```

## What the sender guarantees

The sender:

1. validates the root `integration.json` enough to reject an obviously malformed
   package before transport;
2. fetches exactly `refs/heads/main` into `refs/remotes/origin/main`;
3. creates a temporary detached worktree from that remote-tracking base, leaving
   the AI's development checkout untouched;
4. creates a globally unique `autobuild-submit/<submission-id>` branch;
5. copies the complete package to
   `autobuild/inbox/<submission-id>/package/`;
6. commits the complete package body in **one commit**;
7. creates and commits `ready.json` in a **second commit**;
8. pushes the branch **once**, transferring both commits and all package Git
   objects in one pack; and
9. removes its temporary worktree and local helper branch.

Binary files are ordinary Git objects. They must not be encoded into text chunks
for this transport.

The two-commit / one-push design preserves the important rule that `ready.json` is
logically last, while avoiding hundreds of per-file network operations.

## Submission shape

The resulting remote branch contains:

```text
autobuild/inbox/<submission-id>/
├── package/
│   ├── integration.json
│   └── ... complete package source ...
└── ready.json
```

Example ready marker:

```json
{
  "schema": "alchemy.autobuild.git-submission/0.1",
  "submission_id": "20260822T070000Z-CHATGPT-my-component-acde12",
  "submitted_by": "CHATGPT",
  "package_path": "package"
}
```

Once the ready commit exists, the submission is immutable. Corrections use a new
submission id and therefore a new branch.

## Receiver semantics

The branch-capable receiver treats remote branches as transport envelopes. It
fetches remote refs, looks for newly-added `autobuild/inbox/<id>/ready.json`
markers, and reads the package tree from the exact branch commit using Git object
operations.

It does **not** checkout, merge, or rebase a submission branch into `main`. A
submission branch may be far behind `main`; only the submitted package subtree is
materialized and tested.

Accepted state, results and receipts belong on `main`:

```text
autobuild/receipts/<submission-id>.json
autobuild/results/<run-id>/result.json
autobuild/results/<run-id>/logs/...
autobuild/artifacts/<package>/<version>/<sha256>.zip
packages/<accepted-package>/...
```

The receipt is the idempotency marker. A receipt suppresses future execution of
that submission id regardless of PASS, FAIL or ERROR.

## `integration.json`

Use the current Alchemy integration contract. ooRexx-heavy tests should declare
their environment at the individual test level when search paths differ, including
`REXX_PATH` and required package-root exports. Do not rely on a login-shell
environment to select dependency versions.

## Fallback when the sender cannot be executed

Only when an execution-capable Git checkout is genuinely unavailable may an AI
construct the same branch protocol through a Git provider API. The same invariants
still apply: package tree first, ready marker in the final commit, immutable after
ready, globally unique submission id, and no merge to `main`.

Provider-API fallback is not the normal path. Prefer `tools/alchemy_submit.py`.
