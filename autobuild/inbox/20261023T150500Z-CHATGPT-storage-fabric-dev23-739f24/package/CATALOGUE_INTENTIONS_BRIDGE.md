# Storage Fabric catalogue Intentions — additive candidate 3

**Scope:** additive source and test on the delivered dev21 CLI candidate 2. No change to the original Storage Fabric core, Azure Git provider, wire transport or version/API family. This is **not** an integration or supersession of the independent Storage Fabric dev24 line in the Library.

## Why

Human requests such as "find my TPS video", "bring it to this node", "put a second durable copy on Azure Git", and "add these recordings under /clients/..." belong to the existing Intention Service and Management Intention Discovery framework. Storage owns file identity, persistent namespace, replica policy, byte transfer and its own specialist relevance.

## Implementation

`src/StorageCatalogueIntentionBridge.cls` adds three adapter classes:

- `StorageCatalogueIntentionPort` composes the existing `StorageIntentionPort` and a `StorageCommandService` instance; it publishes native `StorageIntentionDescriptor` objects for `LIST`, `FIND`, `LOCATE`, `ADD`, `ANNOTATE`, `REMOVE`, `MATERIALISE` and `ENSURE_AZURE`.
- `StorageCatalogueManagementSource` supplies the `sourceId`, `discover` and `assessRelevance` contract for Management Intention Discovery v0.1-dev8. Discovery returns the **current** port surface and relevance is an inexpensive domain-local assessment; no NLP ownership or fixed global dispatcher.
- `StorageCatalogueRelevance` is a native ooRexx relevance assessment object recognized by the generic Management discovery contract.

The existing Intention Service v0.1-dev11 remains responsible for text recognition, missing-field clarification and confirmation. Caller/session identity, authenticated permissions and institutional policy must be verified by the resident controller. **Classification confidence never authorises a write.** The adapter accepts typed, already-resolved slots in a Directory, not arbitrary file names extracted from text.

## Runtime binding

```rexx
/* Domain objects are supplied by the resident grid controller. */
base = .StorageIntentionPort~new(residentStorageSurface, meshAuthority)
port = .StorageCatalogueIntentionPort~new(base, storageCommandService, meshAuthority, capabilitySource)
management = .ManagementIntentionDirectory~new
management~registerSource(.StorageCatalogueManagementSource~new(port))
result = management~resolve('locate my TPS review video')
/* The Intention Service gathers and confirms exact slots; it decides READY. */
/* An authenticated controller then calls port~invoke with a current RTO2 epoch. */
```

The controller supplies `capabilitySource~capabilities(context)` as a **fresh** Directory of booleans. `LIST`, `FIND`, `LOCATE`, `ADD`, `ANNOTATE`, `REMOVE`, `MATERIALISE` and `ENSURE_AZURE` are individually advertised only if the operation can actually run, with provider health, socket/peer connectivity, access control and institutional policy reflected in the current result. Do not hardcode all flags to true. Missing flags mean unavailability; `ENSURE_AZURE` requires an actually configured, usable Azure Git provider. A vanished capability vanishes from the next discovery and cannot be invoked from a stale suggestion.

Every new mutation additionally requires a non-nil Storage mesh authority in `ACTIVE` role, a supplied matching `expectedEpoch`, and explicit `arguments['CONFIRMED']=.true`. The existing Storage authority/provider then enforces its independent data-plane policy. Catalogue reads are available on `SPARE` nodes while mutations are not. `FORENSIC` access and cross-node ACLs remain controller/transport gates, not something this bridge establishes.

The new `REMOVE` intention invokes `removeBinding(virtualPath,namespace,.false)` only. It **never** requests catalogue forgetting, provider eviction, physical deletion or Azure Git removal. `ENSURE_AZURE` delegates to existing `StorageCommandService~ensureAzure` rather than implementing Git writes itself. `MATERIALISE` delegates to the existing verified materialisation seam; the standalone CLI still does not have an authenticated cross-node peer connection.

`FIND` searches current catalogue names, object IDs and extended attributes, plus virtual paths when the command exposes its retained namespace snapshot. `LOCATE` uses the exact/ambiguity-aware catalogue lookup and returns existing Storage objects; it does not pretend that last-known availability proves a currently reachable node. No bytes are moved by discovery.

## Native tests

`tests/test_storage_catalogue_intention_bridge.rex` exercises the installed ooRexx 5.3.0 r13196 interpreter with Management Intentions dev8. It covers per-call capability changes, discoverability of reads and writes, Manager specialist selection, authority-epoch fencing, explicit confirmation, removal retaining bytes, Azure intent delegation to the existing command method, provider withdrawal, and SPARE mutation disappearance.

## Outstanding integration gates

1. Reconcile divergent dev21 CLI and dev24 Storage Fabric provider/source package line; do not merge by filename or version assumptions.
2. Bind the capability source to actual resident service/provider health, ACL and per-turn authority evidence.
3. Connect this provider to the Intention Service dev11 confirmation/slot-resolution host and its authenticated event dispatcher.
4. Qualify real ed209 MI/MU XTP peer discovery and materialisation, and live Azure DevOps Git retention/verification; neither is proven by this adapter test.
