# XTP Provisioning and Service Publication — Architecture candidate v0.1

**Date:** 22 October 2026  
**Qualification:** Design + offline signed-envelope contract tests only. Not a commissioned ED209 service, and not a remote-authenticated XTP implementation.

## Governing decision

Introduce **`xtp.provision`** as a *named, privileged XTP application service* hosted at the unified XTP gateway boundary. It distributes **approved, leased configuration** from already trusted authorities to MI agents, and accepts constrained node publications into a controlled registry. It is **DHCP-like provisioning**, not DNS-like resolution: an MI gets an authorised *configuration state and lifecycle*, which includes route candidates, named-service points, lease/revision and revocations. The local service registry remains the application-facing name authority, and carrier addresses remain only in XTP route configuration.

```
          immutable seed trust + authorised bootstrap path
                          |
MI node agent -- XTP authenticated KEY context --> xtp.provision
                          |                           |
                  signed announcement         controller authority
                                                      |
                                 file journal / LDAP Identity Directory
                                                      |
                          replicated authority commit + signed allocation
                                                      |
             verify target, quorum, class, epoch, lease and revocation
                                                      |
                     stage -> qualify -> activate -> ACK applied
                         |                      |
               Service Descriptors      XTP RouteTable / Gateway
```

## Critical present-tense boundary

XTP dev25 provides named FIRST, local route tables and native UDP/raw36/L2 mechanics, but **named-service admission is not remote identity authentication**. `xtp_gateway_v0.1-dev1_candidate` expressly lacks a production remote authenticated KEY-bound session, and the persistent FIRST->DATA stream remains experimental. Accordingly this service **must refuse all effectful operations until a real mutually authenticated, authorised XTP session or a separately qualified cryptographically authenticated channel bound to the XTP session is delivered**. A source IP, MAC, XTP KEY, ROUTE/XROUTE value, or string service name is never sufficient proof of identity. A signed payload is important but is not itself channel confidentiality or peer-session authorisation.

The XTP 3.4 `ROUTE` and `XROUTE` fields are 32-bit endpoint exchange aids, not a trusted signed route directory or evidence of hop-by-hop forwarding. The control protocol uses ordinary named-service *data*, not counterfeit ROUTE field semantics. Full multi-hop XTP router functionality is still outside this work.

## Layers and ownership

| Component | Authority and duties | Must never do |
|---|---|---|
| Provision node agent | Join over pinned seeds; make node-owned *offers*; apply verified committed configuration | Set its own operational class or alter immutable seed trust |
| Unified XTP gateway | Authenticated remote identity bound to KEY, service admission, actual local endpoint registration, L2/raw36/UDP route selection, stream delivery | Infer permissions from address, accept unsigned peer-supplied routes, advertise nonexistent live registrations |
| Service Registry v2 | Canonical service name -> registered class -> logical route peer -> service point | Store IPv4/IPv6/MAC addresses |
| Provision controller authority | Authenticate publication owner; scope/approve; issue signed per-target snapshots; authorise revocations; control epochs/quorum | Promote node wishes into policy merely because signed by the node |
| Provision registry backend | Durable journal, revision snapshots, audit and controlled subscriptions; file first, optional LDAP projection | Treat replicated LDAP data as consensus, or LDAP bind as sufficient permission |
| Operational Degradation Planner | Policy class of `xtp.provision`; transport-neutral admission/degradation | Be bypassed by caller-supplied priority |
| XTP RouteTable | Own carrier/underlay endpoints (IP, interface, MAC) and path health | Replace trust roots or operational class authority |

`xtp.provision` is a **single control service with opcodes**, not another per-application network stack. The controller and agent may run against an authenticated XTP service on different MIs; the gateway remains the one host-level carrier authority. The provision service class should be *protected management control*, operator registered and operationally bounded under degradation. Policy should ensure emergency revocation and controlled reconfiguration remain possible without giving provisioning unlimited bandwidth or pre-empting actual emergency application payloads.

## Two distinct attestations

**1. Node announcement:** The holder of MI `ed209h.mi1` signs its current offers: `ssh.management` at point `ssh.management`, logical peer `ed209h.mi1`, plus candidate routes by layer. This says **"I can supply"**, not **"everyone must install this"**. Strict standing policy limits the node to its own peer ids and pre-authorised services. The announcement contains no operational-class field.

**2. Controller allocation:** The configuration authority checks publisher identity, policy, collision and previous sequence, then signs a *per-target* allocation. The allocation includes operator-approved service->class relationships, route candidates, revocations, target MI, authority epoch, revision and expiry. Receivers only stage allocations with the required *distinct* controller signatures and local trust anchors. Two signatures from one controller do not satisfy quorum.

