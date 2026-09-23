# Changelog

## 0.1-dev9 — 2026-09-23

LDAP syntax, filter and subschema interoperability increment over dev8.

- Added public `ldap.dn/0.1` with RFC 4514-oriented parsing/serialization for escaped separators, hex escapes, multi-valued RDNs, hexstring values, parent/compose operations and structural subtree comparison.
- Replaced comma/string suffix scope tests at the LDAP edge with parsed-RDN BASE/ONE/SUB semantics; Compare/Delete/Modify/ModifyDN/group-member resolution and Secret Broker Bind can resolve equivalent LDAP DN representations.
- Fixed ModifyDN parent calculation so an escaped comma inside an RDN is not mistaken for a DN separator. Network Add/ModifyDN canonicalize accepted LDAP DNs before committing them to the neutral directory.
- Added public `ldap.filter/0.1` with RFC 4515-oriented parsing/evaluation for AND, OR, NOT, equality, presence, substring, greater-or-equal, less-or-equal and approximate filters, including hex-escaped assertion bytes.
- Extended BER Search filter encode/decode for the same filter choices; independent Python BER qualification now exercises AND/OR/NOT plus substring matching over the real DSA. `extensibleMatch` remains deliberately unsupported until a general matching-rule engine exists.
- Added public `ldap.schema/0.1` and a read-only native `cn=subschema` projection. Root DSE `subschemaSubentry` now leads to a real BASE-searchable subschema entry containing native attribute/object-class declarations plus matching-rule/syntax discovery.
- The subschema development OIDs use the RFC-documentation PEN branch `1.3.6.1.4.1.32473.999.*`; they are explicitly not claimed as allocated production ooRexx OIDs.
- Schema publication remains discovery metadata rather than a second authority: general schema enforcement and arbitrary attribute matching-rule semantics are not claimed. DN comparison currently uses the explicit `oorexx-ldap-dn-case-ignore/0.1` profile.
- Paging and Sync query identity now canonicalize LDAP base DNs through the DN parser rather than lowercasing raw strings.
- Added unit qualification markers `LDAP DN SYNTAX`, `LDAP FILTER SEMANTICS` and `LDAP SCHEMA DISCOVERY`, plus real-wire ooRexx subschema/complex-filter checks and independent Python subschema/complex-filter checks.
- Full primary qualification passes in 10.86 seconds; Access Permissions adapter qualification passes in 0.17 seconds.

## 0.1-dev8 — 2026-09-23

RFC 2696 Simple Paged Results increment over dev7.

- Added public `ldap.paging/0.1` and RFC 2696 control OID `1.2.840.113556.1.4.319`.
- Added BER request/response control coding for page size, server size estimate and opaque continuation cookie.
- Added association-local result-set snapshots so paging does not become durable Identity Directory state or a NoSQL cursor.
- Cookies rotate on every successful page; earlier cookies become unresumable, completion returns an empty cookie, and page-size-zero plus the latest cookie abandons the sequence without closing the LDAP association.
- Continuations are bound to the original Search shape while permitting page-size changes between requests. Query mismatch, unknown/old cookie and exhausted/abandoned state fail closed as `unwillingToPerform`.
- Bounded live paging state to 64 result sets per association.
- Root DSE now advertises the RFC 2696 control and the wire capability snapshot truthfully reports association-local/rotating-cookie behavior.
- Added ooRexx DUA `searchPage`, `searchAllPaged` and `abandonPagedSearch` surfaces.
- Extended independent Python BER qualification to enumerate the full directory through multiple page sizes and opaque cookies.
- Full primary suite passes in 10.32 seconds; Access Permissions adapter qualification passes in 0.18 seconds.
- Sorting/VLV controls, complete RFC 4514/4515/schema behavior, arbitrary point-operation cancellation/concurrency and AD/Entra domain-controller semantics remain outside this development claim.


## 0.1-dev7 — 2026-09-23

RFC 3909 Cancel and same-association outstanding-operation multiplexing increment over dev6.

