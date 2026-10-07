# ooRexx Identity Directory / LDAP v0.1-dev13

`oorexx_ldap_identity_v0.1-dev13` is a network-capable development cut of the platform identity directory for the ooRexx/Alchemy stack.

The defining rule is:

> **One identity truth, many conversations.**

Identity Directory owns neutral identity, resource, ACL declaration, credential metadata and cryptographic-key lifetime semantics. LDAP is the first native directory personality. Microsoft AD/Entra and other vendor dialects belong at the conversation-filter edge; they do not become platform policy or semantic truth.

This is the same architectural discipline used by NoSQLServer and its compatibility gateways: an edge can emulate a foreign conversation without making that foreign conversation the backend model.

## dev13 — current carrier truth and semantic multicast bridge

The logical peer contract still creates exactly one authoritative `DirectoryChange` and one `IdentityPeerUpdateRequest` regardless of how many peers must receive it. dev13 now has an executable multicast transport seam for that request rather than only unicast fan-out.

`IdentityPeerNativeMulticastTransport` uses one multicast publication only when the delivery set is the request's complete original target set. Per-peer ACKs remain explicit application evidence and are collected separately; multicast receipt is never treated as an ACK. If durable recovery later has only a subset outstanding, the transport uses targeted unicast for that subset instead of republishing to the whole group. This preserves dev12's “retry only missing peers” property.

The current Library dependency truth matters here:

- Socket Provider v0.1-dev12 has an explicit multicast membership/address contract and can host NORM/IP multicast providers.
- NORM v0.1-dev3 is the current qualified reliable-multicast sibling provider.
- XTP v0.1-dev14 explicitly advertises `multicast=false`; LDAP does not select XTP to satisfy multicast.

`SocketProviderIdentityPeerMulticastChannel` therefore accepts an already-selected multicast `SocketAddress` and publishes the unchanged peer-update JSON through `SocketProvider~senderAt()`. Carrier selection and group/session mechanics stay below Socket Provider. ACK transport remains separate because quorum/ALL commit semantics require individual peer evidence, not inferred network delivery.


### Environment qualification

A complete runtime harness is supplied at `tools/test_environment.sh`. It extracts the supplied ooRexx `.deb` without installing it system-wide, verifies r13196, wires the declared package roots, and runs the real LDAP/Identity suite. Set `LDAP_RUN_ACCESS_PERMISSIONS=1` plus the three policy package roots to include that integration pass.


## Public development APIs

- `identity.directory/0.1`
- `identity.credentials/0.1`
- `identity.keys/0.1`
- `identity.acl/0.1`
- `identity.replication/0.1`
- `identity.directory.store/0.1`
- `identity.directory.store.nosql/0.1`
- `identity.peer.update/0.1`
- `identity.peer.epoch/0.1`
- `identity.peer.outbox/0.1`
- `identity.peer.outbox.nosql/0.1`
- `identity.peer.transport/0.1`
- `ldap.personality/0.1`
- `ldap.conversation/0.1`
- `ldap.ber/0.1`
- `ldap.wire/0.1`
- `ldap.sasl/0.1`
- `ldap.tls/0.1`
- `ldap.sync/0.1`
- `ldap.cancel/0.1`
- `ldap.paging/0.1`
- `ldap.dn/0.1`
- `ldap.filter/0.1`
- `ldap.matching/0.1`
- `ldap.schema/0.1`
- `ldap.schema.enforcement/0.1`

These are development contracts and are not yet frozen production APIs.

## dev12 — failover-safe logical peers and estate socket boundary

Dev12 adds a logical peer layer above physical transport.  A platform peer has one stable identity even when RexxOS/RTO2 promotes a replacement runtime or when the selected network carrier changes. `IdentityPeerEpochAuthority` fences writers by promotion epoch and seals the exact committed origin-sequence range of older epochs: committed replay remains legal, while a future write from a stale epoch fails closed.

