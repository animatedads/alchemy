# Development Floor architecture — v0.1-dev6

The Development Manager owns allocation. Workers receive bounded assignments;
they do not acquire authority merely by discovering work or by being able to
reach an external system.

## Identity and authority separation

```text
Assignment
   |
   +-- SpecialistProfile       durable package/domain knowledge
   +-- BotProfile              logical role and lane authority
   +-- ExecutionProvider       model/runtime used for this assignment
   +-- ProviderAccount         billing/business/account authority
   +-- ControlPlane            normalized infrastructure authority
   +-- ResourceProvider        host/WLU/QEMU/network/etc. authority
   +-- DeploymentProvider      how an exact deployment reaches execution
   `-- ApplianceProfile        qualified RexxOS runtime/provider composition
```

Provider, account, business entity, funding source, execution model and
specialist identity are separate facts.

## Alchemy Cloud Control binding

`alchemy.cloud-control/0.1` is registered as the normalized infrastructure
control plane with three kinds:

```text
SERVICE  -> normalized provider service capability
RESOURCE -> existing cloud resource control through cloudctl.sh
NODE     -> managed-node EXEC / TRANSFER / PULL through sshnode.sh
```

Development Floor does not fork the Cloud Control entitlement/account model.
The exact supplied v0.1-dev2 package is pinned by package and transport SHA-256 identities.

GCP RESOURCE operations require the explicit account selector and are routed by
Cloud Control through `gcloud-account.sh`, which checks the expected identity.
The two supplied GCP authorities therefore remain isolated:

```text
GCP/bashqueue        -> bashqueue@gmail.com
GCP/animated-ads-cy  -> animated.ads.cy@gmail.com
```

Other fleet provider-account registrations are presently declared logical
bindings until their exact account selectors/principals are added to Cloud
Control policy. They must not be treated as equivalent to the qualified GCP
identity guards.

## Infrastructure observation projection

The control plane and host probes intentionally remain separate authorities, but
Development Floor exposes one identity-preserving `DFManagedNodeProjection` per
logical node. This follows the same pattern used by the Odoo provider: wire/provider
representations are evidence; the ooRexx object is the stable navigable surface.

`DFNodeProjectionRegistry` is the identity map. Re-applying a new observation for
`ED209J` refreshes the existing object rather than manufacturing a new node object.
Each `DFObservedFact` retains its complete observation list and source-specific
latest value. Normalized convenience methods choose only the preferred presentation
source; they do not delete conflicting evidence.

Example divergence is therefore valid:

```text
cloudState = RUNNING        <- Alchemy Cloud Control
reachable  = false          <- sshnode.sh
freeSpace  = UNKNOWN        <- no host observation available
```

The projection is a read model only. It cannot restart machines, alter cloud
resources, mutate firewall rules or execute host commands. Those operations remain
owned by the registered authorities.

### Firewall as one concept

`DFManagedNodeProjection~firewall` returns a `DFFirewallProjection`. Its normal
`rules` surface aggregates rules from all observed scopes. Provenance remains in
`CLOUD`, `LOCAL` and `GUEST_INTERNAL` facets. Most allocation/test code therefore
asks about `firewall`; only network-specialist/RexxOS internals select a facet when
they must modify or reason about a particular enforcement layer.

## ED209 managed-node boundary

The node identifier is the durable identity. Development Floor intentionally
does not copy host IPs, users, SSH keys or ports into its registry.

```text
Development Floor
      |
alchemy.cloud-control/0.1 NODE
      |
SshNodeDelegate
      |
sshnode.sh
      |
ED209 logical node
```

This preserves the rule that every ED209 command, transfer and pull ultimately
uses `sshnode.sh` exclusively.

A host is allocatable only when both lifecycle and observed capability evidence
permit it. Known host != reachable host != QEMU-qualified host != allocatable
host.

## Cloud-infrastructure worker lane

The cloud-infrastructure specialist is a logical worker role, not a cloud
credential holder. It may request operations through registered authorities
when Development Manager assigns them. Raw provider CLI, raw SSH and scope
expansion are prohibited.

## Deploy-to-test

```text
REQUEST_RESOURCE_SET
ALLOCATE_HOST
RESERVE_WLU
ASSIGN_QEMU
ACQUIRE_NETWORK_LEASE
DEPLOY_OR_MATERIALISE
RUN_TEST
COLLECT_EVIDENCE
CLEAR_DOWN
REVOKE_NETWORK_LEASE
RELEASE_WLU
RELEASE_HOST
```

RexxOS deployments are image materialisations; ordinary Linux QEMU test boxes
may use post-boot deployment. RTO topology can request side-by-side standby,
explicit promotion, failover and forensic preservation.

The Network Lease resource remains intentionally `REGISTERED_INCOMPLETE` in dev5.
Cloud Control currently maps firewall listing but not temporary add/remove.
Cross-host port exposure therefore remains blocked at the framework level until
that provider surface exists and revocation can be verified.

## RexxOS appliance profiles

Appliance composition is a registered execution fact rather than application semantics. The App Server continues to depend only on `Crypto`; provider implementation remains outside it.

```text
REXXOS_MINIMAL  QUALIFIED_FALLBACK
    Crypto v0.8.3 / pure Rexx
    private_key_capability = 0

REXXOS_FAST     QUALIFIED_DEFAULT
    Crypto v0.8.3
      -> Runtime Reference v0.4
      -> Foreign Runtime v0.22.6
      -> foreign.openssl.crypto
      -> OpenSSL libcrypto.so.3
    private_key_capability = 0

REXXOS_CRYPTO   REGISTERED_UNQUALIFIED_PRIVATE_KEY_SERVICE
    separate authority class for provisioned private-key operations
```

A profile capability such as `crypto.ed25519.sign` does not by itself grant possession or authority over deployment/master private keys. The `privateKeyCapability` registration describes whether the appliance is intentionally provisioned as that service class.

## RexxOS deployment activation boundary

The signed command deployment path is qualified through `STAGED`. Activation is a separate state machine:

```text
STAGED
  -> RECONSTRUCTED
  -> BOUND
  -> ACTIVE
```

No worker may collapse those states or infer `ACTIVE` from successful transport/signature verification. The RTO activation specialist is registered for the next implementation slice but does not gain activation authority merely by being able to inspect a staged deployment.

## Specialist bootstrap and engineering loop

The expensive package bootstrap is one-time. Revisions update persistent
specialist knowledge from deltas. Zero-model-cost autotasks continue to refresh
source structure, compile state, tests, documentation work and evidence at
engineering boundaries.

## WLU execution authority and accounting

Development Floor does not own work entitlement.  The exact `work.load.units/0.12`
`WLUAuthority` owns demand assessment, reservation, admission, authenticated reservation
proof, actual consumption, settlement and release.  `DFWLUControl` is an adapter between
assignments and that authority.

A model/runtime/host binding is preparatory only.  Substantive execution requires an admitted
WLU reservation.  Assignment state therefore records WLU `UNRESERVED`, `RESERVED`,
`ADMITTED`, `SETTLED` or `RELEASED` separately from worker/provider identity.

The Development Floor accounting ledger is deliberately non-entitling.  It correlates WLU
reservation IDs with other resource facts while retaining their native units.  WLU and money
are not interchangeable currencies; neither are tokens, GPU seconds or wall time.