- Added public `ldap.cancel/0.1` with RFC 3909 Cancel OID `1.3.6.1.1.8`, BER request-value coding, and `canceled(118)`, `noSuchOperation(119)`, `tooLate(120)` and `cannotCancel(121)` result handling.
- Added association-local outstanding-operation tracking with explicit active/completed state; Cancel cannot cross an association boundary and repeated cancellation of a completed persistent Search reports `tooLate`. Completed IDs may subsequently be reused for a new LDAP operation, as required by the outstanding-only uniqueness rule.
- Promoted RFC 4533 refreshAndPersist from connection-close-only notification support to an operation that can be canceled without closing the LDAP association.
- Added DUA response demultiplexing by LDAP message ID so a persistent Sync Search may remain outstanding while a point operation completes on the same association.
- Qualified same-association refreshAndPersist + Modify interleaving, persistent MODIFY notification, RFC 3909 Cancel, target SearchResultDone `canceled(118)`, repeated-Cancel `tooLate(120)`, and successful post-Cancel Search.
- Root DSE now advertises the RFC 3909 Cancel OID in `supportedExtension`.
- Replaced the attempted concurrent RxSock reader/worker design with a single association event loop using `Socket~select()` polling after qualification exposed process-level blocking behavior. Message-ID multiplexing is real; arbitrary point-operation concurrency remains deliberately unclaimed and `concurrentDispatch=false`.
- Retained same-cookie Sync Info heartbeat/liveness messages without manufacturing semantic directory changes.
- Added independent Python BER qualification of the same multiplexed refreshAndPersist/Modify/Cancel/reuse conversation, in addition to the ooRexx DUA test.
- Full primary qualification and the Access Permissions adapter remain green; full OpenLDAP syncrepl behavior, paged results and arbitrary concurrent point-operation execution remain outside this development claim.

## 0.1-dev6 — 2026-09-22

Direct-TLS and persistent Content Sync network increment over dev5.

- Added direct implicit-TLS / LDAPS listener mode without changing LDAP or identity semantics.
- Added `LdapWireClient~connectTls()` with the same OpenSSL/Foreign Runtime chain and host/certificate verification used by StartTLS.
- Qualified direct TLS independently with both the ooRexx DUA and Python's TLS/BER stack.
- Added RFC 4533 refreshAndPersist notification support: initial Sync State refresh, Sync Info refresh completion, persistent ADD/MODIFY/DELETE state notifications and opaque cookie continuation.
- Added BER IntermediateResponse encode/decode and Sync Info codec coverage.
- Added an ooRexx persistent-sync subscription surface and independent Python persistent-sync qualification.
- Persistent-search cancellation is connection-scoped in dev6. LDAP Cancel and general outstanding-operation multiplexing are deliberately not claimed, so the capability remains `rfc4533RefreshAndPersistNotifications`, not complete refreshAndPersist.
- Added bounded same-cookie Sync Info heartbeats during an idle persistent subscription so a closed association becomes observable without manufacturing a semantic directory revision.
- The DSA accepts client associations asynchronously, while the capability snapshot explicitly keeps general `concurrentDispatch=false` because the supplied RxSock/runtime exhibits blocking process-level behavior.
- Moved `LdapWireClient~unbind` back onto the client class after introducing the subscription class; subscription close now correctly delegates to the DUA association.
- Full primary suite passes including ordinary LDAP, refreshOnly, refreshAndPersist notifications, StartTLS/SASL, direct TLS, semantic/store tests and independent Python clients.

## 0.1-dev5 — 2026-09-22

Network-security, Content Sync, semantic-time, Modify, durable-store and platform-authority increment over the earlier development cuts.