`IdentityPeerUpdateRequest` carries exactly one existing `DirectoryChange`.  One request identity may be distributed to many peers.  Targets apply the underlying change idempotently, and a duplicate `changeId` with a different semantic identity now fails as `REPLICATION_CHANGE_ID_DIVERGED`.  Completion policy is explicit: `LOCAL_COMMITTED`, `QUORUM_COMMITTED`, or `ALL_TARGETS_COMMITTED`.

Delivery state is deliberately separate from directory truth. `NoSQLIdentityPeerStateStore` records the durable request outbox and per-peer acknowledgements.  A replacement process can recover the authoritative Identity Directory, reopen the outbox, resend only missing targets, and continue the same logical peer origin sequence after an externally authorized promotion.  The dev12 regression proves this process-loss/recovery sequence locally against NoSQLServer. It is an RTO2-ready semantic boundary, not a claim that this package has already completed the full RexxOS WAN kill/promote field campaign.

LDAP wire construction also now accepts the estate `SocketProvider`/`SocketSelector` boundary.  The qualified bridge uses the current TCP binding and proves a real DSA listener and DUA sender through provider endpoints. LDAP still asks for reliable stream semantics and ordinary public LDAP interoperability remains TCP/TLS; LDAP does not choose XTP L2/L3/L4 carriers itself.

The current XTP v0.1-dev10 package is a transport companion: it supplies native ooRexx sender/listener bindings and carrier selection across L2, native IP protocol 36 and XTP-over-UDP. Its current executable profile does **not** yet qualify native XTP multicast. Therefore `identity.peer.transport/0.1` exposes semantic request multicast with safe unicast fan-out by default; a later carrier may implement native multicast without changing request identity or directory semantics.

The next human-facing layer is intentionally separate: current Intention Service v0.1-dev10 is the integration target for discovery-first identity/customer/cloud/infrastructure intentions. It is not hard-loaded by the directory core.

## Neutral semantic core

The semantic model is deliberately neither an LDAP schema nor an AD object model. It provides:

- stable semantic entity IDs independent of LDAP DN;
- principals: PERSON, SERVICE, NODE, WORKLOAD or another declared principal type;
- groups with explicit stable-ID memberships;
- resources with stable resource references;
- credential records containing `secretRef`, never secret values;
- `.DateTime` lifecycle state for `notBefore`, `notAfter`, `rotateAt`, `createdAt` and `updatedAt`;
- canonical UTC text only where a time crosses a protocol, persistence or evidence boundary;
- ACL grant records over subject/resource/action with default deny and explicit DENY precedence;
- key sets and immutable generation identities;
- staged/active/retiring/retired/revoked key lifecycle with validity-window enforcement;
- key rollover with an explicit active-generation pointer;
- monotonic local revisions and semantic change records;
- idempotent peer replay and fail-closed divergence detection.

A DN rename changes a directory address while preserving the semantic identity referenced by ACLs, credentials and keys.

### LDAP entry UUID is not platform identity

v0.1-dev13 retains the explicit separation of two identities which earlier development cuts could conflate:

- `oorexxEntityId` is the stable platform semantic identifier;
- `entryUUID` is the LDAP directory-entry UUID projected by the LDAP personality.

`entryUUID` is stable across DN rename, ordinary modification, restart and durable recovery. It is represented as canonical UUID text in LDAP attributes and as 16 octets where the LDAP Sync control requires an entry UUID. A compatibility personality may alias either external name, but it does not merge their meanings.

## LDAP personality and edge filters

`NativeLdapPersonality` projects neutral semantic entities as LDAP entries. It intentionally exposes secret references and public key material but never raw private secret contents.

`AttributeAliasConversationFilter` plus `FilteredDirectoryPersonality` make the edge-personality rule executable: an endpoint can translate external vocabulary to/from the native personality without adding vendor fields to the semantic core. This is the intended seam for later AD, Entra, FreeIPA or other compatibility personalities.

A compatibility personality can change conversation syntax and externally visible conventions. It cannot silently redefine identity, authority, credential or key-lifetime semantics.

## LDAP DN, filter, matching and schema edge

