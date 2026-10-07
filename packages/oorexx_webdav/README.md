# ooRexx WebDAV Gateway v0.1-dev4

dev4 continues the real dev2 -> dev3 implementation line and concentrates on
stateful DAV behaviour and bounded Storage I/O.

## New in dev4

### RFC 6578-style collection synchronisation

`REPORT` now accepts `sync-collection` requests.

- initial sync enumerates the current collection projection;
- incremental sync uses opaque `urn:oorexx:webdav:sync:N` tokens;
- PUT, DELETE, MKCOL, COPY, MOVE and PROPPATCH publish change evidence;
- deletions are represented as 404 responses in the multistatus;
- `WebDavSyncJournal` is restart-persistable and has bounded retention;
- expired/invalid tokens fail closed.

The journal is DAV change evidence. Storage generation/object identity remains
Storage Fabric authority.

### Stronger WebDAV `If` state-list evaluation

dev3's token-presence lock gate has been replaced with a parser/evaluator for
the useful RFC 4918 state-list core:

- OR between parenthesised state lists;
- AND within a list;
- lock state tokens;
- entity tags;
- `Not` conditions;
- tagged resource lists for the request resource.

Malformed state expressions fail closed.

### Shared and exclusive write locks

The lock authority now supports both:

- exclusive write locks;
- shared write locks;
- coexistence of multiple shared locks;
- exclusive/shared conflict checks;
- refresh and unlock;
- Depth 0 / infinity;
- restart journal format `WEBDAVLOCKS2`;
- migration/read support for the dev3 `WEBDAVLOCKS1` journal.

PROPFIND advertises both lock types and projects active lock discovery.

### Bounded Storage byte plane

WebDAV can now bind a `StorageByteSource` to a `StorageRef`.

- Range GET reads only the requested bounded Storage chunk;
- a large object need not exist as one in-memory WebDAV body;
- HEAD reports size without reading the object;
- full GET of a source larger than the bounded response limit fails closed
  until the HTTPS server exposes a streaming-response API;
- `putFromSource()` copies source -> `StorageByteSink` in bounded chunks,
  flushes each chunk, hashes the completed sink with streamed SHA-256, admits
  the resulting StorageRef, and re-exposes it through a local byte source.

The default bounded transfer/read quantum is 8 MiB. Tests deliberately exercise
a 20 MiB virtual source while requesting only 100 bytes.

### ooRexx `RESULT` cleanup

WebDAV source no longer uses `result` as a working object variable. `RESULT` is
an ooRexx special variable after `CALL`; using `result~...` is therefore a
latent failure trap.

## Still deliberately open

- the HTTPS Server needs a true streaming response API before unbounded full
  GET can be emitted without collection into one body object;
- HTTP request-body streaming needs the corresponding server-side source API
  before network PUT can directly feed `putFromSource()`;
- sync REPORT currently implements the collection/token/change core rather than
  every RFC 6578 optional property-selection detail;
- full multi-resource tagged `If` semantics for COPY/MOVE source+destination
  combinations remain a further increment;
- production collection-only dead properties need an external durable provider.

