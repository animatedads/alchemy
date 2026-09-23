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