`ldap.dn/0.1` owns LDAP distinguished-name syntax at the conversation boundary. It parses escaped separators and hex escapes, preserves multi-valued RDN structure, provides deterministic rendering, and performs BASE/ONE/SUB hierarchy checks by parsed RDN rather than by searching raw comma-delimited strings. LDAP DN remains an address: the stable semantic `oorexxEntityId` remains authoritative.

`ldap.matching/0.1` now owns live LDAP comparison semantics. The qualified DN comparison profile is `oorexx-ldap-schema-matching/0.1`: each AVA is compared through the matching profile of its attribute, so `member` uses `distinguishedNameMatch`, revision/generation values use integer matching, `entryUUID` uses UUID matching, and native directory strings use case-ignore matching unless the filter explicitly selects another compatible rule. Search scope, Compare, Modify target/member resolution, Secret Broker Bind-name resolution, paging/Sync query identity and other live LDAP paths use this matching layer. The older `LdapDn~equivalent()` helper remains only as a dev9 compatibility syntax helper; it is not the advertised live comparison profile.

The current registry provides object-identifier, distinguished-name, case-ignore, case-exact, integer and UUID matching primitives, including the ordering/substrings rules published by the native subschema where applicable. Native attribute descriptions and their published numericoids are canonicalized to one profile, and native object-class descriptors/numericoids are equivalent under `objectIdentifierMatch`. This is a bounded native registry, not a claim of arbitrary dynamically installed LDAP matching rules or complete Unicode/StringPrep behavior.

`ldap.filter/0.1` parses and evaluates AND, OR, NOT, equality, presence, substring, greater-or-equal, less-or-equal, approximate and `extensibleMatch` filters, including RFC 4515-style hexadecimal escaping. Extensible matching supports an explicit attribute, explicit rule by name/OID, omitted attribute, and the `:dn` flag over DN AVAs. Rule/attribute compatibility is checked by syntax; unknown or incompatible rules fail closed as LDAP `inappropriateMatching(18)`. Ordering/substrings rules are not silently treated as boolean extensible equality rules. The BER DUA/DSA codec carries the same AST.

`ldap.schema/0.1` publishes a read-only native subschema entry at `cn=subschema`, referenced by Root DSE `subschemaSubentry`. It exposes the native attributes/object classes, 12 native matching-rule declarations and the required syntaxes. The development-private schema OIDs are beneath the documentation PEN branch `1.3.6.1.4.1.32473.999.*`; they are not represented as allocated production ooRexx identifiers. The subschema remains discovery/matching metadata rather than platform policy. dev11 separately enables bounded native-schema enforcement at the LDAP personality boundary; `schemaEnforcement=true` therefore refers only to `NATIVE_PUBLISHED_SCHEMA`, not to Identity Directory policy or arbitrary dynamic schema.

## Authentication is not authority

`LdapConversationService~bind()` establishes attributed identity only. It does **not** grant directory access.

Every Search/Compare/Add/Modify/Delete/ModifyDN operation crosses a separate `LdapOperationAuthority`. The supplied `DirectoryAclLdapAuthority` is a reference adapter over directory-managed ACL declarations and is default deny.

`AccessPermissionsLdapAuthority` is an optional first-tier adapter to the platform `AccessControlAuthority`. It projects the directory as an Access Control domain and each LDAP operation as an explicit entry point. The resulting decision remains Access Control evidence; it is not promoted into exact ooRexx method Permission.

The separation is therefore preserved:

```text
authentication attribution != Access Control != exact method Permission
```

## Dynamic Intention Service integration

`identity.intention.discovery/0.1` exposes Identity Directory to the estate Intention Service without turning a chat classifier into directory authority. `IntentionService~input()` refreshes discovery before each fresh proposal cycle; the LDAP adapter publishes a snapshot whose revision is bound to the current logical peer and directory revision. Current evidence replaces stale discovery evidence when the revision changes.

The supplied `DirectoryIdentityReadIntentionOperations` is intentionally read-only: status, list and find. The find path returns the ooRexx identity object intact. Administrative operations are an injected operations-provider concern and must perform their existing authorization/policy checks before mutation. This preserves the architectural rule that recognition of an intention is not permission to execute it.

