# Publishing the Alchemy ooRexx estate

Alchemy publication is a repeatable repository command, not a one-off ZIP-copy exercise.

Use:

```sh
./bin/alchemy-publish estate \
  --api-archive /path/to/oorexxapis.zip \
  --sphere-archive /path/to/sphere.zip \
  --overlay /path/to/current-component.zip \
  --json
```

That command is an **audit/dry-run by default**. It unpacks the supplied distributions in a temporary staging area, determines the normal Git source tree, strips embedded dependency payloads, detects byte-identical dependency source copied elsewhere in a component, and emits a provenance report. It does not modify Git.

When the report is correct, publish a branch from a local checkout:

```sh
./bin/alchemy-publish estate \
  --repo . \
  --api-archive /path/to/oorexxapis.zip \
  --sphere-archive /path/to/sphere.zip \
  --overlay /path/to/queuerexx.zip \
  --overlay /path/to/job_node_allocator.zip \
  --overlay /path/to/storage_evacuation.zip \
  --apply --push --json
```

`--push` implies `--apply`. Publication is performed in a temporary Git worktree based on `origin/main`; the caller's checkout is never switched. The default remote branch is date-stamped under `publication/`. Use `--branch` to select another publication branch.

## Dependency boundary

Directories named `deps`, `vendor`, `third_party`, `third-party`, or `externals` are treated as distribution dependencies, not source owned by the containing project. Their contents are not published into that component tree. A generated README is left at the dependency directory and the omitted file hashes are retained in the publication manifest.

The command also hashes dependency files and rejects their non-empty byte-identical copies elsewhere in the same component. This catches distributions that place an upstream dependency under `vendor/` and then copy the same file into `src/`.

## BashQueues full deliveries

The same command publishes a BashQueues delivery while excluding queue/runtime state:

```sh
./bin/alchemy-publish bashqueues \
  --repo /path/to/bashqueues \
  --archive /path/to/bashqueues_full_delivery.zip \
  --version-label 0.18.144 \
  --apply --push --json
```

Known runtime roots such as `.queuebash`, `.qbroot`, pending/running/done/failed state buckets, logs, workers and the `testr` runtime mirror are omitted and recorded. The repository's public `README.md` is retained; a delivery README is preserved under `docs/history/` instead of replacing the public front door.

## Manifest

Every applied publication commits a JSON manifest under `publication/manifests/`. It contains source archive names, SHA-256 hashes, component destinations, published counts, dependency roots and every omitted file/reason. Local absolute source paths are deliberately not written to the public manifest.

## Safety properties

- dry-run unless `--apply` or `--push` is explicitly supplied;
- no checkout switching in the caller's worktree;
- exact source-archive SHA-256 provenance;
- ZIP path traversal and symlink entries fail closed;
- embedded dependency source is never silently adopted;
- runtime queue state is not BashQueues source;
- publication occurs on a branch rather than silently rewriting `main`.

Run the command tests with:

```sh
python3 tests/test_alchemy_publish.py -v
```
