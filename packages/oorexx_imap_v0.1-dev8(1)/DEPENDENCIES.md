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
* **Storage Fabric dev13** — qualification target for the richer message/EAs/ranged
  byte-source projection.  The older direct literal sink remains compatible with the
  earlier Storage Fabric seam.

No NoSQLServer entry is invented in `OOREXX_PACKAGE.json` until NoSQLServer publishes a
Preferred-Packager package identity/lineage contract. The integration remains explicit
and externally supplied rather than encoding a guessed dependency identity.

## Dev8 transfer layer

`ImapTransfer.cls` has no new package dependency. Same-server MOVE/COPY/delete logic is
pure IMAP. Cross-provider streaming is intentionally left to the existing Storage
Fabric integration rather than adding another transport/storage dependency.