The adapter uses discovery-scoped surface advertisements for current proposals and revalidates operation availability again at dispatch. Registrations are vocabulary only; a once-seen registration cannot preserve execution authority after the live operations provider withdraws it.

## Secret Broker integration

`SecretBrokerSimpleBindAuthenticator` is an optional adapter. Identity Directory stores only a `secretRef`; the adapter acquires a short-lived Secret Broker lease, materializes it inside the trusted authentication boundary, retires the lease before returning and never projects the raw value into LDAP.

The adapter enforces credential `notBefore`/`notAfter` as `.DateTime` values before acquiring a secret lease. An `ACTIVE` credential outside its effective window is unusable.

The simple-bind adapter is a boundary proof rather than a production password-hashing policy. A password-verifier provider can replace direct secret comparison without changing directory identity semantics.

## SASL boundary

`ldap.sasl/0.1` introduces a provider seam independent of directory policy. The supplied reference provider implements SASL `PLAIN` only and refuses it unless TLS is already active. It delegates the authentication identity/password to the existing authenticator and does not grant authorization as a side effect of SASL success.

The reference `PLAIN` provider accepts an empty authorization identity or one equal to the authentication identity; arbitrary delegation is intentionally not invented in this development cut.

## TLS / StartTLS boundary

`ldap.tls/0.1` is provider-neutral. The core wire server knows how to accept the LDAP StartTLS extended operation and replace a connection's transport with an approved `LdapTlsProvider`; it does not contain OpenSSL policy.

`LdapOpenSslTls.cls` is the first server provider. It uses Foreign Runtime with the qualified OpenSSL memory-BIO substrate adapted from the supplied ooRexx HTTPS server line while RxSock remains owner of network I/O. `LdapOpenSslClientTls.cls` is the corresponding DUA provider, aligned with the supplied API Client OpenSSL path: peer verification is enabled by default, a configured CA file or system trust store is used, and `SSL_set1_host` binds certificate identity to the LDAP host. A successful StartTLS response is sent before the TLS handshake begins. After transport upgrade the LDAP session returns to anonymous state and must Bind again.

`LdapWireClient~startTls()` now performs the LDAP extended operation and upgrades the same live socket through the client TLS provider; `bindSasl()` then provides SASL Bind over that protected transport. Qualification covers ooRexx DUA -> ooRexx DSA StartTLS with certificate/hostname verification as well as an independent Python TLS client. v0.1-dev13 also qualifies direct implicit-TLS LDAP (`ldaps://` style) as a separately configured listener mode. `LdapWireClient~connectTls()` performs immediate verified TLS before the first LDAP PDU. StartTLS and implicit TLS share the same provider-neutral transport seam; neither changes identity or authority semantics.

## Durable directory-store boundary

`DirectoryStore` is a provider-neutral persistence SPI. Identity Directory remains semantic authority; a store persists accepted `DirectoryChange` records and cannot reinterpret LDAP schema, ACL meaning, credential state or key lifecycle.

`NoSQLDirectoryStore` is the first durable provider and uses NoSQLServer's native FILE engine. It maintains durable peer/schema metadata plus an append-only semantic change relation. One accepted directory mutation maps to one durable change append. On restart, the directory replays those changes in local-revision order and reconstructs the same neutral entities.

The commit boundary is write-before-memory: if durable append fails, the in-memory revision and entity state do not advance. A store is durably bound to its `peerId`. Replicated changes are persisted while retaining their source peer/sequence and do not consume the receiving peer's local origin sequence.

Persisted payloads use the ooRexx-supplied `json.cls`; no local JSON parser/encoder is implemented. Textual values use `JsonString`, including numeric-looking IDs such as `001`. Core `.DateTime` values become canonical UTC text at the persistence boundary and are reconstructed as `.DateTime` on recovery. Credential payloads contain only `secretRef`.

Recovery currently replays the durable log. Checkpoint/compaction is deferred. Multi-change higher-level operations such as key rollover are not yet claimed to be one storage transaction; each constituent accepted `DirectoryChange` is individually durable and recoverable.

