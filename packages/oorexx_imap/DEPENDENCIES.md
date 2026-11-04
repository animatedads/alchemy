# Dependencies

Core/session code has no required third-party ooRexx package dependency.

Optional integrations:

* API Client v0.4.x + Foreign Runtime v0.22.x: current OpenSSL-backed TCP/TLS compatibility seam used by `ImapApiTlsTransport.cls`.
* Storage Fabric v0.1-dev11 or compatible API: optional direct response-literal sink for large bodies/attachments.
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
\n\n## Dev11 current Library integration notes — 7 October 2026\n\nThe current Library contains LDAP/Identity v0.1-dev14, SMTP Secure Stack v0.1-dev7, Socket Provider v0.1-dev14, and a newer-by-date Storage Fabric v0.1-dev21 branch. Dev11 keeps LDAP and Storage as optional integrations, adds an optional Socket Provider server binding, and does not copy SMTP/LDAP/Storage semantics into IMAP. LDAP remains identity attribution only; mailbox authorization remains IMAP/mailbox-authority owned.\n\nStorage Fabric v0.1-dev21's current adapter/projection surface was requalified with dev11 and both existing IMAP Storage tests pass. Because an earlier dev10 qualification used Storage Fabric dev23, the lower dev21 module number is treated as a separately published newer-by-date baseline rather than silently asserted as a monotonic supersession of dev23.\n

## Dev12 Instrumentation Mesh integration

* **Instrumentation Mesh v0.1-dev3 / `instrumentation.mesh/0.1` (optional)** —
  `ImapInstrumentationAdapter.cls` translates server endpoint facts into the
  common estate telemetry contract. The IMAP core/server files do not require
  Instrumentation Mesh, and IMAP creates no private telemetry history, transport
  or management protocol.

## Dev13 observation/readiness integrations

* **Socket Provider v0.1-dev14 (optional)** — server listener/connection authority
  and the readiness primitive consumed by `ImapSocketStreamTransport` for IDLE.
* **Instrumentation Mesh v0.1-dev3 (optional)** — semantic IMAP server/session and
  IDLE telemetry.
* **Socket Isolation Telemetry v0.1-dev1 / `socket.telemetry/0.1` (optional)** —
  decorator around Socket Provider for generic socket-boundary observations.  Its
  current package uses `PACKAGE.json`, not the Preferred-Packager
  `oorexx.package/0.1` identity contract, so dev13 does not invent an
  `optionalRequires` identity for it.

None of these observation components grants IMAP mailbox/session mutation authority.

