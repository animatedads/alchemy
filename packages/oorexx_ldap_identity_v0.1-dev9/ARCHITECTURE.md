# Identity Directory / LDAP v0.1-dev9 architecture

## 1. Authority boundary

The semantic authority is the **Identity Directory**. LDAP is the first native network personality. Compatibility with AD, Entra or any future vendor dialect belongs in an edge conversation filter.

```text
                     applications / platform services
                                |
                                v
                  Identity Directory semantic core
        principals | groups | resources | ACLs | credentials | keys
                  /             |                 \
                 /              |                  \
       DirectoryStore      Access/Permission       lifecycle/crypto refs
             |                   |                        |
     NoSQL durable store         |                 Secret Broker / Crypto
                                 |
          +----------------------+---------------------+
          |                                            |
          v                                            v
     LDAP native personality                    other projections
          |
     conversation filters
          |
   LDAP wire / StartTLS / Sync / future vendor compatibility
```

This is the same architectural discipline used by the NoSQLServer/MySQL gateway: an edge conversation can emulate a foreign personality without making that personality backend truth.

## 2. Stable semantic identity vs directory address

A semantic entity has a stable platform identifier. LDAP DN is an address/projection and may change. `modifyDN` therefore changes directory location while preserving the semantic identity used by ACLs, credentials, keys and resource relationships.

v0.1-dev9 preserves the explicit separation of that platform identity from LDAP's directory-entry UUID:

```text
platform semantic identity:  oorexxEntityId
LDAP entry identity:          entryUUID
LDAP address:                 distinguishedName / DN
```

`entryUUID` is deterministic from immutable entity creation identity, cached by the entity, stable across ordinary modification/rename/recovery and exposed as canonical UUID text through ordinary LDAP attributes. `ldap.sync/0.1` uses the corresponding 16-octet UUID in Sync State controls. An AD-style `objectGuid` edge alias may map to `entryUUID`; that does not turn the UUID into the platform object ID.

## 3. Principal, group and resource model

A principal represents an attributable actor such as PERSON, SERVICE, NODE or WORKLOAD. A group owns explicit memberships by stable principal ID. A resource represents a protected or discoverable platform resource and carries a stable resource reference.

Group membership is not stored as a copy of mutable member DNs. The LDAP personality resolves stable member IDs to current DNs when projecting a group, so a member rename does not require rewriting semantic membership edges.

## 4. ACL semantics

Directory ACL declarations are neutral records over:

```text
subject -> resource -> action -> effect
```

The reference directory authority is default deny and gives explicit DENY precedence. LDAP Bind never bypasses this boundary.

`AccessPermissionsLdapAuthority` is an optional adapter into the existing platform Access Control contract. The LDAP service becomes a protected domain and an LDAP operation becomes an entry point. The returned Access Control decision remains coarse access evidence; it is not promoted to exact ooRexx method Permission.

## 5. Credentials and Secret Broker

Credential records contain identity, type, status, effective lifetime and a logical `secretRef`. Raw secret values do not belong to Identity Directory.

```text
Identity credential
      |
      +--> secretRef
             |
             v
       Secret Broker
             |
       short-lived lease
             |
             v
      trusted verifier
```

The supplied simple-Bind adapter:

1. resolves Bind DN to a stable principal;
2. resolves an ACTIVE credential whose `.DateTime` validity window contains the current instant;
3. acquires the logical `secretRef`;
4. materializes through `SecretLease~secretForTrustedConsumer()`;
5. verifies inside the trusted authentication boundary;
6. retires the lease before returning;
7. returns identity attribution, not directory authority.

No LDAP projection emits a password or private key value.

## 6. Time is semantic, text is a boundary representation

Lifecycle instants are `.DateTime` objects in the core:

- credential `notBefore` / `notAfter`;
- key-generation `notBefore` / `notAfter` / `rotateAt`;
- entity `createdAt` / `updatedAt`;
- directory-change `createdAt`.

Canonical UTC text appears only at persistence, LDAP/protocol or evidence boundaries. Recovery reconstructs `.DateTime`; timezone-spelling differences therefore do not become different semantic instants.

## 7. Key lifetime

A logical key set owns immutable generations. A generation carries algorithm, public material, private `secretRef`, validity/rotation times and revocation state.

