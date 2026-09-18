# Architecture

Client -> HTTPS Server -> WebDavHttpsAdapter interceptor -> WebDavStorageAdapter -> Storage Fabric.

Mutating operations may instead be delivered through Queue Fabric using `WebDavQueueService`; a queued retry must refer to the same logical Storage transfer/commit identity when streaming support is enabled. Queue completion is not Storage commit authority.

WebDAV paths are projections of `StorageNamespace`; they are not host filesystem paths. `StorageRef.objectId` is the stable resource identity. ETags derive from the StorageRef digest when present. Storage environment generation is the future collection-sync authority.

## dev2 canonical-media boundary

WebDAV representation != Storage object identity.

A CARD_DECK, PAPER_LISTING or TAPE_VOLUME is canonical Storage sequential
media. WebDAV codecs render/import negotiated external forms. Hercules remains
a sibling edge authority and is never controlled internally by WebDAV.

Tape has no implicit flattening representation. A codec such as HET/AWSTAPE
must preserve filemarks and block boundaries bidirectionally.


## Durable ordinary-byte binding (dev3)

```
HttpRequest body (bounded by HTTPS)
        |
        v
WebDAV representation
        |
        v
StorageLocalFileByteSink -> SHA-256 -> StorageLocation
                                      |
                                      v
                                 StorageObject
```

GET reverses the durable leg through `StorageLocalFileByteSource`. Storage namespace unlink never implies physical deletion of that location.

## Hercules printer edge (dev3)

```
Hercules 1403/3211 host output
        | ASCII + FF
        v
WebDavHerculesPaperBridge
        |
        v
StorageSequentialMediaImage(PAPER_LISTING)
  DATA / DATA / PAGE_BREAK / DATA ...
        |
        v
WebDAV text/plain projection
```

The adapter owns representation conversion only. Hercules/device authority remains a sibling authority and any control path continues through its proper Queue Fabric/device component.


## Tape representation boundary (dev4)

```
WebDAV PUT (AWSTAPE / plain HET)
          |
          v
representation codec
          |
          v
StorageSequentialMediaImage(TAPE_VOLUME)
  DATA(block) / FILEMARK / DATA(block) ...
          |
          +----> Hercules adapter / mount
          |
          +----> WebDAV GET (explicit representation negotiation)
```

AWSTAPE/HET headers and compression/chunk markers are edge-format facts, not Storage object truth. Storage retains the logical block/filemark sequence. No generic byte concatenation exists for tape. Compressed HET remains a codec-provider boundary: the gateway detects compression flags and fails closed until an approved zlib/bzip2 implementation is injected.
