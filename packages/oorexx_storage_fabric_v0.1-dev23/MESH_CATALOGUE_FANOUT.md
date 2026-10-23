# Storage Fabric multi-MU catalogue search — candidate4

`src/StorageMeshCatalogueSearch.cls` composes the existing authenticated
`StoragePeerClient~catalogueList` surface. It creates no transport, packet
codec, independent Storage authority, replica claim, placement lease, or new
XTP service. Input peers must already have passed caller-/customer-specific
policy admission by the resident host controller. This class is not an ACL
checker and does not authorize fanout to any other customers' MUs.

## API

```
client = .StoragePeerClient~new('ed209b', authenticatedQueueRexxPeerTransport)
peers = .array~of('ed209c','ed209d')  /* approved, not all reachable by default */
search = .StorageMeshCatalogueSearch~new(client, peers)
report = search~search('Initech',25,8)
```

`report` is a Directory containing `ok`/`complete` (true only if EVERY
requested MU completes), `code` (`OK`/`PARTIAL`), `nodes`, `record_count`,
`records` (each row: `node_id`, `revision`, `item`), `coverage` keyed by MU.
Coverage rows contain `node_id`, `code`, `pages`, `revision`, `accepted`.
Individual failure codes such as `UNREACHABLE`, `DISCOVERY_NOT_AUTHORISED`,
`REVISION_CHANGED`, `INVALID_RESPONSE`, or `TRUNCATED` are retained.

Queries are read-only and limited to 1..64 admitted peer IDs, 1..100 records
per page and 1..100 pages per node. Every follow-on page supplies the previous
page's exact revision. Changed revision, invalid origin, zero-progress page or
unreachable peer invalidates all results from that MU; complete peer results
remain available as PARTIAL with accurate node provenance. No remote result is
claimed to prove fresh bytes, durable replica status, or a valid placement.

## Tests

- `tests/test_storage_mesh_catalogue_search.rex`: two authorised MUs, origin,
  empty peer, unauthorized remote, unreachable node, bounded truncation,
  revision mismatch and forged origin payload.
- `tests/test_storage_mesh_catalogue.rex`: rejects unauthenticated direct
  catalogue calls; tests ACL, paging, redaction and revision checks.
- `tests/test_storage_catalogue_intention_bridge.rex`: dynamic advertised
  capabilities, management relevance, epoch guards, explicit confirmation,
  non-physical path unbinding, provider withdrawal and SPARE read-only mode.

Use both `REXX_PATH=.../src:.../package_root:<management_dev8_src>` and the
supplied ooRexx 5.3.0 r13196 runtime when testing the intention bridge.

**Not qualified:** live ed209 Storage Peer QueueRexx binding, real multi-MU
catalogue fanout, hosted policy/secret integrations, live Azure Git retention,
biometric analysis and job acceptance. These require Codex execution.