The implemented lifecycle is:

```text
STAGED -> ACTIVE -> RETIRING -> RETIRED
              \-> REVOKED
```

Activation requires the current instant to be inside the generation validity window. Rollover can overlap generations so a successor becomes active while a predecessor remains usable for verification during an explicit retirement interval.

`DESTROYED` is reserved but is not claimed by a directory-only transition: destruction requires cooperation from the actual Secret Broker/HSM/KMS provider.

## 8. Personality and conversation filters

`NativeLdapPersonality` maps between neutral directory entities and LDAP entries.

A compatibility personality composes outside it:

```text
external vendor vocabulary/quirks
              <->
conversation filter
              <->
native LDAP vocabulary
              <->
neutral Identity Directory semantic fields
```

`AttributeAliasConversationFilter` and `FilteredDirectoryPersonality` demonstrate the rule without claiming a Microsoft implementation. A future AD/Entra package may translate attribute names, controls and compatibility behavior, but cannot silently redefine identity, ACL, credential, key-lifetime or resource semantics.

If an external ecosystem has a concept absent from the neutral model, the edge retains it as an explicit extension/capability until the platform deliberately adopts a neutral semantic equivalent.

### 8.1 LDAP syntax / matching boundary

`ldap.dn/0.1`, `ldap.filter/0.1` and `ldap.schema/0.1` are LDAP-edge contracts. They improve standards interoperability without moving LDAP representation rules into the neutral Identity Directory.

The DN parser models a DN as an ordered sequence of RDNs and each multi-valued RDN as a SET of AVAs. It handles escaped separators, RFC 4514 hex escapes and hexstring values. Canonical rendering sorts AVAs within an RDN and the current structural comparison profile is explicitly named `oorexx-ldap-dn-case-ignore/0.1`. That profile is sufficient for the qualified native vocabulary, but it is not a claim of schema/matching-rule-aware `distinguishedNameMatch`.

The filter parser/evaluator implements the qualified RFC 4515 choices AND, OR, NOT, equality, presence, substring, greater-or-equal, less-or-equal and approximate matching, including hex-escaped assertion bytes. BER Search filter encode/decode uses the same AST. LDAP `extensibleMatch` is rejected rather than guessed until a general matching-rule engine exists.

Root DSE `subschemaSubentry` points to a read-only native `cn=subschema` entry. That projection publishes the currently supported attribute types, object classes, matching rules and syntaxes for discovery; it does not become a second identity authority and general schema enforcement is not claimed. Development-only project numericoids live under the RFC documentation PEN branch `1.3.6.1.4.1.32473.999.*`; the package does not claim those as allocated production ooRexx OIDs.

## 9. Authentication, SASL and authority

A successful authentication creates an attributed `LdapSession`. It grants nothing else.

```text
Simple Bind / SASL
       |
       v
principal attribution
       |
       +--- Search? ----> LdapOperationAuthority --> allow/deny
       +--- Modify? ---> LdapOperationAuthority --> allow/deny
       +--- Delete? ---> LdapOperationAuthority --> allow/deny
```

`ldap.sasl/0.1` is a provider seam. The reference `PlainLdapSaslProvider` refuses PLAIN until TLS is active and delegates credential verification to the existing authenticator. It supports only empty `authzid` or `authzid == authcid`; this development cut does not invent delegation semantics.

## 10. Persistence boundary

`identity.directory.store/0.1` persists accepted neutral `DirectoryChange` records. It does not persist an LDAP-specific object model.

```text
IdentityDirectory mutation
        |
        v
DirectoryChange (semantic before/after state)
        |
        +--> DirectoryStore SPI
                 |
                 v
          NoSQLDirectoryStore
                 |
                 v
       NoSQLServer FILE engine
```

The authoritative commit order is **persist, then mutate memory**. Failed append means no visible semantic mutation and no revision advance.

The NoSQL provider persists schema/peer metadata plus an append-only change relation keyed by stable change identity. Store metadata binds durable state to one directory `peerId`. Replicated changes retain remote origin peer/sequence and do not consume local origin sequence.

Encoding uses the ooRexx-supplied `json.cls`, including explicit `JsonString` for lexically numeric identifiers. `.DateTime` becomes canonical UTC text only at this storage boundary. Credentials persist `secretRef`, never secret material.

