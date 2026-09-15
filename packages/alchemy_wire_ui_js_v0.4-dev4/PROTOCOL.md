# Wire UI JS v0.3.1 protocol notes

## Versioning

Package version is **v0.3.1**.

`PROTOCOL_VERSION` remains **1** and the ooRexx semantic family remains **`WIRE-UI/0.1`**. v0.3.1 is an integration-lock cut for the current server/builder baseline, not a new public wire generation.

## Direct Comms envelope

Every direct communication has:

- `protocolVersion`
- `messageId`
- `kind`
- `sequence` — contiguous for the logical access-point delivery stream
- `source`
- `destination`
- `correlationId`
- `sentAt`
- `payload`

Transport is replaceable. WebSocket is one adapter; the Queue Fabric gateway is the current browser/server bridge.

## Queue Fabric gateway ordering

Inbound frame:

```text
QUEUE_DELIVERY
    deliverySequence
    package
```

`deliverySequence` MUST be positive and contiguous for one browser/access-point delivery stream.

`QueueWorkPackage.sequence` MUST NOT be used as that stream sequence because Queue Fabric v0.9-dev3 allocates it manager-wide. It remains available as `transportMeta.queueFabricPackageSequence`.

Outbound frame:

```text
QUEUE_PUT
    queue
    correlationId
    payload = WireUIProtocol semantic message
```

## Semantic action compatibility

Ordinary actions remain:

```text
UI_ACTION
    applicationId
    sessionId
    accessPointId
    viewRef
    renderedRevision
    elementInstance
    action
    detail
```

For server v0.3 profile selection, the Queue Fabric adapter additionally projects:

```text
detail.profileId -> profile
```

only when:

```text
action = INTERACTION.PROFILE.SELECT
```

The server must still revalidate the offer, profile, revision, ownership and application state.

## Definitions

A definition is immutable for one exact `(id, version)` pair.

The JS runtime also accepts Builder v0.1 fields:

```text
definitionId
definitionVersion
definitionKey = definitionId@definitionVersion
contentAddress
profile
semanticElementRef
projectionRef
componentRef
bindings
```

There is no implicit `latest` resolution.

A live instance is not rendered until its exact definition version is installed.

## Current semantic primitive adaptation

Server/builder primitives are normalised at definition-install time. The live update path never performs this mapping.

Supported current vocabulary includes `FORM`, `MODE_SWITCH_OFFER`, `OFFER_LIST`, `OFFER_SELECTOR`, `DOCUMENT`, `SEMANTIC_RECORD` and `SEMANTIC_COLLECTION` in addition to the original basic primitives.

## View revision invariant

A patch applies only when:

```text
patch.previousRevision === runtime.currentRevision
```

Otherwise the runtime requests a fresh authoritative snapshot and does not guess missing state.

A semantic action carries `renderedRevision` so ooRexx can reject or explicitly handle stale actions.

## Render profile / immutable cache

`UI_HELLO` may advertise a capability fingerprint. A selected profile/manifest can then identify immutable definitions by exact version and content address.

Only immutable definitions are persistently cached. Live view/session state is never persisted by the Wire UI definition cache.

For `sha256:<64 hex>` addresses, content is cryptographically verified before use/storage. Existing `wui01-*` server tokens remain opaque compatibility identities.

## Subscription and journey boundary

Subscriptions are wiring; direct queues are communications.

Server v0.3 currently owns its journey planner and Queue Fabric definition-subscription wiring. Browser `UI_JOURNEY_PLAN` / named subscription reconciliation remains an optional integration mode, not a requirement for the server's internal journey implementation.

## Hot path

After installation/preparation:

```text
queue patch
    -> instance lookup
    -> precompiled named/indexed slot writer
    -> DOM/property mutation
```

No journey planning, profile inference, primitive selection or virtual-DOM reconciliation belongs on this path.
