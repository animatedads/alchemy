# ooRexx WebDAV Gateway v0.1-dev5

dev5 follows the real dev2 -> dev3 -> dev4 line.  It is driven by the current
Library review rather than by an invented HTTPS streaming interface.

The Library still exposes **ooRexx HTTPS Server v0.4.4** as the current host.
Its public architecture owns TCP through RxSock and TLS through OpenSSL memory
BIOs, but the available source/review evidence does not expose a streaming
request/response body API.  WebDAV therefore does not counterfeit one.

## New in dev5

### Abort-safe staged streaming publication

`webdav.streaming/0.1` adds a host-neutral streaming ingress seam:

```text
HTTPS streaming host (future/current host adapter)
        |
        | bounded chunk <= nextMaximum()
        v
WebDavStreamingUploadSession
        |
        v
StorageByteSink staging object
        |
        +-- flush each accepted chunk
        +-- no namespace publication
        +-- abort -> cleanup
        |
        v
commit()
        |
        +-- exact Content-Length check
        +-- physical staging-size check
        +-- streamed SHA-256
        +-- Storage write-policy/precondition check
        +-- StorageRef + catalogue admission
        +-- namespace publication
        +-- sync change evidence
```

The critical invariant is that a partial or disconnected upload **never
acquires a WebDAV path**.  Publication occurs only after exact byte count and
SHA-256 verification.

`WebDavLocalStagedSink` adds explicit abort cleanup for local staging files.
The streaming session publishes backpressure information through
`nextMaximum()` and rejects chunks larger than the configured bound.

This is deliberately independent of `HttpRequest~body`.  When HTTPS Server
gains a request-stream callback/body-source interface, that host can feed this
session without changing the WebDAV/Storage semantics.

### Durable collection dead properties

Object dead properties were already StorageEA-backed.  dev5 adds
`WebDavDurableCollectionPropertyStore` for collection-only DAV metadata.

The journal:

- survives process restart;
- persists SET and REMOVE;
- follows collection COPY/MOVE semantics;
- stores path, namespace, property name and value without tab/newline ambiguity;
- remains DAV metadata authority rather than pretending collections are
  Storage objects.

Production deployments can inject this store into `WebDavStorageAdapter`.

### Hercules AWSTAPE representation

The current Storage Fabric Library has an authoritative
`StorageHerculesAwsTapeCodec` in `storage.fabric.hercules-sequential-media/0.1`.

WebDAV now exposes that codec explicitly as:

```text
application/vnd.oorexx.awstape
application/x-hercules-awstape   (accepted alias)
```

Canonical `TAPE_VOLUME` identity remains blocks + filemarks.  AWSTAPE is only
an edge representation.  The codec preserves:

- filemarks;
- multi-segment logical records;
- six-byte AWS segment headers;
- previous-segment length chains.

Malformed and truncated AWSTAPE is rejected by the Storage codec.

**HET remains unsupported.**  Storage Fabric dev17 explicitly does not claim a
qualified HET compression codec, so WebDAV does not guess, flatten, or relabel
AWSTAPE as HET.

## Existing dev4 capabilities retained

- PROPFIND / PROPPATCH;
- COPY / MOVE;
- shared and exclusive DAV locks;
- restartable lock journal;
- RFC 4918 state-list core for `If`;
- Range GET / If-Range;
- RFC 6578-style sync-collection REPORT;
- restartable sync journal;
- bounded StorageByteSource ranged access;
- Queue Fabric typed mutation objects;
- cards and paper sequential-media representations.

## Remaining external-host work

The next network-facing step belongs primarily to HTTPS Server:

1. request body source/callback with bounded reads and disconnect notification;
2. streaming response writer with backpressure;
3. abort/finalize hooks;
4. retained transport evidence that does not keep body bytes.

Once that exists, WebDAV can bind it directly to `WebDavStreamingUploadSession`
for PUT and to `StorageByteSource` for full GET without changing Storage or DAV
identity semantics.
