# Source provenance — ooRexx Identity Directory / LDAP v0.1-dev13

Development date: 2026-10-07

Primary project roll-up inspected:

- `oorexxapis(20260921-192614).zip`
- SHA-256 `bd12388cdb358fd8d318fcdee84f13d6b77eee81e8066b2e209a5ccb37018352`

Qualification runtime supplied by the project:

- `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(20260921-223149).deb`
- SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`

Current components directly inspected/used for compatibility or qualification:

- `oorexx_crypto_v0.8.3.zip` — `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`
- `oorexx_secret_broker_v0.2.zip` — `c063a8e863547e8d5af427daee9b887590fdad76a65bc042b8f853acfd51e623`
- `alchemy_objects_v0.8.zip` — `7683ed56ea99097226ea2f13f73305fb49919ba2ec822df2253ccfff59c6c073`
- `oorexx_access_permissions_v0.2.zip` — `44f6b92c9834bffd2699261520e03c820aee9773b94d3e4adcb23af2ceb1e5d5`
- `nosqlserver_v0.85_integer_precision.zip` — `6597301b945380de76fa57487c84aefe51d22f679013946550f33c54ba6bf793` (current FILE-engine requalification)
- `runtime_reference_v0.4.zip` — `c42a0c51cc5f5e26056d22db97d53eae2633141a7cebe3304b5f19b1847f957a`
- `oorexx_foreign_runtime_v0.22.6.zip` — `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`
- `msqlshim_v0.21.2.zip` — `f39bc8c58b2437d4cd45ef2443580785260a6d5dc85332a75bcb112ff026bfcc`

TLS implementation provenance:

- `oorexx_https_server_v0.4.4.zip` — `aad4305c2495b13145a71938c59af86bc8d128be8d466aaf7b3548468a252d56`
- `oorexx_api_client_v0.4.1.zip` — `9542e8cb9fcdefd42f32115a63034a7cc75ce8580a1356b6f58945e3f0401c37`
- `src/LdapOpenSslTls.cls` adapts the HTTPS package's qualified OpenSSL / Foreign Runtime memory-BIO server TLS mechanics to the provider-neutral LDAP `ldap.tls/0.1` seam. LDAP identity/session/authority policy is not inherited from HTTPS.
- `src/LdapOpenSslClientTls.cls` follows API Client v0.4.1's qualified OpenSSL client identity-verification path: TLS client method, trust-store/CA loading, peer verification, `SSL_set1_host`, SNI and post-handshake verify-result checking.
- `src/LdapOpenSslCommon.cls` factors the shared Foreign Runtime call-serialization helpers used by both LDAP TLS directions.
- `bridge/openssl_tls.bridge.json`, `bridge/openssl_bio.bridge.json`, and `bridge/openssl_crypto_error.bridge.json` are copied/adapted from the HTTPS package; `bridge/openssl_tls_client.bridge.json` is carried from API Client v0.4.1. LDAP therefore reuses qualified native symbol boundaries instead of inventing another OpenSSL FFI vocabulary.

Architectural inheritance / external use:

- Access Permissions supplies the existing distinction between authentication attribution, coarse Access Control and exact method Permission. `AccessPermissionsLdapAuthority` calls the upstream API; its policy model is not copied into LDAP.
- Secret Broker supplies the reference/lease/materialize/retire credential boundary.
- NoSQLServer + msqlshim supply the platform precedent that a compatibility wire personality does not become backend semantic authority. NoSQLServer is also the first concrete `DirectoryStore` provider through its public FILE-engine API.
- Crypto is consumed externally for semantic hashes/UUID derivation and related cryptographic primitives.
- Runtime Reference / Foreign Runtime are consumed by the OpenSSL TLS provider and by the accelerated Crypto qualification lane.
- JSON persistence uses `json.cls` from the ooRexx distribution; there is no project-local JSON parser/encoder.

Protocol specifications used as behavior references include the LDAPv3 protocol/model family (RFC 4511/4512/4513), LDAP DN string representation (RFC 4514), LDAP filter string representation (RFC 4515), LDAP syntaxes/matching rules (RFC 4517), LDAP entry UUID syntax/convention (RFC 4530), LDAP Content Synchronization (RFC 4533), the LDAP Cancel extended operation (RFC 3909), and Simple Paged Results (RFC 2696). RFC 3909 supplies the Cancel OID, request-value shape and result-code semantics used by `LdapCancelCodec` / the association operation registry. RFC 2696 supplies the paged-results OID and size/cookie conversation rules used by `LdapPagingCodec` / `LdapPagingRegistry`. These specifications define protocol behavior; their text/source is not copied into the package. The native dev subschema uses the RFC-documentation private-enterprise branch `1.3.6.1.4.1.32473.999.*` strictly as development numericoids; it is not presented as an allocated ooRexx enterprise number.

Current Library integration companions inspected for dev12:

- `oorexx_socket_provider_v0.1-dev5.zip` — `d54c7a95ddcc2097a54101a8a094bd4faf119ca9c39a09af6ce6dbb784659d3f`
- `oorexx_xtp_v0.1-dev10.zip` — `877d9549b335272e609ca5375f9c041fae11fb3ee652fe809fc21fdfd1d60e6e`
- `oorexx_intention_service_v0.1-dev10.zip` — `eb9fcec176760693a9de50b471eacfc62e65cba1881aeeb99713f06f3f59970f`

XTP dev10 was inspected as a transport companion, not copied into LDAP. It qualifies native ooRexx sender/listener bindings over its existing L2/L3/L4 route graph. Its documentation still lists multicast path-set distribution outside the current executable implementation, so dev12 does not claim native XTP multicast.

## v0.1-dev12 original increment

The peer update/epoch/outbox code, SocketProvider-compatible LDAP endpoint changes, divergent replay guard and failover-recovery tests are original package work. The peer layer consumes existing `DirectoryChange` semantics and deliberately separates semantic commit state from transport delivery/ACK state.

## v0.1-dev11 original increment

The dev11 schema-enforcement code is original package work over the sealed dev10 baseline. It adds `NativeLdapSchemaPolicy`, native objectClass/value alias translation, `oorexxEntity`/`oorexxGroup` schema publication, complete native Add coverage for groups/key sets/staged key generations, and associated qualification. No external directory-server source code was copied. Standards names and LDAP result-code semantics are interoperability identifiers only.


## v0.1-dev10 original increment

The dev10 matching-rule work is project-local implementation over the dev9 LDAP edge. `src/LdapMatchingRules.cls` defines the bounded native `ldap.matching/0.1` registry and the qualified `oorexx-ldap-schema-matching/0.1` DN profile. Existing DN/filter/BER/schema/conversation/wire code was extended to consume that registry; no vendor directory implementation or external matching engine was copied into the package.

The implementation uses the matching-rule names/OIDs and MatchingRuleAssertion structure as protocol/schema identifiers, while keeping Identity Directory semantics independent of LDAP matching. The qualified native registry covers objectIdentifier, distinguishedName, case-ignore, case-exact, integer and UUID primitives. It deliberately does not claim dynamically loaded matching rules, general schema enforcement or standards-complete Unicode/StringPrep processing.

Independent wire qualification uses the package's Python BER test only as an external client oracle for the emitted/accepted LDAP framing. The Python test does not supply production implementation code.


## v0.1-dev13 Library reconciliation

Before the dev13 increment, the current Library was rechecked rather than carrying forward dev12's dependency assumptions. The relevant current packages found were:

- `oorexx_socket_provider_v0.1-dev12.zip`
- `oorexx_xtp_v0.1-dev14.zip`
- `oorexx_norm_v0.1-dev3.zip`
- `oorexx_intention_service_v0.1-dev11.zip`
- `oorexx_management_intention_discovery_v0.1-dev7.zip`
- `rexxos_rto2_grid_v0.1-dev7.zip`

The decisive transport finding is that XTP dev14 explicitly corrects earlier capability overclaims and advertises multicast=false. Socket Provider dev12 retains explicit multicast address/membership contracts, while NORM dev3 is the current executable reliable-multicast sibling provider. dev13 therefore adds a provider-neutral LDAP multicast publication channel and a SocketProvider publication bridge without claiming native XTP multicast.

No source from those packages is copied into LDAP. The bridge consumes their public object contracts and keeps request identity, epoch fencing, idempotence and ACK policy in the LDAP/Identity peer layer.


## dev14 additions

- Intention Service contract reconciled against `oorexx_intention_service_v0.1-dev11.zip` from the current Library.
- Dynamic discovery semantics follow Intention Service v0.1-dev11: `input()` refreshes discovery before a fresh proposal cycle, while retained clarification state is explicitly separate.
