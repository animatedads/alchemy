# Dependencies

Core/session code has no required third-party ooRexx package dependency.

Optional integrations:

* API Client v0.4.x + Foreign Runtime v0.22.x: current OpenSSL-backed TCP/TLS compatibility seam used by `ImapApiTlsTransport.cls`.
* Storage Fabric v0.1-dev10 or compatible API: optional direct response-literal sink for large bodies/attachments.
* Secret Broker v0.2 or compatible API: intended production credential acquisition seam; not yet wired into the dev2 probe.

The TLS adapter is intentionally replaceable by a future general network-stream module.


- **ooRexx Logging v0.7 / module level 7 (optional)** — structured IMAP
  diagnostics via `ImapLoggingAdapter.cls`.  The IMAP core remains usable
  without the logging package.


The dev5 semantic profile layer has no new runtime dependency and performs no vendor
auto-detection.


## Dev7 optional search/index integration

* **NoSQLServer v0.79** — preferred backing store for the derived IMAP metadata and
  inverted-term index.  `ImapNoSQLIndex.cls` loads only when that integration is used;
  the wire/session core has no database dependency.
* The supplied NoSQLServer v0.79 build itself adopts Alchemy Objects v0.8 and therefore
  needs the Alchemy Objects/Crypto class path required by that package.  Those are
  NoSQLServer runtime dependencies, not duplicated or vendored by IMAP.
* **Storage Fabric dev15** — qualification target for the richer message/EAs/ranged
  byte-source projection.  The older direct literal sink remains compatible with the
  earlier Storage Fabric seam.

No NoSQLServer entry is invented in `OOREXX_PACKAGE.json` until NoSQLServer publishes a
Preferred-Packager package identity/lineage contract. The integration remains explicit
and externally supplied rather than encoding a guessed dependency identity.

## Dev8 transfer layer

`ImapTransfer.cls` has no new package dependency. Same-server MOVE/COPY/delete logic is
pure IMAP. Cross-provider streaming is intentionally left to the existing Storage
Fabric integration rather than adding another transport/storage dependency.

## Dev10 reviewed integration baselines

The 27 September portfolio checkpoint pins exact contemporary candidates for
cross-project review. They are review inputs, not automatic upgrades merely
because their filenames are newer:

* LDAP Identity dev11 — optional IMAP server authentication/identity attribution;
* Storage Fabric dev23 — current preferred storage-side integration target;
* SMTP Secure Stack dev5 — owns inbound signed/unsigned classification and local
  delivery semantics; IMAP does not duplicate that authority;
* Access Permissions v0.3 — intended future mailbox-authorization adapter seam;
  dev10 does not yet ship that adapter;
* Logging v0.8-dev1 exists in the portfolio, while IMAP's existing adapter remains
  qualified against the earlier v0.7 contract until a deliberate compatibility
  qualification is run.

`ImapLdapAdapter.cls` is optional and dependency-neutral at load time; it consumes
an injected Bind-capable object. The package manifest records LDAP Identity as an
optional dependency rather than making the IMAP client core depend on LDAP.

## Storage Fabric compatibility note — dev10

The dev10 core projection is qualified with Storage Fabric dev23. It no longer requires the removed legacy `StorageSemantic.cls`. The old semantic-provider adapter is isolated in `ImapStorageFabricLegacySemantic.cls`; loading that optional file requires an installation that still supplies `StorageSemantic.cls`.
