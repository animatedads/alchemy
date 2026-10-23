# Storage Fabric catalogue discovery over the existing mesh

`StoragePeerService` handles `CATALOGUE_LIST` and `CATALOGUE_LOCATE` using the **same authenticated StoragePeer contract** as its existing HELLO/HAVE/STAT/READ. Candidate3 hardens discovery: direct `handle(request)` is explicitly rejected with `AUTHENTICATED_PEER_REQUIRED`; network bindings must supply an independently authenticated node ID using `handleFrom(authenticatedPeerId, request)`. The existing QueueRexx server adapter uses `handleFrom` and remains compatible. There is no parallel RPC transport or alternate wire protocol. The existing QueueRexx/XTP peer channel transports request/response directories and must authenticate the network source via `handleFrom(authenticatedNode, request)`.

*Discovery is opt-in.* Until `configureCatalogue` is called with a read-only source and a named allowlist, responses are `DISCOVERY_NOT_CONFIGURED`. Unauthorised nodes receive `DISCOVERY_NOT_AUTHORISED`. `StorageMeshAuthority~canServePeerRead` may guard replies. The configured source should be an independent read-only `StorageCommandService` over the shared durable authority; each query reloads its latest committed checkpoint and fails if that checkpoint cannot be loaded.

Request fields added to the existing StoragePeer request envelope:
- `operation`: `CATALOGUE_LIST` or `CATALOGUE_LOCATE`;
- `query`: substring search (LIST) or exact StorageRef/name/virtual path (LOCATE);
- `offset`: zero-based index (LIST); `limit`: 1..100;
- `expected_revision`: optional revision pin for stable pagination, default -1.

Responses echo existing contract metadata and include `payload.items`, `payload.revision`, `payload.node_id`, `payload.offset`, `payload.more` and optionally `payload.role`/`payload.epoch`. Every item includes `id`, `digest`, `name`, `size_bytes`, `media_type`, `description`, `paths`, `tags`, `metadata`, and recorded location evidence without filesystem locators. StorageRefs retain content identity; filenames and virtual paths remain projections. `REVISION_CHANGED` is a hard failure: restart the paginated lookup against the new revision. Discovery reports *retained location observations*, never asserts live reachability; use HAVE/STAT and the materialiser to prove a particular copy exists.

An existing peer controller can use:

```rexx
reader = .StorageCommandService~new(stateRoot, localNode)
peerService = .StoragePeerService~new(localNode, exportRegistry)
peerService~configureCatalogue(reader, .array~of('ed209b','ed209f'), meshAuthority)
/* Register peerService as the delegate of the existing QueueRexx server. */

client = .StoragePeerClient~new('ed209b', authenticatedPeerTransport)
r = client~catalogueList('ed209c', 'initech', 0, 50)
/* Pin pagination to r['payload']['revision'] and continue while more is true. */
found = client~catalogueLocate('ed209c', '/customers/initech/tps/review.mp4')
```

**Deployment work remaining:** supply an authorised estate reader ACL; wire the node-side source into the already deployed QueueRexx server; configure the authenticated peer transports for all intended MI/MU routes, respecting established XTP carriers and RTO2 leadership; fan out queries and reconcile revisions/coverage for a mesh-wide CLI report; run live connectivity/denial/staleness tests. No code in this package silently selects a different carrier or pretends an unresponsive peer has been searched.

## Bounded multi-MU composition (candidate4)

`StorageMeshCatalogueSearch` uses a controller-supplied, policy-admitted set
of peer IDs to call the existing authenticated `StoragePeerClient`. It pins
revisions, reports per-MU coverage, and fails an incomplete search closed.
It does not make a standalone `storage list` mesh-wide or grant discovery ACLs.
See `MESH_CATALOGUE_FANOUT.md` and the native test.
