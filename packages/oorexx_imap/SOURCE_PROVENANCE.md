# Source provenance

`oorexx_imap_v0.1-dev4` is derived from the Preferred-Packager-shaped
`oorexx_imap_v0.1-dev3` development cut produced in this conversation.

Dev4 adds a dependency-neutral structured diagnostic event-sink seam to
`ImapSession` plus an optional adapter for ooRexx Logging v0.7. The logging
package was taken from the supplied `oorexxapis(20260915-220648).zip` current
API bundle; extracted `oorexx_logging_v0.7.zip` SHA-256 is:

    df271691ec0bb497367feadacf9ee36cb7d2e70d7f2266599360cc89d36ab7cc

The transport/session implementation continues to use the supplied ooRexx
5.3.0 r13196 runtime, API Client / Foreign Runtime TLS seam and optional Storage
Fabric dev10 adapter available in the working environment. No user credential
was copied into this build tree or package.

Preferred Packager bootstrap inputs supplied alongside this work were:

* alchemy-preferred-packager v0.1-dev1 SHA-256
  `76432ac3ab4c818200d8fa7601cc87e079521c67b3249596b9162a2ec51dc393`
* oorexx-compress v0.1-dev4 SHA-256
  `570e15efbae5dcc9cfac6819776869a43320616394e9bf47fcad2b7efe4803e2`
* oorexx-archive v0.1-dev1 SHA-256
  `b68e1756a34b288b93258a342d1dcfb0b1344dfcd33f847de4ed4d3eca42386c`

## dev5 provenance

Dev5 is derived directly from the qualified dev4 tree.  It adds only IMAP-owned
changes: CWD-independent test source resolution and an explicit server-behaviour /
mutation-intent layer.  No Preferred Packager source was copied or modified.

The Citadel profile records operational semantics supplied during this project:
room-oriented IMAP posting, Sent APPEND submission, and automatic Sent recording for
Citadel SMTP submission.  These are represented as an explicit selected profile, not
as inferred generic IMAP behaviour.

## dev6 local changes

Derived from the sealed dev5 package. Added typed mailbox lifecycle operations,
UIDPLUS APPENDUID result parsing, offline qualification for both, and a gated live
APPEND/BODY.PEEK round-trip probe. Preferred Packager remains an external authority
and was not modified.


## Dev7 integration provenance

Dev7 was cross-qualified against the user-supplied Storage Fabric v0.1-dev13 and the
user-supplied/generated NoSQLServer v0.79 implementation. NoSQLServer was consumed as
an external database/index authority and was not modified or copied into this package.
The index adapter uses its public FileDatabaseEngine/NoSQLServerSQL relation and value
index surfaces. Storage Fabric was likewise consumed unmodified through its published
StorageRef/StorageObject/EA/namespace/streaming contracts.

## Dev8 local changes

Dev8 is derived directly from the dev7 executable tree. Changes are confined to the
IMAP project: compact COPYUID mapping helpers, exact move/source-removal semantics,
transfer metadata helpers, new offline/TLS qualification, and opt-in live probes.
Storage Fabric dev15, NoSQLServer v0.79, API Client, Foreign Runtime, Logging and the
Preferred Packager were consumed unchanged.

## Dev10 review provenance — 27 September 2026

Source baseline:

* `oorexx_imap_v0.1-dev9.zip`
* SHA-256 `fcb5ffc263edfd998717ba8c2939d01802e7ea972600b679dbae68c3c2c1ecc9`

Review input:

* `oorexx_portfolio_code_review_2026-09-27_checkpoint1.zip`
* SHA-256 `42a39eb122a47f5503569fde2fdd21a298d994951deb07dabf12f6674048981b`
* IMAP fix-list status at checkpoint: retrieved/inventoried; manual review pending.

Related candidate identities inspected from that checkpoint:

* LDAP Identity dev11 — `1ed558fa9ffed079b678a6915170d33a42851b81fd2a50d1a301d1dd054de35d`
* SMTP Secure Stack dev5 — `da56bbf2d4283f1c083a89f5d422b0233da2034f1587399024f5e7e4c5b1490e`
* Storage Fabric dev23(1) — `6e80e4a95717709ad715ef26ad024cfd9361ddcfe33c9da2629df302b64d1814`

These hashes identify review inputs only; they do not imply cross-project release
acceptance. Dev10-owned source changes are confined to this IMAP package.

Storage Fabric dev23 compatibility was verified against the exact reviewed dev23(1) candidate above. Its removal of `StorageSemantic.cls` exposed a dev9 load-time compatibility defect. Dev10 fixes the IMAP-owned adapter boundary only; Storage Fabric itself is not modified.
\n\n## Dev11 provenance — 7 October 2026\n\nBase: `oorexx_imap_v0.1-dev10.zip`, SHA-256 `76b96d418353e905dd8869fbe91a23794e92a876f8901ad270736a2f941d8291`. Current Library integration inputs inspected during this increment include LDAP/Identity v0.1-dev14, SMTP Secure Stack v0.1-dev7, Socket Provider v0.1-dev14 and Storage Fabric v0.1-dev21. Dev11 modifies only the IMAP package.\n

## Dev12 local changes — 8 October 2026

Dev12 is derived from the qualified dev11 IMAP tree. The new instrumentation
adapter was implemented against the user Library's
`oorexx_instrumentation_mesh_v0.1-dev3.zip`; the Mesh package itself is not
vendored or modified. `ImapServerEndpoint` gained a dependency-neutral observer
seam and `ImapServerResponse` gained terminal-status metadata used by that seam.

## Dev13 local changes — 9 October 2026

Base archive: `oorexx_imap_v0.1-dev12.zip`, SHA-256
`740aa11acc9f6e849389effd03fa2e22f76f43855d947b7868aa5ddcbf7cebab`.

Library inputs used for this increment, consumed unmodified:

* Instrumentation Mesh dev3 —
  `4639859e71c1f6178de67a04c97c0e1a507dc4eef0359f7d4cae49319f6f0114`;
* Socket Isolation Telemetry dev1 —
  `2c295c2e47f166b04202adf13df70ce0f0e0863dc6eeb070013d62b0ee04e412`;
* Socket Provider dev14 —
  `39d9f5f6851bf134acb9cc372126a1f53d19eeff4148b28d353bbe76f5451abe`;
* LDAP/Identity dev14 —
  `60f16d5c4cbdec0e0fde444e4adf075574740d38f42c6e1b895ae21338d35690`;
* SMTP Secure Stack dev8 —
  `5f7cae35c5e30e89141d4484204010c620e2ebdab76d72c0a8089545c1bf0b34`;
* Storage Fabric dev21 branch used for current-by-date integration qualification —
  `e070c38cc622fd2e62bf67e17bd97b74c19fc2c34c77a9452bea2ac081753105`.

The dev13 source changes are confined to IMAP.  No dependency package and no
Preferred Packager source was modified.

