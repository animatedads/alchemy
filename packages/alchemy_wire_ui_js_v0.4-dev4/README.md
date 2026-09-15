# Alchemy Comms + Wire UI JS v0.4.0-dev.4

> **v0.4-dev4:** reconciles the two colliding dev3 lines: versioned Builder material delivery plus FlyLo full-booking primitives/dynamic-instance cold-cache handling.


Browser/access-point implementation of the Alchemy logical Comms object and Wire UI runtime.

Package v0.4.0-dev.4 is a **reconciled material + full-booking rich-rendering development cut** retaining the established Wire UI integration lock and protocol generation 1 / `WIRE-UI/0.1`. Gateway ACK/result frames remain transport framing rather than application semantics.

## v0.4-dev4 reconciliation

Two independently produced archives were both named `alchemy_wire_ui_js_v0.4-dev3`:

- material branch SHA-256 `d1851655daee3ff882ca7f948a5ea06111e1c8faecc7431882f52ef504f62d45`;
- FlyLo full-booking branch SHA-256 `05a19d07ec9a8802dcf654123b4a474633542fcfb962f3e2093d7c5f0ed675be`.

v0.4-dev4 retains both. It adds `CHOICE_LIST` and `TOKEN_FORM`, keeps exact material delivery, separates semantic interaction profile from renderer profile, and queues revisioned `CREATE_INSTANCE` patches behind missing immutable definitions rather than forcing a false resync.


## Versioned material runtime

`MaterialController` listens for `UI_MATERIAL_SET` and maps the exact Builder material token set to browser CSS custom properties (`--wui-*`). It retains the material content address and semantic recipe map, rejects mutation of an already-seen `materialId@version`, and removes token properties that disappear when a new material version is selected.

Recipe strings such as `brand.hero/search.card` remain semantic design-system identifiers. They are **not** interpreted as arbitrary CSS from the server. The browser shell/component library decides how known recipes/style roles consume the versioned token vocabulary.

## Architectural rules

- **Subscription** = authorised wiring: definitions, observation plans and journey capability preparation.
- **Direct queue** = actual communications/events.
- **Server state is authoritative**; browser state is a semantic projection plus ephemeral presentation state.
- Definitions are installed/prepared once; routine rendering is direct `instance + slot + value` mutation.
- Journey planning and interaction-profile selection remain server-authoritative.
- Persistent browser storage contains only immutable definitions, never live session/UI state.

## v0.4 server integration baseline

- validated against Wire UI Server v0.4, Builder v0.1, Queue Fabric v0.9-dev3 and Alchemy Objects v0.6;
- the complete Wire UI Server v0.4 runner, including its real ooRexx↔Node cross-process fixture, passes against this development cut;
- accepts the expanded server/builder primitive vocabulary, including `FORM`, `MODE_SWITCH_OFFER`, `OFFER_LIST`, `DOCUMENT`, `SEMANTIC_RECORD` and `SEMANTIC_COLLECTION`;
- aligns explicit machine-profile selection with the server v0.3 top-level `profile` field at the Queue Fabric boundary;
- accepts Builder v0.1 exact `definitionVersion` / `definitionKey` identities without implicit latest resolution;
- preserves optional site-release/projection/component metadata for the next exact-release runtime seam.


### Gateway reliability development seam

A real gateway must not ACK a claimed Queue Fabric package merely because bytes were written to a WebSocket. v0.4-dev1 therefore supports opaque delivery acknowledgements:

```text
Queue Fabric CLAIM
      ↓
gateway QUEUE_DELIVERY + opaque deliveryId
      ↓
Comms semantic dispatch completes
      ↓
QUEUE_DELIVERY_ACK
      ↓
gateway Queue Fabric ACK
```

If semantic dispatch throws, JS sends `QUEUE_DELIVERY_NACK` instead. Queue Fabric claim tokens never enter browser code.

