# WebDAV v0.1-dev5 architecture

```text
                         DAV protocol authority
                               |
                    +----------+-----------+
                    |                      |
              small HTTP body         streaming body
                    |                      |
                    v                      v
           WebDavHttpsAdapter     HTTPS host streaming adapter
                                           |
                                           v
                              WebDavStreamingUploadSession
                                           |
                                      bounded chunks
                                           |
                                           v
                                   StorageByteSink
                                           |
                                  staging / no publish
                                           |
                         exact length + streamed SHA-256
                                           |
                                           v
                                commitStagedSink()
                                           |
                          Storage policy + preconditions
                                           |
                     StorageRef/catalogue/namespace publish
```

A transport disconnect before commit leaves no WebDAV namespace entry and no
catalogue-admitted object.

## Media representation

```text
canonical TAPE_VOLUME
   block
   block (may be > 65535 bytes)
   FILEMARK
   block
       |
       | Accept: application/vnd.oorexx.awstape
       v
StorageHerculesAwsTapeCodec
       |
       v
AWSTAPE segmented byte representation
```

AWSTAPE headers and segmentation are representation mechanics.  Filemarks and
logical blocks are canonical Storage semantics.

No HET codec is invented in WebDAV.

## Collection dead properties

```text
file/object property  -> StorageEA
collection property   -> WebDavDurableCollectionPropertyStore
```

This split exists because the current Storage namespace has path bindings but
does not manufacture directory inode objects merely for DAV compatibility.

## Authority rules

- HTTPS Server: TCP/TLS/HTTP framing and eventual body streaming.
- WebDAV: DAV methods, properties, locks, preconditions and sync protocol.
- Storage Fabric: StorageRef identity, namespace policy, byte source/sink,
  verification and commit semantics.
- Hercules Storage adapter: AWSTAPE edge encoding/decoding.
- Queue Fabric: durable command delivery where selected.

No layer steals another layer's authority to make streaming convenient.
