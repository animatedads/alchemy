# ooRexx WebDAV Gateway v0.1-dev1

`webdav.gateway/0.1` exposes an ooRexx Storage Fabric namespace through WebDAV while keeping protocol, transport, queue delivery and storage authority separate.

## dev1 executable surface

- HTTPS integration is an `HttpsServer` interceptor; HTTPS Server v0.4.4 is not forked or patched.
- `OPTIONS`, `HEAD`, `GET`, `PROPFIND` (Depth 0/1), `PUT`, `DELETE`, and `MKCOL`.
- Storage namespace resolution/listing and Storage catalogue object identity are authoritative.
- PUT/DELETE advance the Storage Environment generation.
- `ETag`, `If-Match`, `If-None-Match: *`.
- DAV `DELETE` maps to `StorageNamespace.applyUnlink()`; it never directly destroys Storage objects/replicas.
- WebDAV collection markers are gateway metadata in dev1 because Storage Fabric dev13 intentionally models bindings/views rather than directory inode objects.
- Optional Queue Fabric mutation consumer contract (`webdav.queue/0.1`) is supplied for durable command delivery. HTTP request lifetime is not storage-transfer authority.

## Boundaries retained

HTTPS owns TLS/HTTP transport. WebDAV owns DAV method/property/precondition semantics. Queue Fabric owns delivery. Storage Fabric owns namespace, object identity, write policy, generations, transfer verification and commit. Wire UI is reserved for operational projection; browser-visible Wire credentials must not become Storage or Queue authority.

## Dependencies qualified against

- ooRexx 5.3.0 r13196
- Storage Fabric v0.1-dev13
- HTTPS Server v0.4.4
- Queue Fabric v0.9-dev6

## Planned next cut

`PROPPATCH`, `COPY`, `MOVE`, DAV lock authority, StorageEA-backed dead properties, RFC 6578 generation-backed sync REPORT, Range GET, resumable large PUT, and Wire UI operational projection.