## LDAPv3 wire surface

The development DSA/DUA path implements and qualifies:

- definite-length BER TLV encoding/decoding;
- LDAPMessage and LDAPResult framing;
- general LDAP control envelope parsing/encoding and unknown-critical-control refusal;
- anonymous discovery and simple Bind;
- SASL Bind provider dispatch;
- Root DSE discovery;
- Search with BASE/ONE/SUB scope using parsed LDAP RDN hierarchy;
- RFC 4514-oriented DN parsing/escaping for escaped separators, hex escapes and multi-valued RDNs;
- RFC 4515-oriented AND/OR/NOT, equality, presence, substring, greater/less-or-equal and approximate filters on both parsed and BER paths;
- Root DSE `subschemaSubentry` plus a real BASE-searchable native `cn=subschema` entry;
- Compare;
- Add;
- semantic Modify (`ADD`, `DELETE`, `REPLACE`) for supported neutral fields;
- Delete;
- ModifyDN;
- Unbind;
- ExtendedRequest/ExtendedResponse framing;
- RFC 3909 Cancel with association-local outstanding-operation tracking;
- RFC 2696 Simple Paged Results with association-local opaque cookies, cookie rotation, page-size changes and size-zero abandonment;
- message-ID demultiplexing so persistent Sync traffic can interleave with point-operation responses on the same association;
- StartTLS through the provider-neutral TLS seam;
- separately configured direct implicit-TLS / LDAPS transport;
- requested-attribute projection and `1.1`/`*` handling;
- search size-limit response handling;
- an ooRexx LDAP DUA client, including StartTLS, direct TLS and SASL Bind;
- independent Python BER interoperability clients for ordinary LDAP (including RFC 2696 paging), StartTLS/SASL and direct TLS.

The TCP server remains an edge adapter over `LdapConversationService`; it does not contain identity policy.

## Native schema enforcement

`ldap.schema.enforcement/0.1` now enforces the **native published LDAP personality schema** at Add/Modify boundaries. This does not move schema authority into the neutral Identity Directory. Vendor personalities still translate at the edge and are checked only after translation into the native vocabulary.

The enforcement layer canonicalizes native attribute descriptions/numericoids and object-class descriptors/numericoids, rejects undefined attributes, enforces the native MUST/MAY sets, checks single-valued constraints, rejects user writes to server-maintained operational attributes, refuses objectClass mutation, and validates the currently qualified DN/UUID/integer/DateTime syntaxes. LDAP wire failures are projected as the corresponding standard result classes (`undefinedAttributeType(17)`, `constraintViolation(19)`, `invalidAttributeSyntax(21)`, `objectClassViolation(65)` and `objectClassModsProhibited(69)`).

The schema now publishes an abstract `oorexxEntity` superclass for common identity metadata and a native `oorexxGroup` structural class. Native group entries project **only** `oorexxGroup`, including non-empty groups, so the native personality never attaches two unrelated STRUCTURAL classes to one entry. Standard `groupOfNames` is accepted as an interoperability Add alias when its required `member` is present and is normalized to `oorexxGroup`; an OpenLDAP/AD-style personality may expose its preferred external class at the conversation edge. Compatibility filters may explicitly alias both attribute names and objectClass values without changing core identity semantics.

Native Add now covers principals, groups (including member resolution before the single semantic create commit), resources, credentials, key sets, staged key generations and ACL grants. LDAP Add of a key generation can create only a staged generation; activation remains a separate key-lifecycle operation and cannot be smuggled through schema input. Lifecycle times remain `.DateTime` objects after import.

The capability surface reports `schemaEnforcement=true` together with `schemaEnforcementScope=NATIVE_PUBLISHED_SCHEMA`. Dynamic schema mutation and general RDN-value enforcement are still explicitly false.

## RFC 2696 Simple Paged Results

`ldap.paging/0.1` implements the RFC 2696 Simple Paged Results control as an LDAP conversation feature rather than an Identity Directory semantic. The directory core has no page/cursor concept.

