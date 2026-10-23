# Codex: ed209 Storage Fabric virtual catalogue adoption (candidate 3)

**Deployment state:** source candidate qualified locally, **not deployed on ed209**. This is a follow-on to the already passed XTP carrier matrix: 30/30 native L3 IP-protocol-36 paths and 26/26 L4 XTP/UDP port 62801 paths. Those tests do **not** prove catalogue RPC binding, service routing, distributed search, or Storage Fabric durability on any ed209 host.

## Architectural contract

- Eight Management Units (ed209a/b/c/d/e/i/j/k), two MIs under each (16 total). Local MI to MU and MU to MI use XTP L2. Non-GCP MU to MU use XTP L3 native protocol 36. Any MU route involving ed209e or ed209j uses XTP L4 over UDP **62801**. Do not change these carriers to accommodate Storage Fabric.
- Content identities are `sha256:<digest>`. A virtual path is an alias, not a physical copy. Retained catalogue metadata is not live proof of a source; HAVE/STAT, digest-verified materialisation, and Storage failure-domain checks supply separate evidence.
- The CLI persists into one local StorageAuthority checkpoint root. `CLI.lock` protects only processes sharing the same filesystem; **it is not a distributed writer lease or RTO2 epoch fence**. Admit mutators only under the established authority/lease scheme.
- Remote `CATALOGUE_LIST`/`CATALOGUE_LOCATE` use the existing StoragePeer API (`storage.fabric.peer/0.1`) and an **authenticated** peer node supplied by the QueueRexx/XTP transport. Never create a new direct-UDP JSON or SSH-copy Storage RPC.
- A CATALOGUE request sent to `StoragePeerService~handle()` now returns `AUTHENTICATED_PEER_REQUIRED`. QueueRexx `StoragePeerQueueRexxServer~processOne` already calls `handleFrom(expectedPeerNodeId, request)`; keep that bound identity and an explicit catalogue peer allowlist.
- Discovery ACL authorizes **peer nodes**, not arbitrary tenant-scoped records. Do not expose an all-customer catalogue to a multi-tenant reader. Start with an isolated customer namespace/authority and a narrow reader allowlist until per-tenant authorization is designed and qualified.

## Codex execution stages

1. **Inventory** with existing `sshnode.sh` and existing cloud-control/local firewall tooling. Do not require extra host-key pin work after SSH access is operational; do not repeat approved firewall work. Check `uname -m`, `rexx -v`, disk and state paths. Record actual host identity and the installed Storage Fabric package hash. Avoid altering accepted installed services during preflight.
2. **Stage** this candidate into a versioned, non-active application directory on one MU (ed209c suggested for the Initech A01 pilot). Preserve installed files and service configuration; verify the zip SHA-256 and package manifests. Qualify from a *different working directory* to catch nested `::REQUIRES` path mistakes.
3. **Probe an actual video** with `deploy/ed209_catalogue_smoke.sh /absolute/path/to/video.webm`. This creates a disposable authority directory, registers/locates using the CLI, verifies the registered SHA-256 against actual bytes, and deletes only the disposable state. It never deletes the input video.
4. **Bind real authority, without shadow writes**. Mount the existing durable `StorageAuthorityStore` for the designated MU. Provision a separate read-only `StorageCommandService` to the same committed state root; call `StoragePeerService~configureCatalogue(reader, allowedPeerNodeIds, meshAuthority)`. Ensure `refresh()` reads committed state, never an in-flight mutation. Bind the service to existing authenticated `StoragePeerQueueRexxBinding~bindServer(...)`/`StoragePeerQueueRexxServer~processOne` routes. Do **not** launch the bundled TCP socket two-node demo as a substitute for the approved XTP carrier routing.
5. **Two-MU validation**. Issue CATALOGUE_LIST, CATALOGUE_LOCATE and pinned-revision second page from an admitted peer; then refuse an unauthorised peer, a falsely claimed `from_node`, an unbound direct `handle()` call, an invalid pagination window, and a changed checkpoint revision. Confirm no physical locators or credentials leave the peer protocol. Exercise source HAVE/STAT/materialisation separately: a recorded AVAILABLE is not a fresh reachability result.
6. **Expand to seven more MUs** through Job-to-Node/Migratable Job admission and existing ConnectSelector/QueueRexx service routes; keep Storage authority separate from placement authority. Report explicit coverage (`queried`, `unauthorised`, `unreachable`, `stale`, `unconfigured`) and origin/revision per MU; don't misrepresent local `storage list` as mesh-wide. `ed209a` is reachable after the reboot according to the supplied Codex evidence; re-verify rather than assume.
7. **Customer job**. Admit A01 technical check with pinned StorageRef and path; place one worker through allocator lease; permit verified materialisation under Storage Fabric authority and independent local memory staging. The job must return digest, execution MI, planner lease, input pin, output StorageRef, retained receipt, and durable result. Keep the A02 227-job manifest queued for separately qualified analysis runtime and resources.

## Basic isolated CLI invocation

```bash
export REXX_BIN=/path/to/rexx
# Set LD_LIBRARY_PATH only for an intentionally unpacked ooRexx runtime
cd /tmp
/opt/rexxos/storage-fabric-candidate3/bin/storage --state-root /tmp/one-mu-probe \
  --node ed209c list --format json
```

**Do not** set `STORAGE_LOCAL_SAFETY=SAFE` without verifying the backing filesystem, failure domain and durable recovery guarantees. With unknown safety, local objects are registered but are not automatically counted as verified durable replicas.

## Gate evidence for acceptance

- Native `tests/run.sh` returns pass under the deployed ooRexx 5.3.0 r13196 runtime; Python CLI 14 tests pass from unrelated CWD; `tests/test_storage_mesh_catalogue.rex` passes with authentication denial regression.
- One genuine Initech asset can be `add`ed, `locate`d, located after process restart, and given a real immutable `sha256:` content identity. Virtual unlink leaves original file bytes untouched.
- Authentication and customer isolation checked before any mesh-visible catalogue output. No silent direct handler or unauthenticated fallbacks.
- Remote read requires peer ACL and bounded pagination/revision; fanout must give per-node coverage and per-catalogue revision. Actual remote peer RPC acceptance is a **separate live test**.
- No producer or worker should be told the 227 A02 jobs executed until actual job receipts and output StorageRefs exist.

## Rollback

Keep the active previous Storage Fabric binaries and durable state untouched during pilot. Stop only the candidate reader binding; disable its peer discovery ACL and restore the previous service routing. Never restore an older checkpoint over newer valid committed records. Keep a read-only backup and journal evidence before authorising catalogue write migration.