Recovery replays the change log and validates revision, identity, origin, operation, before/after semantic identity and timestamp evidence. Checkpoint/compaction is deliberately left behind the SPI for a later increment.

A key rollover currently spans multiple individually durable changes. Atomicity is claimed for one accepted `DirectoryChange`, not an arbitrary multi-change business transaction.

## 11. LDAP wire boundary

The network stack remains a protocol edge:

```text
RxSock / TLS transport
       |
       v
LDAP BER + controls + extended operations
       |
       v
LdapWireServer
       |
       +--> StartTLS provider
       +--> SASL provider
       +--> Sync provider
       |
       v
LdapConversationService
       |
       +--> authenticator -> Secret Broker
       +--> operation authority -> directory ACL / Access Permissions
       +--> NativeLdapPersonality
       |
       v
IdentityDirectory semantic core
```

`LdapWireClient` provides the outbound DUA path. The current wire surface includes Bind, Search/Root DSE/subschema discovery, RFC 4514-oriented DN handling, RFC 4515-oriented filters, Compare, Add, Modify, Delete, ModifyDN, Unbind, controls, ExtendedRequest/Response, RFC 3909 Cancel, RFC 2696 Simple Paged Results, StartTLS, separately configured direct TLS, RFC 4533 refreshOnly and refreshAndPersist. The DUA demultiplexes responses by LDAP message ID so a long-lived Sync search can remain outstanding while a point operation completes on the same association.

Unknown **critical** controls are refused rather than silently ignored.

## 12. TLS / StartTLS provider seam

`ldap.tls/0.1` owns the provider-neutral transport upgrade contract. It does not hard-wire OpenSSL into the semantic or LDAP core.

The first server implementation, `LdapOpenSslTls.cls`, is adapted from the qualified ooRexx HTTPS server TLS substrate. The outbound implementation, `LdapOpenSslClientTls.cls`, follows the qualified ooRexx API Client TLS identity-verification path. Both use Foreign Runtime to drive OpenSSL with memory BIOs while RxSock continues to own socket I/O. The client verifies the certificate chain and LDAP host name by default; verification can only be disabled by explicit client configuration.

The StartTLS sequence is:

```text
LDAP ExtendedRequest(StartTLS)
          |
          v
LDAP ExtendedResponse(success)
          |
          v
TLS handshake / transport replacement
          |
          v
LDAP session reset to anonymous
          |
          v
client must Bind again
```

This keeps transport confidentiality separate from identity attribution. dev9 qualifies the complete ooRexx StartTLS conversation (DUA extended request -> DSA success -> verified TLS handshake -> SASL PLAIN -> authorized Search) and independently repeats the server-side proof with Python's TLS stack. It also qualifies direct implicit-TLS LDAP: the server upgrades immediately after TCP accept and the DUA uses `connectTls()` before sending its first LDAP PDU. Both paths use the same TLS provider seam and verification rules.

## 13. RFC 2696 Simple Paged Results

Paging is implemented above `LdapConversationService` and below the wire association. The Search is still authorized and evaluated by the normal semantic path first. The resulting LDAP entries are then snapshotted into an association-local `LdapPagedResultSet`.

```text
Search + pagedResults(size=N,cookie="")
       |
       +--> normal LDAP Search authorization + personality projection
       |
       +--> association-local result-set snapshot
       |
       +--> N entries
       +--> SearchResultDone + pagedResults(total,cookie=C1)

Search + pagedResults(size=M,cookie=C1)
       |
       +--> same query identity required
       +--> C1 invalidated
       +--> next M entries
       +--> SearchResultDone + pagedResults(total,cookie=C2 or "")
```

Cookies are opaque to clients, rotate on every page, and are meaningful only on the association that issued them. Reusing an older cookie, changing the query shape, or resuming a closed/abandoned result set fails closed with `unwillingToPerform`. A page-size-zero request with the latest cookie closes the result set without implying Unbind. The registry is bounded to 64 active result sets per association.

This intentionally does **not** become a persistent cursor in Identity Directory or NoSQLServer. Paging lifetime and cookie state are protocol conversation state; identity/resource truth remains independent of whether a client reads it in one Search response or twenty pages.

## 14. RFC 4533 Content Sync

