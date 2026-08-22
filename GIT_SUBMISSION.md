# Direct Git submissions to Alchemy Autobuild

Alchemy Autobuild v0.3 supports a durable Git inbox in addition to browser-downloaded managed ZIPs.

An AI that can write to `animatedads/alchemy` may submit a package without asking the human to download a ZIP.

## Submission layout

Choose a globally unique submission id. A UTC timestamp plus producer and short task name is recommended.

```text
autobuild/inbox/20260822T061500Z-CHATGPT-my-component/
├── package/
│   ├── integration.json
│   ├── run_tests.sh
│   └── ... package source ...
└── ready.json
```

`package/` is the package root. Its `integration.json` uses the same `alchemy.autobuild.integration/0.1` or `/0.2` contract as a managed ZIP.

## Critical ordering rule

Write **all files under `package/` first**. Commit them to GitHub. Create `ready.json` **last**.

The runner only scans immediate child directories of `autobuild/inbox/` for `ready.json`. It does not inspect the package tree until the ready marker exists.

Example `ready.json`:

```json
{
  "schema": "alchemy.autobuild.git-submission/0.1",
  "submission_id": "20260822T061500Z-CHATGPT-my-component",
  "submitted_by": "CHATGPT",
  "package_path": "package"
}
```

The `submission_id` must exactly match the directory name.

Once `ready.json` has been committed, the submission is immutable. Do not edit a ready submission. To correct or replace it, create a new submission id and a new folder.

## What the local runner does

The runner polls Git independently of the `~/Downloads` scanner. By default it pulls every 5 seconds.

A Git submission is pending when:

- `autobuild/inbox/<id>/ready.json` exists; and
- `autobuild/receipts/<id>.json` does not exist.

Unlike downloaded ZIPs, Git submissions are durable. The Downloads startup watermark does **not** apply. A ready submission committed while the local service is stopped is processed after the service starts again.

The runner snapshots `package/` into a deterministic ZIP, executes its declared tests in staging, and uses the normal publication rules. A passing `publish.tree` is promoted as ordinary Git source files. Failed tests do not promote source.

## Result and receipt

Every attempted ready submission gets a persistent receipt:

```text
autobuild/receipts/<submission-id>.json
```

The normal evidence is also written:

```text
autobuild/results/<run-id>/result.json
autobuild/results/<run-id>/logs/...
autobuild/artifacts/<package>/<version>/<sha256>.zip
mesh/ctl/AUTOBUILD-CHATGPT/<message>.msg
```

The receipt is the idempotency marker. Once it exists, the runner will not run that submission id again, regardless of PASS, FAIL, or ERROR.

## Minimal AI procedure

1. Read `MANAGED_ZIP.md` for the `integration.json` contract.
2. Choose a new unique submission id.
3. Create `autobuild/inbox/<id>/package/` and upload the complete package there.
4. Ensure `package/integration.json` declares tests and publication.
5. Commit `autobuild/inbox/<id>/ready.json` last.
6. Do not modify the folder again.
7. Read `autobuild/receipts/<id>.json` and its referenced result/logs for feedback.

This path needs no local AI and no human download step. Git is the durable queue; the local autobuilder is only the deterministic executor.
