# v0.8.1 compatibility restoration

The 2026-08-25 roll-up contains `flylo_v0.3`, whose documented qualified baseline names `wire_ui_server_v0.8.1` and whose source directly calls:

- `WireUIApplication~advanceJourney(state, trigger, evidence)`
- `WireUIApplication~createViewInstance(instanceId, definitionKey, slots, parentId)`

The roll-up does not contain a `wire_ui_server_v0.8.1` archive. The reconciled `wire_ui_server_v0.9` also lacked those methods, causing FlyLo v0.3 to fail immediately with `Object method not found: ADVANCEJOURNEY`.

A second colliding `alchemy_wire_ui_js_v0.4-dev3` branch in the same roll-up contains a cold-cache barrier specifically for revisioned `CREATE_INSTANCE` patches. Together with FlyLo's source contract, this provides executable evidence for the missing dynamic-instance seam.

v0.10 restores that seam without inventing FlyLo semantics:

1. `advanceJourney()` delegates the transition to the existing server-owned `WireUIJourneyPlan`, applies the existing differential `WireUIDefinitionPlanner`, and emits the canonical journey/manifest update.
2. `createViewInstance()` rejects any definition not registered and currently authorised by an active subscription.
3. `WireUIView~createInstancePatch()` creates the instance, increments the authoritative view revision and emits a normal `UI_VIEW_PATCH / CREATE_INSTANCE`.

No browser authority is added and `WIRE-UI/0.1` is unchanged.

Acceptance includes FlyLo v0.3.1's real WebSocket / same-manager Queue Fabric journey through SEARCH -> OFFERS -> PASSENGERS -> ASK -> EXTRAS -> REVIEW -> PAYMENT -> CONFIRMED.