`ldap.sync/0.1` projects the stable semantic change history through LDAP Content Sync without replacing the richer platform peer-change contract.

RefreshOnly remains the bounded replay form:

```text
Sync Search(no cookie)
       |
       +--> matching current entries + Sync State ADD / entry UUID
       |
       +--> SearchResultDone + Sync Done cookie
```

Incremental refresh uses the prior opaque cookie and returns relevant ADD/MODIFY/DELETE transitions followed by a new Sync Done cookie.

The dev9 refreshAndPersist path is an outstanding LDAP Search operation, keyed by its message ID:

```text
Sync Search(messageId=S, mode=refreshAndPersist)
       |
       +--> initial matching entries + Sync State       [messageId S]
       |
       +--> Sync Info IntermediateResponse(refreshDone=TRUE, cookie)
       |                                                [messageId S]
       |
       +--> persistent Sync State ADD/MODIFY/DELETE     [messageId S]
       |
       +--> optional same-cookie Sync Info heartbeat    [messageId S]
       |
       |        point operation(messageId=P)
       |<-----------------------------------------------
       |---------------- result -----------------------> [messageId P]
       |
       |        Cancel(messageId=C, cancelID=S)
       |<-----------------------------------------------
       +--> SearchResultDone canceled(118)              [messageId S]
       +--> Cancel ExtendedResponse success              [messageId C]
```

`ldap.cancel/0.1` implements the RFC 3909 Cancel request value and result semantics. Outstanding-operation state is association-local: a Cancel cannot reach an operation owned by another LDAP association. Completed operation IDs are retained long enough for a repeated Cancel to return `tooLate(120)` rather than becoming indistinguishable from an unknown operation. Unknown targets return `noSuchOperation(119)` and non-cancellable targets return `cannotCancel(121)`.

Cookies are opaque continuation tokens bound to the issuing peer and exact query shape. They are not entity IDs and not authorization tokens. Malformed, foreign, future or query-mismatched cookies fail closed with refresh-required behavior.

The DSA produces both Sync forms and the ooRexx DUA consumes them. The DUA has message-ID demultiplexing: frames for an outstanding operation are retained while the caller waits for another message ID. Independent Python qualification exercises the same association with refreshAndPersist, an interleaved Modify, RFC 3909 Cancel, repeated-Cancel `tooLate`, and a post-Cancel Search.

The implementation deliberately does **not** use concurrent RxSock reader/writer workers on one association. In the supplied runtime, blocking RxSock activity can serialize at process scope. The DSA therefore uses a single association event loop with `Socket~select()` polling: it advances persistent operations, accepts ordinary requests, and serializes writes while preserving LDAP message-ID multiplexing. This is real outstanding-operation multiplexing without claiming arbitrary concurrent point-operation execution; `concurrentDispatch` remains false.

## 15. Equal-peer direction

The package now supports both sides of ordinary LDAP conversation and both refreshOnly and persistent-notification Content Sync: a node can serve its directory projection and consume another server's change feed within the qualified subset.

That is deliberately distinct from the richer platform semantic peer contract. `DirectoryChange` retains source identity, source sequence, before/after semantic identity, idempotence and fail-closed divergence. Those semantics remain available for platform-to-platform replication where a generic LDAP conversation does not carry enough provenance/fencing information.

## 16. Deliberate development limits

Not claimed in v0.1-dev9:

- full OpenLDAP syncrepl provider/consumer compatibility beyond the qualified standard Content Sync conversation;
- cancellation of arbitrary in-flight point operations: the currently cancellable long-lived operation class is refreshAndPersist Search;
- arbitrary concurrent point-operation execution: message-ID multiplexing is qualified, while `concurrentDispatch` remains false;
- schema/matching-rule-aware DN comparison beyond `oorexx-ldap-dn-case-ignore/0.1`;
- LDAP `extensibleMatch` and a general matching-rule engine;
- general schema enforcement or dynamic schema mutation;
- server-side sorting / VLV-style controls beyond RFC 2696 simple paging;
- SASL mechanisms beyond TLS-required reference PLAIN;
- durable-log checkpoint/compaction;
- atomic multi-change key rollover;
- AD/Entra domain-controller policy, Kerberos, DNS integration or Microsoft replication protocols.

Those are extensions around the neutral authority boundary, not reasons to replace it.
