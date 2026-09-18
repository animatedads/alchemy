# Provenance Ledger media adapter — dev5

The media adapter is deliberately owned by Provenance Ledger. Storage Fabric remains unchanged.

`ProvenanceMediaAdapter` wraps each archive manifest, trusted anchor, or durable ledger segment in a self-checking `PROVENANCE-MEDIA|1` envelope containing kind, logical name, exact byte length, and SHA-256 digest. It can place those envelopes into any duck-typed sequential-media image exposing `addData`, optional `addFilemark`, and `records`.

For Storage Fabric dev17 a `StorageTapeVolumeCodec` image is therefore a carrier, not ledger authority. One DATA record carries one complete provenance envelope and a FILEMARK may delimit records. Import verifies the envelope digest before exposing payload bytes. The archive manifest and ledger signatures remain the higher-level integrity/authority mechanisms.

No `::requires StorageFabric.cls` or `StorageSequentialMedia.cls` exists in the production ledger package. The real Storage Fabric dependency appears only in qualification tests.
