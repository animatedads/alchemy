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
