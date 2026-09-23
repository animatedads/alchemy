# Governed command set

`bin/pa-tool` and the PA daemon share named operations.  They do not accept a
caller-supplied shell command.

The package operations are:

```text
pa-tool package stage PACKAGE.zip
llmpa package stage PACKAGE.zip
pa-tool package release WORKING_TREE
llmpa package release WORKING_TREE
```

The operation performs a content hash, approved-root preflight, free-byte and
inode checks, ZIP member traversal checks, immutable generation creation,
manifest verification, JSON metadata validation, and a durable JSON receipt.
Failed generations and receipts are retained.  There is no cleanup or
promotion operation in this ability.

`STAGED_READY` means the package passed this staging contract.  It does not
mean deployed, installed, or live.  Local dependencies are checked against
the PA's declared runtime path and external dependencies are recorded as
explicitly unprobed; provider-specific live checks and promotion remain
separate named abilities.

The receipt schema is `llm.pa.package.stage/0.1` and includes `stage_id`,
package SHA-256, generation, status, preflight measurements, metadata and
qualification evidence.  The PA route and direct CLI call the same
`LlmPaPackageStage` service.

## Package release

`package release` is the inverse of staging.  It reads an approved working tree
without modifying it, builds a fresh immutable snapshot, excludes runtime/build
detritus by policy, writes a new `MANIFEST.sha256`, verifies the snapshot,
creates and tests a ZIP artifact, and writes an external durable release
receipt.

The default hygiene policy excludes source-control metadata, `runtime/`,
`tests/live-gemma-store-*`, `LEDGERPATH`, Python `__pycache__`, `*.pyc`,
`*.pyo`, compiled `*.class`/object files, editor swap/backup files, logs, PID/
socket files, coverage caches and similar transient output.  These are excluded
from the release snapshot; the source working tree is never deleted or cleaned
in place.  The source `MANIFEST.sha256` is ignored and regenerated from the
actual released bytes.

Release source paths are constrained by `LLMPA_RELEASE_SOURCE_ROOT`.  The PA
daemon defaults this authority root to its package root.  The direct `pa-tool`
client defaults it to the caller's current directory.  A caller cannot use the
release ability as a general filesystem archiver.

The receipt schema is `llm.pa.package.release/0.1`; `RELEASE_READY` means the
immutable generation, manifest and ZIP were structurally qualified and
verified.  Deployment remains a separate operation.