An approved publisher may update routine route candidates automatically under an existing delegation, but may **never grant itself a higher service class**. New sensitive service types or class changes require separate service-policy authority.

## DHCP-like lifecycle (over authenticated XTP)

1. `HELLO` — node opens `xtp.provision` using **locally pinned seed route(s) and authority keys**, authenticated and authorised before XTP payload admission. Node proves MI identity; supplies last applied epoch/revision, generation and a nonce. Never require a newly downloaded route to reach the very controller that authorises it.
2. `OFFER` — controller reports approved realm, capabilities, policy digest, authoritative epoch, revision, lease limits, and signed challenge response. Multiple authorised controllers may offer; the agent selects a compatible quorum-certified head, not the fastest unauthenticated responder.
3. `ANNOUNCE` — node submits an Ed25519 signed, sequence-monotone offer of node-owned service points/routes. Controller persists a pending record and checks scope; publisher cannot edit service classes or arbitrary peers.
4. `REQUEST` — agent requests a target-MI snapshot, or a delta following a known committed root hash. Full snapshot is mandatory fallback when ancestry is missing; deltas cannot be applied against the wrong base.
5. `ALLOCATE` — controller returns a signed, *quorum-certified* allocation (or signed `NO_CHANGE`). Transport acknowledgement is **not** authority quorum.
6. `PREPARE` — agent verifies signatures, controller roles, realm/target, epoch/revision, expiry, revocations and service policy; writes a durable staged generation; uses route preflight and health tests, but does not yet replace current routes.
7. `ACTIVATE` — atomic application of service/route generation in the gateway; preserve immutable bootstrap/override routes and any already-established critical contexts until safe cutover/fencing rules permit. `ACK_APPLIED` is durable and distinct from XTP CNTL receipt. Failure must `ROLLBACK` to last known good, with explicit error receipt.
8. `RENEW` — agent refreshes before expiry with jitter. A controller-issued lease is bounded in both wall time and local monotonic elapsed time. Reboot without trustworthy wall time must revalidate before accepting a new allocation.
9. `WITHDRAW`/`REVOKE` — node can withdraw only its own offers; high-priority controller-signed revocation/tombstone is distributed to every affected MI. Recipients preserve monotonic revocation floors even if peers restart or old snapshots reappear.
10. `SYNC` — agents reconnect after partitions, fetch the committed head, reconcile exactly once and report current applied revision and qualified service points.

The initial wire profile can use typed, bounded JSON for control records with a precisely specified ASCII-key/string, integer, boolean and array canonicalisation rule. Do **not** sign loosely parsed/reformatted arbitrary JSON; the reference verifier uses domain-separated Ed25519 over an explicit canonical body. For runtime, bind the canonical byte encoding to the established Serialization Selector once that exact executable interface is verified. Reject duplicate keys, floats, unknown schema fields, oversized frames, version downgrades and unexpected critical extensions.

## Deployment and paired-or-better authority

**Preferred production topology:** 3 independent provision controllers with 2-of-3 signed *committed* allocations, and a real durable commit/log authority behind the signatures. Authority membership, signing keys and epoch promotions are independently governed. Signing different revisions for the same (realm, epoch, index) is a protocol fault, not a normal merge to be silently resolved.

**Two controllers:** permitted with 2-of-2 commits; if one controller fails, commits pause and recipients use the last valid committed lease. Two independent writable authorities accepting their own 1-of-2 writes would split the estate. If higher write availability is needed, add a third witness/voter or an independently fenced leader/lease authority with demonstrated takeover and rollback; merely having a hot LDAP mirror is not enough.

**Backends:**
- **File provider first:** append-only, fsync-durable publication journal; versioned sealed snapshots; source/epoch/sequence ledger; applied MI receipts and revocation floors. A generation is write-before-memory and published only after durable commit. Maintain last-good and last-staged separately.
- **LDAP Identity Directory dev18 adapter:** store stable node identities, key references, delegations/ACLs, directory resource entities and searchable approved service records. Reuse the directory's existing peer epoch fencing, persistent outbox and application acknowledgements where qualified. DN is *not* identity; the stable directory entity id is. Bind operations to `LdapOperationAuthority` / Access Control (LDAP Bind alone is identity attribution). LDAP Sync/replication and NoSQL durability do not *by themselves* establish consensus or a quorum-certified configuration commit.
- Neither backend should hold raw private signing keys in directory attributes. Reference Secret Broker or a suitably governed private-key service/HSM.

**Security:** Use Ed25519 from the existing ooRexx Crypto v0.8.3 / direct OpenSSL path for detached record signatures, keyed by approved controller and MI identities. Prefer dedicated provision-key roles, separate from service-owner keys. Controller quorum authorization is *not* simply any two registered public keys. Authentication and confidentiality of the transport require their own qualified security layer; do not repurpose Crypto's nonstandard unclamped X25519 compatibility operation as a production key agreement without separate review. Revocation and epoch floors must survive node reinstallation/rollback or be re-established from independent trusted source.

