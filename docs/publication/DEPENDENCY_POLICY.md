# Publication and dependency policy

This repository publishes project-owned source, tests, documentation, schemas, fixtures and examples as ordinary Git files.

## Dependency boundary

A component's `deps/`, `vendor/`, `third_party/`, `third-party/` or `externals/` payload is **not** copied into that component's source tree during publication. Those directories are distribution conveniences, not ownership claims. The publication process replaces each such payload with a small `README.md` that records what was omitted and its SHA-256 provenance.

The same rule follows the bytes, not merely the directory name. If an archive also contains a byte-identical copy of a dependency file elsewhere in the component tree — for example a vendored `StorageFabric.cls` copied again into `src/` — that duplicate is omitted as dependency source too and recorded in the provenance note. Moving or duplicating a dependency cannot turn another project's source into project-owned source.

Dependencies should instead be obtained from their own first-class component tree, upstream project, or package source identified by the component documentation. This prevents stale duplicate source, ambiguous licensing, accidental divergence, and cross-project ownership confusion.

## What is published

- reusable ooRexx libraries, runtimes, services and tools under `packages/`;
- complete application and integration examples under `examples/`;
- LLM Gopher knowledge/documentation spheres under `spheres/`;
- repository and publication documentation under `docs/`.

Runtime queue state, machine-local caches, secrets and generated working directories are not source and must not be committed as source.