A paged result set is snapshotted after the ordinary LDAP Search authorization and personality projection have completed. Continuation state is local to that LDAP association, bounded to 64 live result sets, and addressed only by an opaque cookie. The server rotates the cookie on each successful page, so an earlier cookie is no longer resumable once a later page has been issued. Completion returns an empty cookie. A request with page size zero and the most recently returned cookie abandons the sequence and invalidates that cookie without closing the LDAP association.

The query identity is bound to the original Search shape: personality, base DN, scope, filter, requested attributes, `typesOnly`, `sizeLimit`, `timeLimit` and alias-dereference mode. The page size may change between requests, as RFC 2696 allows; other query-shape changes fail closed with `unwillingToPerform`. The server returns its result-set size estimate in the response control. On an initial paged request, if a non-zero Search `sizeLimit` is less than or equal to the requested page size, the control is ignored and ordinary Search size-limit semantics apply.

This remains a wire/conversation facility. It does not create durable directory cursors, semantic revisions, identity objects or authorization tokens.

## RFC 4533 Content Sync and RFC 3909 Cancel

`ldap.sync/0.1` projects the durable stable-change model through LDAP Content Sync conversations. v0.1-dev13 qualifies both `refreshOnly` and `refreshAndPersist`, with RFC 3909 Cancel as the operation-level termination mechanism for the outstanding persistent search.

The implementation supports:

- Sync Request control decoding/encoding for refreshOnly and refreshAndPersist;
- Sync State controls on returned entries;
- Sync Done controls for refreshOnly;
- Sync Info IntermediateResponse values for refreshAndPersist refresh completion and new-cookie notification;
- initial refresh with ADD states;
- incremental refresh from a previously issued cookie;
- persistent ADD/MODIFY/DELETE notifications after the refresh stage;
- stable 16-byte entry UUID across ordinary changes;
- cookie binding to issuing peer plus exact query shape;
- fail-closed refresh-required handling for malformed, foreign, future or query-mismatched cookies;
- RFC 3909 Cancel (`1.3.6.1.1.8`) with `canceled(118)`, `noSuchOperation(119)`, `tooLate(120)` and `cannotCancel(121)` handling;
- association-local operation ownership: one LDAP association cannot cancel another association's operation;
- message-ID demultiplexing in the DUA, so a point operation can complete while a persistent Sync search remains outstanding;
- DSA production and ooRexx DUA consumption;
- independent Python wire qualification of refreshAndPersist, interleaved Modify, Cancel and post-cancel association reuse.

A persistent subscription ends its refresh phase with Sync Info rather than `SearchResultDone`, then remains an outstanding search while ordinary operations may continue on the same LDAP association. Cancel has its own ExtendedResponse and the target search terminates separately with result code `canceled(118)`. A repeated Cancel of the completed search returns `tooLate(120)` rather than silently erasing association-local completion knowledge.

The implementation deliberately uses a single association dispatcher with `Socket~select()` polling rather than concurrent RxSock reader/writer activities. The supplied runtime can serialize blocking RxSock calls process-wide; event-loop dispatch therefore gives genuine message-ID multiplexing without pretending that arbitrary operations execute concurrently. Same-cookie Sync Info heartbeats remain available as liveness traffic and do not create semantic directory changes.

The cookie is an implementation-private continuation token, not a semantic identity or authorization token. Complete OpenLDAP syncrepl provider/consumer compatibility is still not claimed: generic LDAP Content Sync remains distinct from the richer platform peer-replication/provenance contract.

The platform's separate semantic replication contract remains available for platform-to-platform provenance/fencing rules that are richer than the generic LDAP Sync conversation.

## Deliberate dev11 limits

The following are not claimed yet:

