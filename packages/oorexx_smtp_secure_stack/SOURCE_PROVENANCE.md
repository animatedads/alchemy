# Source provenance

The SMTP semantic/policy/wire code is new for this package.

The protocol-neutral OpenSSL secure-socket implementation is mechanically extracted and renamed from the user-supplied/current Library LDAP Identity v0.1-dev10 OpenSSL server/client TLS substrate. That LDAP implementation itself documents provenance from the qualified ooRexx HTTPS/API-client OpenSSL + Foreign Runtime paths.

Bridge descriptors copied unchanged from LDAP Identity v0.1-dev10:

- `bridge/openssl_tls.bridge.json`
- `bridge/openssl_tls_client.bridge.json`
- `bridge/openssl_bio.bridge.json`
- `bridge/openssl_crypto_error.bridge.json`

The extraction intentionally removes LDAP naming/policy while retaining the transport mechanics and provider boundary.


dev3's `AccessPermissionsSmtpAuthorityV1` follows the concrete API shape observed in LDAP Identity v0.1-dev10's `LdapAccessPermissionsAdapter.cls`; SMTP action/domain/resource attributes are mail-specific while Access Permissions retains decision authority.

dev3's S/MIME/CMS verifier is new glue around the host OpenSSL command provider. It does not introduce an SMTP certificate store or signing key authority.

## dev4 exact qualification inputs

- Open Object Rexx 5.3.0 r13196 debug DEB: `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`
- Foreign Runtime v0.22.6: `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`
- Storage Fabric v0.1-dev23: `6e80e4a95717709ad715ef26ad024cfd9361ddcfe33c9da2629df302b64d1814`

The QueueRexx publisher shape deliberately follows Storage Fabric's existing optional QueueRexx binding: persistent messages, security-domain binding, and use of the supplied peer mesh/channel APIs without copying QueueRexx transport semantics.

## dev5 qualification additions

The new outbound dispatcher is package-owned SMTP protocol/release orchestration only. It does
not fork Storage Fabric durability, QueueRexx transport authority, Access Permissions, message
signature authority, Foreign Runtime, or OpenSSL TLS semantics. Live client STARTTLS was
qualified using the exact r13196 runtime and Foreign Runtime v0.22.6 listed in VALIDATION.txt.

## dev7 Library refresh — 2026-10-07

Dev7 is based byte-for-byte on the delivered dev6 archive before the changes listed here.

Reviewed current Library inputs:

- Socket Provider v0.1-dev13 — `b0772f42162aa814c6a8f5f76241dcd7ae80db61990509683b76665df180bd6f`
- LDAP/Identity v0.1-dev14 — `60f16d5c4cbdec0e0fde444e4adf075574740d38f42c6e1b895ae21338d35690`
- MVS Alchemy Services v0.1-dev3-pre17-wire-typed-locked — `24d8a2bbe72df9bc1bc75abd788205e407351db30366bf6e6bd993f4f400f505`

`SmtpSocketProviderBinding.cls` is new SMTP glue over the public Socket Provider contract; no
Socket Provider implementation is copied into this archive.  `SmtpMasMailBinding.cls` is new
host-side glue that intentionally distrusts the pre17 qualification booleans and reuses the
existing SMTP release authority path.

Storage Fabric dev23 remains the exact durable-delivery qualification baseline for this cut.
The Library contains newer/later-edited Storage Fabric branches and review overlays, but no
single newer full archive was adopted implicitly by filename/date alone.
