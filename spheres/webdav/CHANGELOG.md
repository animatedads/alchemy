# Changelog

## 0.1 continuation — 2026-10-27
- Records WebDAV dev6 candidate and HTTPS v0.4.8 integration.
- Ordinary large PUT can be streamed into the existing abort-safe staged publication session.
- Full GET can stream a StorageByteSource without whole-object materialisation.
- Local-file byte sources are source-factory backed for concurrent GET safety.
- Sequential-media PUT remains on the representation-aware path.
- Static integration PASS; runtime/live TLS gate remains pending.
- Rasen Falcon lane: `webdav-https-streaming`.

## 0.1
- Initial WebDAV engineering sphere.
- Records the real dev2 -> dev3 -> dev4 -> dev5 line.
- Captures abort-safe staged streaming publication and the HTTPS streaming-host gap.
- Records durable collection dead properties and AWSTAPE/HET boundaries.
- Records dev5 14/14 qualification and continuation work.
