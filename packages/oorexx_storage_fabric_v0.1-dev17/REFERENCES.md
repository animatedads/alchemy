# Storage Fabric v0.1-dev6 references

## Google Drive protocol

Official Google Drive API documentation used to pin the first executable Drive transfer semantics:

- Resumable uploads: https://developers.google.com/workspace/drive/api/guides/manage-uploads
  - resumable session initiation and `Location` URI;
  - non-final chunk sizes in multiples of 256 KiB;
  - `Content-Range` on chunk PUT requests;
  - HTTP 308 / response `Range` acknowledgement and status-query resume flow;
  - resumable session lifetime documented as one week.
- Partial downloads: https://developers.google.com/workspace/drive/api/guides/manage-downloads
  - byte-range partial download via the HTTP `Range` header for binary Drive files.

These references define protocol behaviour only. Storage Fabric does not persist bearer tokens or OAuth refresh credentials.

## ooRexx runtime

The supplied ooRexx 5.3.0 r13196 reference manual (`rexxref.pdf`) was consulted for persistent-stream operations used by the local byte adapters, particularly `STREAM QUERY SIZE`, `STREAM QUERY TIMESTAMP`, `STREAM OPEN`, `STREAM FLUSH`, `CHARIN`, and `CHAROUT` positioning semantics.

- REST File resource: https://developers.google.com/workspace/drive/api/reference/rest/v3/files
  - `sha256Checksum` is output-only and may be available for binary content stored in Drive; it is not populated for Docs Editors or shortcut files.

The upload guide was checked at its 2026-08-19 revision for dev6. In particular, restart logic follows the provider `Range` acknowledgement and does not assume that all transmitted bytes were received.


## dev9 attached baselines

- `oorexxapis(20260915-170216).zip` — SHA-256 `bd12388cdb358fd8d318fcdee84f13d6b77eee81e8066b2e209a5ccb37018352`.
- `oorexx_storage_evacuation_v0.1-dev8(1).zip` — SHA-256 `1cfa0eee719808bced797d119a202b52ac3cc23ad903f98e6b5f57fb786788f4`; its `EvacPreparedSnapshotProvider` explicitly consumes a platform/filesystem-created stable snapshot root.
- current roll-up `oorexx_posix_v0.1-dev1.zip` — SHA-256 `7d13f10268b0801caeec5482601aa3af21af8f9139a553bef8a99275a7591d29`; reviewed as the POSIX metadata/xattr gap layer, not a FUSE server.

The qualification container itself has no libfuse3/fusermount3 `/dev/fuse`
surface, so dev9 makes no live-mount claim.

## dev10 native mount dependencies reviewed

- `oorexx_foreign_runtime_v0.22.6.zip`
  SHA-256 `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`
  — accepted `call-thread` synchronous callback policy reviewed; dev10 avoids
  using arbitrary FUSE worker threads as direct ooRexx callback threads.
- `oorexx_unix_socket_v0.6.zip`
  SHA-256 `aea3f193e910b216b051b046cc9ea695089e7ed67013a1a1a412d1324199e326`
  — AF_UNIX stream transport, peer/socket-path controls, mode-0600 RPC authority.
- `oorexx_api_client_v0.4.1.zip`
  SHA-256 `9542e8cb9fcdefd42f32115a63034a7cc75ce8580a1356b6f58945e3f0401c37`
  — optional bounded HTTP bridge remains compatible.


## Hercules sequential media references (dev17)

- Hercules configuration documentation: 1403/3211 line-printer output is
  variable ASCII lines; trailing blanks are removed and carriage control is
  translated to blank lines/form feeds.
- Hercules AWSTAPE documentation/source: variable blocks use 6-byte headers;
  filemarks use a header with no data. Header fields are little-endian current
  and previous segment lengths plus flags; NEWREC=0x80, TAPEMARK=0x40,
  ENDREC=0x20. AWSTAPE logical records may span multiple physical chunks.
- HET shares the AWS structure but adds compression; dev17 deliberately does
  not duplicate Hercules HET compression logic.