## Registries and installation boundaries

A signed allocation contains two separate sections:

```
services: [{name, operational_class, route_peer, service_point}]
routes:   [{peer, layer, carrier, destination, interface, metric,
            wire_filters, multicast, enabled}]
```

Addresses appear only under `routes`, never under `services`. The service name remains what an app requests in `FIRST`. In the current baseline XTP `RouteTable` reads `routes.tsv`, while Service Registry v2 reads `services.tsv`; neither TSV contains provenance/lease/epoch/revocation. **Do not directly append externally supplied records to either TSV.** Maintain a signed authority ledger, generate both views for one transaction and have the gateway replace their in-memory generation together. The existing gateway candidate currently does not provide that authenticated atomic `PREPARE/ACTIVATE/REVERT` contract; that is a required implementation increment.

A published service point is a **permission to make that endpoint discoverable**. It does not launch a daemon and is not evidence that the local application registered its listener. Gateway live-registration checks still gate incoming FIRST before CNTL acceptance.

Carrier candidates may change after admission: validate destination/interface syntax, permitted routes, node identity associated with the remote key, effective route policy, expected protected path requirements and XTP health. Keep seed paths independent from downloaded paths; do not take down the last working seed before alternative reachability and emergency rollback are independently qualified. Do not infer a peer's identity from a supplied carrier destination.

## Proposed implementation surfaces (not yet claims of delivered API)

- `XtpProvisionAgent~join(seedControllerPeers)`; `~renew`, `~publish`, `~stage`, `~activate`, `~appliedState`
- `XtpProvisionController~receiveAnnouncement`, `~authorize`, `~commit`, `~issueAllocation`, `~revoke`, `~sync`
- `XtpPublicationStore` interface: `appendDurable`, `readHead`, `appliedFloor`, `replay`, `commitHead`, `recordAck`
- `XtpPublicationFileStore` primary provider; `XtpPublicationLdapStore` alternate backed by Identity Directory
- Gateway management IPC: `CONFIG_PREPARE`, `CONFIG_ACTIVATE`, `CONFIG_REVERT`, `CONFIG_STATUS`, `SERVICE_LIVE` (privileged, local and capability/UID constrained)
- Named XTP control service: `xtp.provision` (not a new UDP broadcast or EtherType)

The service agent must use the local gateway/Connect Selector surface when published, not implement another L2/raw36/UDP transport. The implementation should preserve the planner class from the registered descriptor rather than from the control message caller.

## Acceptance gates

### Offline contract (candidate1)

- Genuine Ed25519 signed announcements/allocations: PASS/FAIL with independent reference verifier;
- Node cannot assert or escalate an operational class; cannot publish outside delegated name/peer scope;
- 2-of-2 and 2-of-3 unique-signer quorum; reject one signer, duplicates and foreign signer;
- Expiry, stale sequence, stale epoch/revision, wrong target, bad carrier and protected bootstrap route denied;
- Revocation/route collision denied; source byte manipulation invalidates signature.

### Local native integration (required, **not qualified in candidate1**)

- Real gateway authenticated FIRST -> persistent KEY -> multiple provisioning messages;
- File backend power-fail/replay, write-before-memory and cross-registry atomic generation;
- LDAP adapter ACL, directory epoch/fence, durable outbox and replicate/ACK tests;
- live two-controller partition test enforcing 2-of-2 no-write; three-controller 2-of-3 takeover;
- real XTP UDP route health, lease renew jitter, heavy concurrent `xtp.provision` and critical service pressure;
- reject forged identity even when payload is signed, reject missing channel-binding proof;
- trusted UTC/monotonic-clock and reboot/rollback tests, expiry and revocation spread.

### Field promotion (required, **not qualified**)

- ED209 MI pairs over real XTP raw36, then L2 where available, using `/home/hc3/alchemy-autobuild/sshnode.sh <node> ...` and tightly scoped `CAP_NET_RAW`;
- failed controller, failed peer and broken route; old committed config remains readable, unsafe writes stop;
- complete fallback and emergency access verified before touching bootstrap connectivity;
- no full XTP multi-hop ROUTE/XROUTE forwarding claims.

## Package notes

`reference/provision_contract.py` is intentionally **offline Python executable evidence**, not an alternative production stack or a replacement for ooRexx service objects, crypto and Identity Directory. It writes no route files and opens no sockets. It provides pinned negative test vectors for a future native implementation to reproduce. All test keys are generated in memory on each test run, never shipped as private keys.
