# Storage Fabric CLI — virtual catalogue and Azure-safe retention

Status: **dev21-based CLI candidate 2**, not a released eight-MU grid deployment.
Original Storage Fabric authority, Git, peer, and namespace contracts remain the source of truth. This update adds a Python 3 operator frontend (`bin/storage`) with an ooRexx command endpoint (`bin/storage-cmd.rex`) and `StorageCommandService`.

## Start

```sh
export REXX_BIN=/path/to/rexx
export STORAGE_NODE_ID=ed209c
export STORAGE_STATE_ROOT=/var/lib/storage-fabric/authority
export PATH=/path/to/package/bin:$PATH

# Set SAFE only after a real persistent filesystem/failure domain is qualified:
export STORAGE_LOCAL_SAFETY=SAFE
export STORAGE_LOCAL_VENDOR=AZURE
export STORAGE_LOCAL_SITE=ED209C
```

The CLI appends the packaged `src` to `REXX_PATH` and uses a local `CLI.lock`. This is **not** distributed RTO2 leadership or epoch fencing. Production must bind the existing authority mechanism before allowing concurrent mutators on different nodes. Credentials are not accepted as command flags.

## Catalogue operations

```sh
# Register original video, choose its logical path and describe it:
storage add /data/videos/meeting.mp4 \
  --virtual /customers/initech/tps/meeting.mp4 \
  --namespace media \
  --description 'October TPS review meeting' \
  --tag tps --tag review \
  --meta customer=Initech --meta recorded=2026-10-13 \
  --format json

# Another logical path to the SAME StorageRef (no copying, no rehashing):
storage bind sha256:<64-character-digest> \
  --virtual /review/2026/meeting.mp4

# Add metadata to an existing registered object:
storage annotate /customers/initech/tps/meeting.mp4 \
  --description 'Approved review recording' --tag approved \
  --meta reviewer=qa --untag review --unset recorded

# Recursively add a directory, preserving relative names as virtual paths:
storage scan /data/videos --virtual-root /incoming/videos --tag raw

# Catalogue list/search (the retained checkpoint, not a live mesh probe):
storage list
storage list --namespace media --path /customers/initech
storage list --tag tps --meta customer=Initech --format json
storage list --query approved
storage list --node ed209c
storage list --provider azure-git
storage list --underreplicated
storage find initech --format json
storage locate /customers/initech/tps/meeting.mp4
storage status sha256:<64-character-digest> --format json

# Unpublish one virtual path. Never unlink the original video or Git copy:
storage remove /customers/initech/tps/meeting.mp4 --namespace media

# Also forget its catalogue StorageRef and policy, only if NO other
# virtual bindings reference it. This does NOT delete physical bytes:
storage remove /review/2026/meeting.mp4 --forget --yes
# Alternatively after unbinding all virtual paths:
storage remove sha256:<64-character-digest> --forget --yes
```

`add` and `scan --virtual-root` need a regular local file; symlinks are rejected. The file is fully hashed and recorded as `sha256:<digest>`. The SHA-256 identity deduplicates contents, whereas each namespace binding retains its own absolute virtual path. Content-level description, tags, and custom metadata are shared by every virtual binding of the same StorageRef. Virtual path conflicts are rejected (not overwritten). `scan` commits one file at a time; a later failure does not roll back earlier registered files. `register` and `scan` without `--virtual-root` remain backward compatible with the previous CLI.

`remove` only unbinds a virtual path. `--forget --yes` additionally removes the unbound catalogue object and replica requirement, after checking *all* namespaces for remaining bindings. Both intentionally leave on-disk and Azure Git data untouched; remote retention/deletion policy remains separately governed. No automatic deletion is inferred from an unbound or forgotten object.

## Movement/replication

```sh
export STORAGE_AZURE_GIT_REPO_URL='https://dev.azure.com/<org>/<project>/_git/<repo>'
export STORAGE_AZURE_GIT_BRANCH=storage-fabric
export STORAGE_AZURE_GIT_CHECKOUT=/var/lib/storage-fabric/git-checkout
export STORAGE_AZURE_GIT_SITE=AZURE-DEVOPS

storage ensure /customers/initech/tps/meeting.mp4 --replicas 2 --provider azure-git
storage materialise /customers/initech/tps/meeting.mp4 --to /data/restored/meeting.mp4
```

`ensure` delegates to the existing `StorageGitProvider`, which uses chunked content-addressed Git objects and post-push verification. It requires one qualified, verified, stable local durable source, then enforces two retained durable replicas in distinct failure domains. This does **not** add an untested different Azure backend or require Git LFS. `materialise` uses staged SHA-256 verification and a non-existing target path.

The ooRexx command service accepts an injected authenticated `StoragePeerClient`, so XTP/QueueRexx materialisation is part of the existing contract. The **standalone** CLI does not instantiate that grid peer runtime; `--from-peer` fails explicitly until it is bound by the estate controller. Do not substitute SSH-copy or plain UDP.

## Search and protocol

`list`, `locate`, and `find` include persistent catalogue metadata: display name, MIME type, StorageRef, virtual paths, description, tags, custom key/value fields, locations, and durable-replica assessment. `locate` accepts an exact StorageRef, an exact unique display filename, an exact recorded physical locator, or a virtual path; ambiguous references fail closed. `find` and `list --query` perform case-insensitive substring matching on name, identity, virtual paths, description, tags, metadata keys/values.

New peer operations `CATALOGUE_LIST` and `CATALOGUE_LOCATE` are available through the **existing** Storage Peer API `storage.fabric.peer/0.1`, with pagination (maximum 100 items per page), committed-revision checking, explicit peer allowlist, optional RTO2 authority guard and no physical filesystem locators in replies. A peer responder may call `StoragePeerService~configureCatalogue(readOnlyStorageCommandService, allowedPeers, meshAuthority)` and clients call `StoragePeerClient~catalogueList(...)` / `~catalogueLocate(...)`. See `MESH_DISCOVERY.md`.

These operations have passed **in-process authenticated peer protocol tests** and are ready for the existing QueueRexx service binding. They are not proof of live all-node lookup. Without a configured authenticated grid service, the CLI's `list`/`locate` remain the locally retained catalogue view. A stale recorded `AVAILABLE` is not a live HAVE/STAT result.

## Qualification

See `QUALIFICATION_CLI_CANDIDATE2.txt`. Qualification used the uploaded ooRexx 5.3.0 r13196 debug `.deb` extracted into an isolated test runtime, the full existing dev21 `tests/run.sh` suite, seven native CLI end-to-end tests, seven parser/mock tests, and the new paginated peer catalogue native test. No Azure DevOps live credentials or ed209 cross-node route were available to run live tests.

## Candidate3 deployment hardening

`StoragePeerService~handle()` now **rejects** catalogue operations without an authenticated transport entry; use `handleFrom(authenticatedPeerNode, request)` and enforce the explicit peer ACL. The in-process test transport models this binding but is not itself network authentication. The CLI prepends both `src/` and the package root to `REXX_PATH` so inherited `::requires "src/StorageFabric.cls"` resolves from any working directory. See `docs/ED209_CODEX_STORAGE_CATALOGUE.md` and the isolated `deploy/ed209_catalogue_smoke.sh` test. Live eight-MU catalogue fanout is still future integration work.