- Replaced string lifecycle timestamps with ooRexx `.DateTime` objects in the semantic core: credential/key `notBefore`/`notAfter`, key `rotateAt`, and entity/change timestamps.
- Canonicalizes DateTime values to UTC text only at protocol/serialization/evidence boundaries and reconstructs `.DateTime` on durable recovery.
- Validates lifetime ordering, credential effective windows and key activation validity windows.
- Added semantic LDAP Modify for supported principal/group/resource fields, including conversation-filter translation before mutation.
- Added BER ModifyRequest, controls and ExtendedRequest/ExtendedResponse framing plus DSA/DUA support.
- Added real LDAPv3 TCP server/client paths for Root DSE, Bind, Search, Compare, Add, Modify, Delete, ModifyDN and Unbind.
- Added optional `AccessPermissionsLdapAuthority` while preserving Bind attribution != Access Control != exact method Permission.
- Added provider-neutral `identity.directory.store/0.1` and `identity.directory.store.nosql/0.1` using NoSQLServer v0.79 FILE relations.
- Added write-before-memory durability, fail-closed peer binding, restart recovery and durable replicated changes without consuming local origin sequence.
- Persistence uses the ooRexx-supplied `json.cls`; numeric-looking IDs remain strings and credentials persist only `secretRef`.
- Separated LDAP `entryUUID` from platform `oorexxEntityId`; entry UUID is stable across modification, rename and recovery and has a 16-octet Sync representation.
- Added provider-neutral `ldap.sasl/0.1`; reference SASL PLAIN requires TLS and establishes attribution only.
- Added provider-neutral `ldap.tls/0.1` and a Foreign Runtime/OpenSSL memory-BIO StartTLS provider adapted from the qualified ooRexx HTTPS TLS substrate.
- StartTLS sends LDAP success before TLS negotiation and resets the LDAP authentication session to anonymous after transport upgrade.
- Added independent Python StartTLS qualification with certificate verification, encrypted SASL PLAIN Bind and authorized Search.
- Added an ooRexx OpenSSL/Foreign Runtime DUA TLS provider with certificate-chain and hostname verification, plus `LdapWireClient~startTls()` and `bindSasl()`; qualified ooRexx DUA -> ooRexx DSA StartTLS end to end.
- Factored shared OpenSSL Foreign Runtime call serialization into `LdapOpenSslCommon.cls` so client and server TLS providers share the native-lane discipline without sharing identity policy.
- Added `ldap.sync/0.1` implementing RFC 4533 Content Sync `refreshOnly`: request/state/done controls, initial ADD refresh, incremental ADD/MODIFY/DELETE transitions, opaque query-bound cookies and refresh-required refusal.
- Added DSA production and ooRexx DUA consumption of refreshOnly, plus independent Python wire qualification of initial and incremental Sync.
- Added generic critical-control refusal; unsupported critical controls fail closed.
- `refreshAndPersist`, full OpenLDAP syncrepl compatibility, direct LDAPS listener qualification, full RFC 4514/4515 behavior, complete subschema publication, paged results, concurrent wire dispatch and AD/Entra domain semantics remain deliberately unclaimed.
## 0.1-dev1 — 2026-09-22

First executable Identity Directory / LDAP semantic increment.

- Added stable-ID principal, group, resource, credential, ACL, key-set and key-generation entities.
- Separated stable semantic identity from mutable LDAP DN.
- Added default-deny ACL reference evaluation with group subjects and DENY precedence.
- Added key-generation staging, activation, rollover, retirement and revocation semantics.
- Added reference-only credential records and optional Secret Broker simple-bind adapter with immediate lease retirement.
- Added native LDAP semantic projection without raw secret exposure.
- Added generic conversation-filter attribute aliasing to establish the vendor-personality edge boundary.
- Added LDAP-style equality/presence/AND/OR/NOT filter evaluation for the parsed-operation layer.
- Added parsed-operation Bind/Search/Compare/Add/Delete/ModifyDN conversation service with authentication/authority separation.
- Added semantic peer-change export/replay with idempotency and fail-closed divergence.
- Explicitly does not claim BER/socket LDAP, RFC 4533 Sync, AD/Entra domain semantics or durable persistence yet.

