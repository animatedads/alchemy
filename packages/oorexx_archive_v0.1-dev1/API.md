# API `oorexx.archive/0.1`

## Facade

```rexx
archive = .Archive~openZip(path)
archive = .Archive~parseZip(bytes)
writer  = .Archive~zipWriter
```

## `ZipArchive`

Construction:

```rexx
archive = .ZipArchive~fromBytes(bytes, maxEntries, maxEntryBytes, maxTotalBytes)
archive = .ZipArchive~fromFile(path,  maxEntries, maxEntryBytes, maxTotalBytes)
```

Defaults are 10,000 entries, 512 MiB per entry and 1 GiB total declared
uncompressed content.

Methods:

- `entries` -> Array of `ZipEntry` objects in central-directory order.
- `names` -> Array of logical entry names.
- `entry(name)` -> `ZipEntry` or `.nil`.
- `extractBytes(entryOrName)` -> validated uncompressed bytes.
- `extractFresh(root)` -> extract all validated regular files/directories into a
  newly-created root. Existing roots are rejected.

`extractBytes()` validates CRC32 and exact size. Method-8 decoding calls
`Compress~inflate(payload, entry~uncompressedSize)`, making the declared size a
live decompression ceiling.

## `ZipEntry`

Read-only attributes include:

- `name`
- `method`
- `flags`
- `crc32Bytes`
- `compressedSize`
- `uncompressedSize`
- `localOffset`
- `versionMadeBy`
- `versionNeeded`
- `externalAttributes`
- `internalAttributes`
- `diskStart`
- `isDirectory`
- `unixMode`

It also exposes `encrypted`, `hasDataDescriptor`, `utf8Name`, and `hostSystem`.

## `ZipWriter`

```rexx
writer = .Archive~zipWriter
writer~addBytes('src/Foo.cls', sourceBytes, 8)
writer~addBytes('data/', '', 0)
zipBytes = writer~bytes
writer~writeFile('/tmp/package.zip')
```

`method` must be 0 or 8. Directory entries must end in `/`, carry no payload,
and are written Stored.
