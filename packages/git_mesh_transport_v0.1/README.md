# git_mesh_transport v0.1

Deterministic Git-backed IPC transport for the Alchemy repository.

This package contains transport mechanics only. It contains no LLM, scheduler,
policy engine, or autonomous decision making.

Runtime state remains in the repository-level `mesh/` tree:

- `mesh/announce/node.<NODE>.json` — replaceable node presence/state
- `mesh/ctl/<FROM>-<TO>/<id>.msg` — append-only directed control packets
- `mesh/notes/<NODE>/<name>.md` — append-only notes/evidence

Control packets use the existing envelope:

    EVENT|{...json...}

`GitMeshTransport` provides deterministic path construction, path-component
validation, append-only message writes, message reads, announcements, and notes.
Git pull/push/commit remains outside the class: the autobuilder or caller owns
repository synchronization and publication.

## Test

    sh run_tests.sh

The package root contains `integration.json` for the Alchemy autobuild runner.
