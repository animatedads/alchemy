# Changelog

## v0.4.0-dev.4

- Reconciles the two colliding v0.4-dev3 lines.
- Retains exact versioned `UI_MATERIAL_SET` / `MaterialController` support.
- Adds `CHOICE_LIST` and `TOKEN_FORM` precompiled semantic primitives required by FlyLo v0.3.
- Separates semantic interaction profile identity from negotiated browser render profile identity.
- Adds a cold-cache definition barrier for revisioned `CREATE_INSTANCE` / `LIST_APPEND` patches.
- Keeps server-owned identities hidden/read-only in generated forms and returns boolean choice state explicitly.
- `WIRE-UI/0.1` remains unchanged.


## 0.4.0-dev.3

- Adds `UI_MATERIAL_SET` and `MaterialController` for exact versioned Builder material delivery.
- Applies material tokens only as `--wui-*` CSS custom properties; material recipes remain semantic recipe identifiers and are not executed as arbitrary CSS.
- Rejects an immutable material identity if the same `materialId@version` arrives with a different content address.
- Removes stale CSS token properties when switching to a different material version.
- Validated 41/41 JS tests plus the real Queue Fabric FlyLo SEARCH -> OFFERS -> SELECTION -> ASK browser acceptance.


## 0.4.0-dev.2

- Adds rich Builder/server semantic rendering without adding FlyLo business logic to the generic renderer.
- `FORM` bindings compile to labelled typed inputs and submit the current field values as the configured semantic action detail.
- `OFFER_LIST` / list-family actions render actionable collection items and return only a server-issued item identity plus display index.
- Preserves `styleRole` after rich semantic composition.
- Adds diagnostic render-root identities for exact definition/profile/semantic/projection/component/material correlation; these are observation metadata, not authority.
- Adds FlyLo renderer acceptance for search form, actionable offers, and rich-root style-role preservation.
- Keeps Queue Fabric gateway ACK/NACK / `clientPutId` / `QUEUE_PUT_RESULT` protocol unchanged from dev1.
- Validated 38/38 JS tests and unchanged Wire UI Server v0.7 suite against Alchemy Objects v0.8.

## 0.4.0-dev.1

- Validates unchanged cross-wire semantics against Wire UI Server v0.4.
- Adds opaque gateway `deliveryId` ACK/NACK support after Comms semantic dispatch.
- Keeps Queue Fabric claim tokens gateway-private.
- Adds optional `QUEUE_PUT_RESULT` acceptance/rejection correlation via `clientPutId`.
- Adds gateway PUT result timeout/close rejection handling.
- Retains compatibility with v0.3 gateway deliveries that do not carry `deliveryId`.
- Adds five gateway reliability contract tests; JS suite is 35/35 passing.
- Records that immutable site-release binding remains a separate Builder→Server runtime seam.


## 0.3.1

- Integration-lock cut against `wire_ui_server_v0.3` and `wire_ui_builder_v0.1`.
- Expands the ooRexx semantic primitive adapter for the current OurLadyAir/server/builder vocabulary.
- Compiles `FORM` actions as semantic submit operations rather than generic click handling.
- Projects `detail.profileId` to the server v0.3 top-level `profile` field only for `INTERACTION.PROFILE.SELECT`.
- Accepts Builder v0.1 exact `definitionVersion` / `definitionKey` references and retains semantic/projection/component/binding metadata.
- Aligns the human interaction profile name with server v0.3 `HUMAN_VISUAL`.
- Documents that current server v0.3 journey planning is server-internal and does not require the optional browser journey controller.
- Records the remaining server migration seam: exact version-qualified definition references/site release binding.

## 0.3.0

- Adds one-time `RenderProfileController` capability/profile negotiation.
- Adds `UI_RENDER_PROFILE` and `UI_DEFINITION_MANIFEST` bootstrap seams.
- Adds persistent immutable definition cache interface with memory and localStorage implementations.
- Adds SHA-256 verification for cryptographically content-addressed definitions.
- Warm manifests load cached definitions and request only misses.
- Adds Queue Fabric gateway WebSocket transport/framing.
- Corrects Queue Fabric ordering semantics: manager-wide `QueueWorkPackage~sequence` is retained as provenance; gateway supplies contiguous per-access-point `deliverySequence` for Comms ordering.
- Browser outbound semantic payloads retain the browser `commsSequence` for provenance/server-side future use.
- Adds render/cache/gateway contract tests and a slot-mutation regression benchmark.

## 0.2.0

- Retains protocol generation 1 / existing `WIRE-UI/0.1` snapshot-patch-action compatibility.
- Adds differential `Comms.reconcileSubscriptions()`.
- Adds `WireUIJourneyController` for server-authored ACTIVE/PREFETCH/ON_DEMAND plans.
- ON_DEMAND capabilities remain inactive until an explicit named request.
- Adds interaction-profile offers and explicit `INTERACTION.PROFILE.SELECT` semantic action support.
- Adds a public revision-bearing `WireUIRuntime.sendSemanticAction()` seam.
- Coalesces repeated identical missing-definition requests while awaiting definitions.
- Adds journey/profile functionality to automatic acceptance.

## 0.1.1

- Added current ooRexx v0.1 semantic definition/snapshot/patch adapters.
- Added Queue Fabric envelope mapping helpers.
- Preserved semantic named slots while compiling to direct browser writers.
