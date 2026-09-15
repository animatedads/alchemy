# ooRexx Wire UI integration notes — JS v0.4.0-dev.4

## Integration baseline

Validated on 2026-08-24 against:

- `wire_ui_server_v0.4` integration-lock cut
- `wire_ui_builder_v0.1`
- `oorexx_queue_fabric_v0.9-dev3`
- `alchemy_objects_v0.6`
- `oorexx_crypto_v0.1`
- ooRexx 5.3.0 r13196 supplied debug build

The complete packaged Server v0.4 runner passes with this JS development cut, including the real ooRexx↔Node OurLadyAir cross-wire fixture. Server v0.4 now owns exact `definitionId@version` identity end-to-end and directly accepts `detail.offerId` / `detail.profileId`; the old browser-side top-level compatibility projection remains harmless but is no longer required for server correctness.

## Stable architectural boundary

- subscriptions are wiring, not the live application event bus;
- direct queues carry live UI traffic;
- ooRexx owns application state, action authority, journey state and semantic profile;
- UI actions carry the rendered revision;
- missing view revisions cause resynchronisation;
- immutable definitions are prepared once and live rendering is direct slot mutation;
- the browser does not infer customer journeys or silently change interaction profile.

## Queue Fabric delivery ordering

`QueueWorkPackage~sequence` is manager-wide in Queue Fabric v0.9-dev3. It is transport provenance and may contain gaps on a single Wire UI OUT queue.

The browser Comms reorder sequence is therefore supplied by the gateway as a separate positive contiguous `deliverySequence` for one access-point delivery stream.

```text
QUEUE_DELIVERY
    deliverySequence = 17       <- Comms ordering
    package.sequence  = 991      <- Queue Fabric provenance
```

The JS adapter preserves the latter as `transportMeta.queueFabricPackageSequence`.

## Wire UI Server semantic primitive vocabulary

The compatibility adapter now accepts the server/builder primitives currently present in the roll-up:

```text
PANEL / CONTAINER      -> container
TEXT / STATUS          -> text
ACTION_BUTTON / BUTTON -> button
MODE_SWITCH_OFFER      -> button
INPUT                   -> input
FORM                    -> form
LIST / OFFER_LIST       -> list
OFFER_SELECTOR          -> list
DOCUMENT                -> document
SEMANTIC_RECORD         -> semantic-record
SEMANTIC_COLLECTION     -> list
```

This translation occurs once when a definition is installed. Routine patch application still performs no primitive selection.

`FORM` actions compile to a local `submit` handler with browser default submission suppressed; the semantic action is then sent through the direct queue.

Machine-semantic primitives remain semantic projections, not a second business API. An AI access point may invoke the same semantic actions without relying on decorative DOM interaction.

## Interaction-profile selection lock

Wire UI Server v0.10 accepts the JS-native detail shape directly and also tolerates the compatibility top-level projection:

```text
UI_ACTION
    action  = INTERACTION.PROFILE.SELECT
    profile = AI_AGENT_OPTIMISED
```

The JS journey controller keeps offer evidence grouped in `detail`:

```text
detail.offerId
detail.profileId
detail.agentRef ...
```

The current adapter still projects only `detail.profileId` to top-level `profile` for backward compatibility with Server v0.3. Server v0.4 no longer depends on that projection. Arbitrary detail fields are not flattened.

## Definition completeness invariant

Every exact definition referenced by a live snapshot or `CREATE_INSTANCE` must either already be known by the access point or be obtainable from the definition-delivery wiring.

The JS runtime blocks an incomplete snapshot and requests missing definitions. It never invents a generic fallback.

## Builder v0.1 exact-version contract

Builder v0.1 deliberately compiles exact identities:

```text
definitionId      = OLA_SEARCH_FORM
definitionVersion = 2
definitionKey     = OLA_SEARCH_FORM@2
```

JS already stores definitions as exact `(id, version)` keys. v0.3.1 also accepts builder-shaped `definitionVersion` / `definitionKey` fields and preserves projection/component/binding metadata.

There is no browser-side `latest` resolution.

**Resolved in Server v0.4:** definitions, subscriptions and view instances now preserve exact `definitionId@version`; multiple versions may coexist and bare IDs do not resolve implicitly.

## Site release / replay seam

The compatibility adapters preserve optional `releaseRef` / `siteReleaseRef` fields on snapshots and patches when present. Builder v0.1 requires eventual binding of rendered evidence/actions to an exact immutable site release. Wire UI Server v0.10 still does not emit this context. Exact definition identity is now solved; exact immutable site-release binding remains the next Builder→Server evidence seam.

## Journey ownership

Server v0.4 owns `WireUIJourneyPlan` and applies ACTIVE/PREFETCH/ON_DEMAND subscriptions differentially. Its Queue Fabric adapter wires active definition subscriptions to the access point definition queue.

`WireUIJourneyController` remains an optional browser-side executor for deployments where a server-authored journey plan is explicitly projected to the client. It is **not required** for the current v0.4 server's internal planner and must not be treated as a competing journey authority.

ON_DEMAND remains a request, never local authority.

## AlchemyObject

AlchemyObject adoption is a server-side house-model concern. Browser objects do not mimic AlchemyObject. Identity/provenance crosses the access-point boundary only when defined by the semantic protocol.

## Gateway reliability seam (JS v0.4-dev1)

Server v0.4 exposes Queue Fabric queues but does not itself implement the browser WebSocket gateway. The next gateway must retain the Queue Fabric package/claim-token privately and expose only an opaque `deliveryId` to the browser. JS acknowledges that delivery only after semantic dispatch completes. See `GATEWAY_PROTOCOL.md`.

## v0.4-dev4 dynamic-instance integration

A revisioned `CREATE_INSTANCE` may arrive before its immutable definition on a cold cache. The runtime queues that patch and requests the exact missing definition, preserving patch order. `CHOICE_LIST` and `TOKEN_FORM` are compiled once from Builder/server metadata; no FlyLo business authority is moved into JS.
