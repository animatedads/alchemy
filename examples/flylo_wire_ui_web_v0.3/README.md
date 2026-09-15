# FlyLo Wire UI browser projection v0.3

A replacement for the hand-authored interactive FlyLo demo shell.

This package deliberately contains **no booking/search/offer/assistant business actions**. The interactive region is owned by the versioned Wire UI release served by FlyLo/Wire UI Server. The shell provides branding, layout, CSS recipes for the current FlyLo material/style roles, and browser runtime bootstrap only.

## Preferred bootstrap: one browser-safe URL

The normal deployment path no longer duplicates application/session/access-point IDs or queue names into the page. The host injects only a browser-safe bootstrap URL:

```json
{
  "bootstrapUrl": "/wire-ui/bootstrap?token=SERVER_ISSUED_ACCESS_POINT_TOKEN"
}
```

`bootstrap-config.js` fetches that document with same-origin credentials and `cache: no-store`. Queue Fabric Web Gateway v0.2 can serve the bootstrap from the exact `WireUIServer`/application binding.

The returned document contains:

- `moduleUrl`
- `gatewayUrl`
- `outboundQueue` — the browser's fixed PUT queue (`WIREUI.IN.<access-point>`)
- `siteId`
- `ownership.applicationId`
- `ownership.sessionId`
- `ownership.accessPointId`

No Queue Fabric claim token, Queue Fabric principal credential, private bridge token, payment credential, or AI/provider secret belongs in this browser configuration.

An explicit inline configuration remains supported for simple/static test deployments; see `web/config.inline.example.json`.

## Material is now authoritative

The shell creates the generic JS `MaterialController`. `FLYLO_MATERIAL@1` tokens delivered by Wire UI Server v0.8 become `--wui-*` CSS custom properties. The shell CSS uses those properties for FlyLo brand colours, surface colour and control radius, with local fallback values only for pre-connection/error rendering.

This removes the live duplicate visual truth: changing a versioned Builder material token can change the rendered FlyLo projection without editing the browser shell. Semantic recipe identifiers remain governed by the component/style library rather than being executed as server-provided CSS.

## Runtime

The bootstrap constructs:

- `QueueFabricGatewayTransport`
- `Comms`
- `DefinitionRegistry`
- `BrowserRenderer`
- `RenderProfileController`
- `WireUIRuntime`
- `WireUIJourneyController`
- `ObservationPlan`

and then waits for server-authored definitions/snapshots.

The supplied Alchemy Wire UI JS v0.4-dev3 generic renderer supports the current FlyLo primitives without FlyLo-specific client logic:

- `FORM` -> bound labelled inputs and configured semantic submit action
- `OFFER_LIST` -> actionable collection returning only server-issued identity plus index
- `SEMANTIC_RECORD` -> bound record fields; a `message` binding becomes an input and the configured semantic action becomes the Send control

Thus Ask FlyLo can render and emit `ASSISTANT.ASK` through the same semantic runtime without a hard-coded assistant button/action in this shell.

The CSS styles the current Builder roles (`hero.search`, `utility.card`, assistant/legal roles) through renderer-emitted `wui-*` classes. Material compilation into a browser-native stylesheet remains a future Builder/compiler improvement; this shell is a visual projection adapter, not a second application model.
