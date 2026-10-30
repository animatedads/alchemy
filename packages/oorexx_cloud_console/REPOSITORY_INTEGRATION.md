# Repository integration — ooRexx Cloud Console v0.1-dev2

This directory publishes the exact source tree of the qualified `oorexx_cloud_console_v0.1-dev2.zip` together with this repository-only integration note.

The qualified ZIP identity remains:

```text
SHA-256 9c93d6c4e0c9ac7a6964cdb69770236c8ced1c22cd14f90408cb71c31e96086f
```

`REPOSITORY_INTEGRATION.md` was added after that qualification and is deliberately **not** included in the package `SHA256SUMS`. Nothing in this note upgrades or extends the 2026-09-06 runtime qualification.

## Authority placement in the current Alchemy tree

The current Alchemy repository already treats **Alchemy Cloud Control** as the cloud resource authority:

```text
API       alchemy.cloud-control/0.1
Authority ALCHEMY_CLOUD_CONTROL
Kinds     RESOURCE, NODE
```

The Development Floor registration and dependency material use that authority for cloud resources and hosts. Therefore ooRexx Cloud Console must not become a competing cloud truth or a provider-specific branch inside Management Intention Discovery.

The intended placement is:

```text
Human / Codex / program / ooRexx caller
                 |
                 v
        ooRexx Cloud Console
  vocabulary, plan/apply, rendering,
  workspace-safe argument transport
                 |
                 v
       Alchemy Cloud Control
      alchemy.cloud-control/0.1
      RESOURCE / NODE authority
                 |
                 v
      provider adapter / provider IAM
       Azure | GCP | AWS | OCI | Vultr
```

The direct provider-CLI backend in v0.1-dev2 remains useful as the package's already-qualified fixture/adapter boundary and as an emergency/operator path. It is not the preferred semantic integration seam for Management.

## Boundaries that remain mandatory

- Management Intention Discovery discovers a cloud specialist dynamically; it does not learn `az`, `gcloud`, `aws`, `oci`, Vultr syntax or credentials.
- Cloud Console owns interaction vocabulary and presentation, not cloud truth.
- Alchemy Cloud Control owns resource/node operation semantics and remains the authority consulted for mutation.
- Provider IAM and credentials remain provider authority and are not transferred by a workspace switch.
- `--workspace` is execution context only. A source directory is not a permission grant, durable state authority or semantic identity.
- Provider resource handles are action locators. They are not Job-to-Node Allocator `nodeId` values.
- Mutation remains plan-first and must fail closed when authority or provider evidence is incomplete.

## Continuation recovered from Library

The later operator helper `cloudctl(2).sh` (Library snapshot 2026-10-13, SHA-256 `8cdd1df898b708552eae99ae079ae9bc20b4b1ba527b03155af91572cacd2510`) contains multi-peer firewall source-set operations used by XTP commissioning on GCP, AWS, Azure and OCI.

That is a real capability gap relative to the September ooRexx console, but its reusable requirement is **generic firewall source-set reconciliation**, not an ED209/XTP-specific vocabulary in Cloud Console. The next executable increment should therefore add authority-backed operations such as:

```text
firewall sources add
firewall sources replace
firewall sources remove
```

or an equivalent typed reconciliation contract. XTP may consume that capability while XTP remains authority for XTP topology and peer membership.

## Next executable gates

1. Introduce an `alchemy.cloud-control/0.1` backend beneath `CloudApp` without changing the public Cloud Console vocabulary.
2. Keep the direct provider-CLI backend available for offline fixtures and explicitly selected operator/emergency use.
3. Add generic firewall source-set reconciliation and prove idempotent add/replace/remove semantics across providers.
4. Preserve provider-handle versus managed-node identity separation.
5. Re-run the full fake-provider suite under ooRexx 5.3.0 r13196, then perform bounded live read-only qualification before any live mutation qualification.
6. Put Wire UI over the same controller/authority seam rather than creating another cloud implementation.

No new runtime qualification is claimed by this repository integration commit.
