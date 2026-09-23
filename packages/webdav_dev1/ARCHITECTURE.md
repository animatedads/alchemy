# Architecture

Client -> HTTPS Server -> WebDavHttpsAdapter interceptor -> WebDavStorageAdapter -> Storage Fabric.

Mutating operations may instead be delivered through Queue Fabric using `WebDavQueueService`; a queued retry must refer to the same logical Storage transfer/commit identity when streaming support is enabled. Queue completion is not Storage commit authority.

WebDAV paths are projections of `StorageNamespace`; they are not host filesystem paths. `StorageRef.objectId` is the stable resource identity. ETags derive from the StorageRef digest when present. Storage environment generation is the future collection-sync authority.