- full OpenLDAP syncrepl provider/consumer compatibility beyond the qualified RFC 4533 conversation;
- cancellation of arbitrary in-flight point operations: the current cancellable outstanding class is the long-lived refreshAndPersist Search, while ordinary point operations are serially completed by the association dispatcher;
- arbitrary concurrent point-operation execution; message-ID multiplexing is qualified, but `concurrentDispatch` remains false;
- matching rules outside the published `ldap.matching/0.1` native registry, dynamically installed matching rules, or standards-complete Unicode/StringPrep normalization;
- dynamic schema mutation, arbitrary installed schema modules, general RDN-value enforcement, standards-complete syntax validation, or a claim that the development OIDs are production-assigned identifiers;
- server-side sorting / VLV-style result-set controls beyond RFC 2696 simple paging;
- SASL mechanisms beyond the reference TLS-required PLAIN provider;
- snapshot/checkpoint/compaction of the durable change log;
- atomicity across a multi-change higher-level sequence such as key rollover;
- Active Directory domain-controller semantics;
- Entra compatibility, Kerberos, DNS integration or Microsoft replication protocols.

AD/Entra support remains a separate edge-personality conversation, not a reason to change this list of core semantics.

## Run tests

The full suite requires Crypto, Secret Broker, Alchemy Objects and NoSQLServer. Runtime Reference + Foreign Runtime are optional for the neutral core but enable the fast Crypto lane and the OpenSSL StartTLS/direct-TLS provider qualification:

```sh
REXX=/path/to/rexx \
OOREXX_CRYPTO_ROOT=/path/to/oorexx_crypto_v0.8.3 \
SECRET_BROKER_ROOT=/path/to/oorexx_secret_broker_v0.2 \
ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.8 \
NOSQLSERVER_ROOT=/path/to/nosqlserver_v0.79 \
RUNTIME_REFERENCE_ROOT=/path/to/runtime_reference_v0.4 \
FOREIGN_RUNTIME_ROOT=/path/to/oorexx_foreign_runtime_v0.22.6 \
./run_tests.sh
```

The optional platform Access Permissions adapter is qualified separately because it pulls in the wider Access Permissions / Institutional Policy / Security Effect chain:

```sh
REXX=/path/to/rexx \
OOREXX_CRYPTO_ROOT=/path/to/oorexx_crypto_v0.8.3 \
ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.8 \
ACCESS_PERMISSIONS_ROOT=/path/to/oorexx_access_permissions_v0.2 \
INSTITUTIONAL_POLICY_ROOT=/path/to/institutional_policy_v0.8 \
SECURITY_EFFECT_ROOT=/path/to/security_effect_v0.14 \
tests/access_permissions_smoke.sh
```

Current acceptance markers include:

```text
IDENTITY CORE: OK
DATETIME LIFECYCLE: OK
KEY LIFECYCLE: OK
LDAP MODIFY: OK
LDAP PERSONALITY: OK
PERSONALITY FILTER: OK
REPLICATION: OK
CONVERSATION AUTHORITY: OK
SECRET BROKER BIND: OK
LDAP BER: OK
LDAP SASL PROVIDER: OK
LDAP SYNC: OK
LDAP WIRE CAPABILITIES: OK
LDAP CANCEL CODEC: OK
LDAP PAGING: OK
LDAP DN SYNTAX: OK
LDAP FILTER SEMANTICS: OK
LDAP SCHEMA DISCOVERY: OK
DIRECTORY STORE: OK
NOSQL DIRECTORY STORE: OK
LDAP WIRE OOREXX CLIENT: OK
LDAP WIRE PYTHON CLIENT: OK
LDAP WIRE SERVER: OK
LDAP SYNC PERSIST + CANCEL OOREXX CLIENT: OK
LDAP SYNC PERSIST + CANCEL PYTHON CLIENT: OK
LDAP SYNC PERSIST + CANCEL SERVER: OK
LDAP STARTTLS + SASL PLAIN OOREXX CLIENT: OK
LDAP STARTTLS + SASL PLAIN PYTHON CLIENT: OK
LDAP STARTTLS SERVER: OK
LDAP LDAPS OOREXX CLIENT: OK
LDAP LDAPS PYTHON CLIENT: OK
LDAP LDAPS SERVER: OK
ACCESS PERMISSIONS LDAP ADAPTER: OK
```
