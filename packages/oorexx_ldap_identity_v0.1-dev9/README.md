# ooRexx Identity Directory / LDAP v0.1-dev9

`oorexx_ldap_identity_v0.1-dev9` is a network-capable development cut of the platform identity directory for the ooRexx/Alchemy stack.

The defining rule is:

> **One identity truth, many conversations.**

Identity Directory owns neutral identity, resource, ACL declaration, credential metadata and cryptographic-key lifetime semantics. LDAP is the first native directory personality. Microsoft AD/Entra and other vendor dialects belong at the conversation-filter edge; they do not become platform policy or semantic truth.

This is the same architectural discipline used by NoSQLServer and its compatibility gateways: an edge can emulate a foreign conversation without making that foreign conversation the backend model.

## Public development APIs

- `identity.directory/0.1`
- `identity.credentials/0.1`
- `identity.keys/0.1`
- `identity.acl/0.1`
- `identity.replication/0.1`
- `identity.directory.store/0.1`
- `identity.directory.store.nosql/0.1`
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
- `ldap.schema/0.1`

These are development contracts and are not yet frozen production APIs.

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

v0.1-dev9 retains the explicit separation of two identities which earlier development cuts could conflate:

- `oorexxEntityId` is the stable platform semantic identifier;
- `entryUUID` is the LDAP directory-entry UUID projected by the LDAP personality.

`entryUUID` is stable across DN rename, ordinary modification, restart and durable recovery. It is represented as canonical UUID text in LDAP attributes and as 16 octets where the LDAP Sync control requires an entry UUID. A compatibility personality may alias either external name, but it does not merge their meanings.

## LDAP personality and edge filters

`NativeLdapPersonality` projects neutral semantic entities as LDAP entries. It intentionally exposes secret references and public key material but never raw private secret contents.

`AttributeAliasConversationFilter` plus `FilteredDirectoryPersonality` make the edge-personality rule executable: an endpoint can translate external vocabulary to/from the native personality without adding vendor fields to the semantic core. This is the intended seam for later AD, Entra, FreeIPA or other compatibility personalities.

A compatibility personality can change conversation syntax and externally visible conventions. It cannot silently redefine identity, authority, credential or key-lifetime semantics.

## LDAP DN, filter and schema edge

`ldap.dn/0.1` owns LDAP distinguished-name syntax at the conversation boundary. It parses escaped separators and hex escapes, preserves multi-valued RDN structure, provides deterministic rendering, and performs BASE/ONE/SUB hierarchy checks by parsed RDN rather than by searching raw comma-delimited strings. LDAP DN remains an address: the stable semantic `oorexxEntityId` remains authoritative.

DN equality currently uses the explicit `oorexx-ldap-dn-case-ignore/0.1` comparison profile. That is stronger and safer than raw lowercased DN text but is **not** a claim of arbitrary schema/matching-rule-aware `distinguishedNameMatch`. A later matching-rule engine can replace the comparison profile without changing semantic identity.

`ldap.filter/0.1` parses and evaluates AND, OR, NOT, equality, presence, substring, greater-or-equal, less-or-equal and approximate filters, including RFC 4515-style hexadecimal escaping. The BER DUA/DSA codec carries the same choices. `extensibleMatch` is refused rather than guessed because its meaning depends on matching-rule/schema authority that dev9 does not yet provide.

`ldap.schema/0.1` publishes a read-only native subschema entry at `cn=subschema`, referenced by Root DSE `subschemaSubentry`. It exposes the native attributes/object classes plus basic matching-rule and syntax discovery used by the current personality. The development-private schema OIDs are beneath the documentation PEN branch `1.3.6.1.4.1.32473.999.*`; they are not represented as allocated production ooRexx identifiers. The subschema is discovery metadata, not a new source of platform policy.

## Authentication is not authority

`LdapConversationService~bind()` establishes attributed identity only. It does **not** grant directory access.

Every Search/Compare/Add/Modify/Delete/ModifyDN operation crosses a separate `LdapOperationAuthority`. The supplied `DirectoryAclLdapAuthority` is a reference adapter over directory-managed ACL declarations and is default deny.

`AccessPermissionsLdapAuthority` is an optional first-tier adapter to the platform `AccessControlAuthority`. It projects the directory as an Access Control domain and each LDAP operation as an explicit entry point. The resulting decision remains Access Control evidence; it is not promoted into exact ooRexx method Permission.

The separation is therefore preserved:

```text
authentication attribution != Access Control != exact method Permission
```

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

`LdapWireClient~startTls()` now performs the LDAP extended operation and upgrades the same live socket through the client TLS provider; `bindSasl()` then provides SASL Bind over that protected transport. Qualification covers ooRexx DUA -> ooRexx DSA StartTLS with certificate/hostname verification as well as an independent Python TLS client. v0.1-dev9 also qualifies direct implicit-TLS LDAP (`ldaps://` style) as a separately configured listener mode. `LdapWireClient~connectTls()` performs immediate verified TLS before the first LDAP PDU. StartTLS and implicit TLS share the same provider-neutral transport seam; neither changes identity or authority semantics.

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

## RFC 2696 Simple Paged Results

`ldap.paging/0.1` implements the RFC 2696 Simple Paged Results control as an LDAP conversation feature rather than an Identity Directory semantic. The directory core has no page/cursor concept.

A paged result set is snapshotted after the ordinary LDAP Search authorization and personality projection have completed. Continuation state is local to that LDAP association, bounded to 64 live result sets, and addressed only by an opaque cookie. The server rotates the cookie on each successful page, so an earlier cookie is no longer resumable once a later page has been issued. Completion returns an empty cookie. A request with page size zero and the most recently returned cookie abandons the sequence and invalidates that cookie without closing the LDAP association.

The query identity is bound to the original Search shape: personality, base DN, scope, filter, requested attributes, `typesOnly`, `sizeLimit`, `timeLimit` and alias-dereference mode. The page size may change between requests, as RFC 2696 allows; other query-shape changes fail closed with `unwillingToPerform`. The server returns its result-set size estimate in the response control. On an initial paged request, if a non-zero Search `sizeLimit` is less than or equal to the requested page size, the control is ignored and ordinary Search size-limit semantics apply.

This remains a wire/conversation facility. It does not create durable directory cursors, semantic revisions, identity objects or authorization tokens.

## RFC 4533 Content Sync and RFC 3909 Cancel

`ldap.sync/0.1` projects the durable stable-change model through LDAP Content Sync conversations. v0.1-dev9 qualifies both `refreshOnly` and `refreshAndPersist`, with RFC 3909 Cancel as the operation-level termination mechanism for the outstanding persistent search.

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

## Deliberate dev9 limits

The following are not claimed yet:

- full OpenLDAP syncrepl provider/consumer compatibility beyond the qualified RFC 4533 conversation;
- cancellation of arbitrary in-flight point operations: the current cancellable outstanding class is the long-lived refreshAndPersist Search, while ordinary point operations are serially completed by the association dispatcher;
- arbitrary concurrent point-operation execution; message-ID multiplexing is qualified, but `concurrentDispatch` remains false;
- schema/matching-rule-aware DN equality beyond the documented case-ignore comparison profile;
- LDAP `extensibleMatch` and a general matching-rule engine;
- general schema enforcement, dynamic schema mutation, or a claim that the development OIDs are production-assigned identifiers;
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