Outbound `QUEUE_PUT` also carries `clientPutId`; an optional `QUEUE_PUT_RESULT` handshake can be required for operations that need proof that the gateway accepted the PUT. See `GATEWAY_PROTOCOL.md`.

## v0.3 additions

### One-time render profile negotiation

`RenderProfileController` advertises a capability fingerprint during `UI_HELLO`. The server selects a render profile such as a capability/display class and replies with `UI_RENDER_PROFILE` / `UI_DEFINITION_MANIFEST`.

The hot render path never performs browser-brand or viewport compatibility branching.

### Content-addressed definition cache

Immutable definitions can be retained in `LocalStorageDefinitionCache` or another implementation of the same async cache interface. A manifest identifies definitions by site, render profile, version and content address.

Warm bootstrap therefore becomes:

```text
UI_HELLO + capability fingerprint
        ↓
selected render profile + manifest
        ↓
load matching immutable definitions locally
        ↓
request cache misses only
        ↓
fresh authoritative UI snapshot
```

For addresses of the form `sha256:<64 hex>`, the browser verifies the definition content before using or storing it. Earlier ooRexx `wui01-*` tokens remain supported as opaque compatibility identities.

### Queue Fabric gateway transport

`QueueFabricGatewayTransport` gives a browser a narrow WebSocket bridge to Queue Fabric without exposing queue-manager CLAIM/ACK/NACK mechanics to application code.

Outbound:

```text
QUEUE_PUT
    queue
    correlationId
    semantic payload
```

Inbound:

```text
QUEUE_DELIVERY
    deliverySequence   ← contiguous for this access point
    package            ← QueueWorkPackage-shaped delivery
```

**Important:** Queue Fabric `QueueWorkPackage~sequence` is manager-wide and may have gaps for any one browser queue. It is therefore transport provenance, not the Comms reorder sequence. The gateway must assign a contiguous per-access-point `deliverySequence`.

### Existing v0.2 journey behaviour retained

- differential subscription reconciliation;
- ACTIVE and PREFETCH activation;
- ON_DEMAND remains dormant until explicitly requested;
- explicit `INTERACTION.PROFILE.SELECT` semantic action;
- server-authored journey/profile projection only.

## Main modules

- `src/comms.js` — ordered logical direct queue, subscription reconciliation.
- `src/profile.js` — capability detection/fingerprint.
- `src/render-profile.js` — render-profile and definition-manifest bootstrap.
- `src/content-address.js` — canonical SHA-256 definition verification.
- `src/queue-fabric-gateway-transport.js` — browser ↔ Queue Fabric gateway framing.
- `src/oorexx-queue-adapter.js` — QueueWorkPackage/semantic-envelope mapping.
- `src/observations.js` — positive-list observation capture.
- `src/wire-ui/definition-cache.js` — immutable definition caches.
- `src/wire-ui/definition-registry.js` — immutable installed definitions.
- `src/wire-ui/browser-renderer.js` — once-per-definition compilation to factories/direct slot writers.
- `src/wire-ui/runtime.js` — snapshots, patches, semantic actions and resync.
- `src/wire-ui/journey-controller.js` — server journey-plan executor.

## Example bootstrap

```js
const definitions = new DefinitionRegistry();
const renderer = new BrowserRenderer({ definitions, mount });
const cache = new LocalStorageDefinitionCache();

const profile = new RenderProfileController({
  comms,
  definitions,
  renderer,
  definitionCache: cache,
  siteId: 'OurLadyAir'
});

new WireUIRuntime({
  comms,
  definitions,
  renderer,
  renderProfile: profile,
  serverSemantic: true,
  ownership: { applicationId, sessionId, accessPointId }
});

await comms.connect(profile.helloPayload({ applicationId, accessPointId }));
```

## Validation

```sh
npm run check
npm test
npm run benchmark
```

The benchmark is a local microbenchmark of direct slot mutation through the deterministic renderer. It is useful for regression detection; it is **not** a React comparison or a substitute for browser/application benchmarks.
