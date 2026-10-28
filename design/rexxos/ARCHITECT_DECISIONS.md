# RexxOS platform — Architect decisions

**Architecture and every decision below:** Tom Dyer.
**Recorded by:** Claude (Opus 5.5), 24 October 2026.
**Coding of the components named:** ChatGPT and Codex (unless stated).

These decisions were made and communicated before 24 October 2026. Tom restated them in the integration review on 24 October because they were not written down anywhere in Git, so ChatGPT and Claude both asked for them again.

**Rule for every agent:** these are settled. Don't mark them `ARCHITECT` or `UNKNOWN`, and don't ask for them again. Where code disagrees with a decision, the code is the defect.

## D-01 XTP striping is selectable

Striping is a per-connection option, selected the way any other XTP protocol option is selected. It is not a fixed carrier behaviour.

- The single-channel and dual-channel modes are both legitimate selections.
- Dual-channel stripes alternate bits over two channels. On loss of a channel it requests retransmission over the surviving route, then continues interleaved on the one channel.
- **Code status:** XTP dev25 has only XMP1 chunk striping (`include/xtp/xtp_multipath.hpp`, `send_multipath`). It has no bit-interleaved mode and no selection option. XMP1 also sends each chunk as a separate context, one at a time, so its paths are never in flight together.
- **Spec note (24 Oct 2026, secondary sources only):** the XTP sources found define no striping option. The per-context negotiation vehicle is the XTP 4.0 FIRST traffic specification, so the selection should be carried there as a private value and documented as an Alchemy extension. Details: `docs/XTP_SPEC_GAPS_DEV26.md` in XTP dev26.

## D-02 Dead-MU decision is a quorum of several MUs

A dead MU is decided by a quorum of several MUs. The quorum is not necessarily drawn from the MU responsible for the job.

- The owning MU detects a dead MI. Other MUs detect a dead MU.
- **Code status:** no quorum code exists in Git. Job-to-Node `JobNodePlacementLifecycle~recover` releases on one allocator's heartbeat expiry (`packages/job_node_allocator_v0.6-network1/src/JobNodeLiveness.cls:203`). That must wait for the quorum decision.

## D-03 MI identity and key model is open to proposal

Tom is flexible on the mechanism: a per-MI signing key, or a per-MI secret with outside attestation. Any proposal must close review finding R-10, which is that the MU can currently forge an MI result.

## D-04 Routes are distributed through LDAP, behind a pluggable interface

- LDAP is the natural distribution method for route management.
- The route source must be pluggable.
- Manual override files must work when LDAP has failed.
- **Code status:** `xtp.provision` (`packages/xtp_route_publication_v0.1_candidate1`) proposes the opposite arrangement: a file journal as the authority and LDAP as a projection. It must be redesigned to this decision. Today's `xtp.routes.tsv` files are the manual-override form.

## D-05 State-freezable jobs default to a minimum of 2 replicas

- The minimum is 2 replicas for state-freezable jobs.
- That is expected to be the production default.
- The design requires making a job state-freezable to be trivial.
- **Code status:** `StorageReplicaRequirement` defaults to 1 (`packages/oorexx_storage_fabric_v0.1-dev23/src/StorageFabric.cls`, `use arg replicasArg=1`).

## D-06 The MU provides Storage Fabric to its MIs, with partial materialisation

The MU serves Storage Fabric to its MIs.

A reader may jump across a very large object, for example coding a few seconds out of a 500 GB video. On a jumped read, only the byte ranges actually accessed are materialised.

**Code status in dev23:**

| Where | What it does | Problem |
| --- | --- | --- |
| `StoragePeerMaterialiser~materialise` (`src/StoragePeer.cls:478`) | Copies the whole object, then checks a whole-file SHA-256 | A whole-file digest can't verify a partial range |
| `StorageFuse` `readAt` (`src/StorageFuse.cls`) | Calls `materialize`, which builds the entire stream as one Rexx string, then takes `substr` | Impossible at 500 GB |
| `StorageParallelFetch` | Plans which source supplies which byte ranges | Planning only |

To meet D-06, materialisation needs two things:

- Range-addressed storage with sparse local extents.
- Per-chunk integrity, so a range is verified on its own. The Git provider's chunk manifests are the nearest existing pattern.

## D-07 XTP security: mechanism in libxtp, keys and policy outside

Decided by Tom Dyer, 28 October 2026, in answer to `docs/transport/XTP_AUTHENTICATION_PROPOSAL.md`.

- **The split.** libxtp carries the per-packet protection mechanism. Keys, identities and policy come from outside it: the Identity Directory over LDAP, the gateway, and Secret Broker.
- **Key sources: LDAP first, then a key file.** The key file is the fallback when LDAP is unavailable. This is the same pattern as routes under D-04.
- **Both authentication and encryption** are offered as options.
- **Protection is per service.** XTP links are per named service, so each named service has its own protection profile (none, authentication, or encryption) and its own keys.
- **The same strategy applies to X.25.** An X.25 service, identified by its called address and CUD protocol identifier, maps to a named service with a profile. A leg that cannot meet the profile is refused, not silently downgraded.

## Directives as recorded by ChatGPT (24 Oct answer K7, for Tom to confirm)

| Date | Directive |
| --- | --- |
| 4 Oct 2026 | Host access only through `sshnode.sh`. Allocation sequence: allocate, WLU, QEMU, ports, test, clean up |
| 7 Oct 2026 | MU to MI traffic is native L2 XTP only, never TCP |
| 7 Oct 2026 | Standby is about 10% the size of the primary, with a recovery target under 1 minute and its storage offloaded |
| 13 Oct 2026 | 16/8 minimum, then 20 distinct receipts |
| 22 Oct 2026 | MIs are found by their symbolic `GRID.MN.<MI>` names |
| 23 Oct 2026 | Field target is 10 MUs and 20 MIs; Git and hosts are not changed without authority |

Claude (Opus 5.5)
