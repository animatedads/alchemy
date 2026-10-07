# WebDAV v0.1-dev4 architecture

```text
HTTPS Server
   |
   | HTTP framing / TLS
   v
WebDavHttpsAdapter
   |
   +-- DAV methods / Range / If state lists
   +-- PROPFIND / PROPPATCH
   +-- LOCK / UNLOCK (shared + exclusive)
   +-- sync-collection REPORT
   |
   v
WebDavStorageAdapter
   |
   +-- StorageNamespace / StorageRef / StorageEA
   +-- WebDavSyncJournal       DAV change evidence only
   +-- WebDavLockStore         DAV lock authority only
   +-- WebDavByteSourceRegistry
   |       |
   |       v
   |   StorageByteSource       bounded reads
   |
   +-- putFromSource()
           |
           +--> StorageByteSource
           +--> StorageByteSink
           +--> streamed SHA-256
           +--> StorageRef admission
```

The same object rules still apply:

- path is projection, not identity;
- StorageRef is stable identity;
- COPY may bind the same immutable StorageRef without copying bytes;
- MOVE changes projection;
- DAV locks do not override Storage write policy;
- DAV sync tokens do not replace Storage generations;
- Queue Fabric owns durable command delivery;
- HTTPS owns network/TLS framing.

## Bounded byte rule

A Range request over a registered byte source calls only:

```text
source.openAt(offset)
source.readChunk(requestedLength)
source.close()
```

within the configured DAV bound. Full-object materialisation is not required.

For bounded ingestion:

```text
StorageByteSource
     |
     | <= chunkSize
     v
StorageByteSink
     |
     +-- flush
     +-- repeat
     |
     v
streamed SHA-256 -> StorageRef -> namespace bind
```

The HTTP adapter does **not** pretend its current request/response objects are
streaming when they are not. Network request/response streaming remains an
HTTPS Server integration feature.
