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

## September 2026 estate baseline

For the September 15, 2026 publication, place the supplied archives in one directory and run this audit first:

```sh
./bin/alchemy-publish estate \
  --api-archive 'oorexxapis(20260915-080909).zip' \
  --sphere-archive 'sphere(20260915-080907).zip' \
  --overlay 'queuerexx_v0.1-dev12(2)(5).zip' \
  --overlay 'job_node_allocator_v0.6-network1(4).zip' \
  --overlay 'oorexx_storage_evacuation_v0.1-dev2(1).zip' \
  --overlay 'fd_door_micro_motion_v0.2-dev5(1).zip' \
  --overlay 'oorexx_llm_pa_v0.1-dev9-candidate1(1).zip' \
  --json
```

The known-good dry-run summary for those exact inputs is:

```text
components:                 195
files_published:            8131
bytes_published:            56460838
dependency_roots_omitted:   12
files_omitted:              688
```

Treat a different result as a review point, not as permission to continue automatically. In particular, the publisher must detect copied dependency bytes outside their original dependency folder; current examples include Storage Evacuation's copied `StorageFabric.cls` and Virtual Browser's copied `ApiClient.cls`.

After that audit matches, publish the estate to a fresh review branch:

```sh
./bin/alchemy-publish estate \
  --repo . \
  --branch 'publication/2026-09-15-oorexx-estate-final' \
  --api-archive 'oorexxapis(20260915-080909).zip' \
  --sphere-archive 'sphere(20260915-080907).zip' \
  --overlay 'queuerexx_v0.1-dev12(2)(5).zip' \
  --overlay 'job_node_allocator_v0.6-network1(4).zip' \
  --overlay 'oorexx_storage_evacuation_v0.1-dev2(1).zip' \
  --overlay 'fd_door_micro_motion_v0.2-dev5(1).zip' \
  --overlay 'oorexx_llm_pa_v0.1-dev9-candidate1(1).zip' \
  --push --json
```

The `-final` suffix is intentional: earlier publication transport experiments used the unsuffixed branch name, and the final publication must not depend on or overwrite those abandoned transport branches.

For the companion BashQueues delivery, the corresponding audit is:

```sh
/path/to/alchemy/bin/alchemy-publish bashqueues \
  --archive 'bashqueues_0.18.144_BOB27_lock_tree_ownership_hotfix_full_delivery(2).zip' \
  --version-label 0.18.144 \
  --json
```

The known-good BashQueues result is **2619 published source files** and **1355 omitted runtime-state files**. Publish it only after that audit is understood:

```sh
/path/to/alchemy/bin/alchemy-publish bashqueues \
  --repo /path/to/bashqueues \
  --branch 'publication/2026-09-15-bashqueues-0.18.144' \
  --archive 'bashqueues_0.18.144_BOB27_lock_tree_ownership_hotfix_full_delivery(2).zip' \
  --version-label 0.18.144 \
  --push --json
```

The command publishes branches; promotion to `main` remains a separate review/merge decision.

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
