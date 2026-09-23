# Source provenance — ooRexx Identity Directory / LDAP v0.1-dev9

Development date: 2026-09-23

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
- `nosqlserver_v0.79.zip` — `076e6c6dafe367862ee25d5fcf80bef2eb3a5337060d3d2f55bba2f55327a1ec`
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

Protocol specifications used as behavior references include the LDAPv3 protocol/model family (RFC 4511/4512/4513), LDAP DN string representation (RFC 4514), LDAP filter string representation (RFC 4515), LDAP entry UUID syntax/convention (RFC 4530), LDAP Content Synchronization (RFC 4533), the LDAP Cancel extended operation (RFC 3909), and Simple Paged Results (RFC 2696). RFC 3909 supplies the Cancel OID, request-value shape and result-code semantics used by `LdapCancelCodec` / the association operation registry. RFC 2696 supplies the paged-results OID and size/cookie conversation rules used by `LdapPagingCodec` / `LdapPagingRegistry`. These specifications define protocol behavior; their text/source is not copied into the package. The native dev subschema uses the RFC-documentation private-enterprise branch `1.3.6.1.4.1.32473.999.*` strictly as development numericoids; it is not presented as an allocated ooRexx enterprise number.
