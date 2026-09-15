# Builder ↔ Wire UI Runtime Meeting Point — v0.11

The Builder is an authoring application above the Wire UI runtime; consumer applications are not part of this contract.

## Supported live development topology

`run_builder_studio.sh` resolves and starts the exact development stack:

```text
ooRexx 5.3.0 r13196
  -> ObjectQueueManager / Queue Fabric v0.9-dev4
  -> Wire UI Server v0.16
  -> WireUIBuilderApplication
  -> WireUIWebAccessPointBinding (same ObjectQueueManager)
  -> Queue Fabric Web Gateway v0.2
  -> Alchemy Wire UI JS v0.4-dev4
  -> browser
```

The Node host is orchestration/static/bootstrap only. It does not replace Server or Queue Fabric, and there is no Python application runtime.

The backend services the full access-point loop: claim from `WIREUI.IN.*`, dispatch through `WireUIServer`, drain Builder application outbound messages, and enqueue them to `WIREUI.OUT.*`. Merely opening a listening bridge socket is not sufficient.

## Compiled target package

v0.11 preserves the established compiled interaction package contract. Exact definitions retain `definitionId`, exact `definitionVersion`, `definitionKey`, `contentAddress`, semantic/projection/component references, profile, and material/style roles. No runtime path needs `WireUIBuilderProject` merely to serve an already published target release.

## Builder Studio application

`WireUIBuilderRuntimeFactory` takes a separate target `WireUIBuilderProject`, optional source catalogue, application/session/access-point identity, and preferably the precompiled `wire_ui_builder_studio_v0.11.json`. It binds the Studio compiled release through Server v0.16 and installs target/source state into the Studio view.

Browser form and composition actions return as normal `UI_ACTION` messages and are revalidated by the server before conversion to typed draft operations.

For related authoring facts, v0.11 uses Server v0.16 `mutateStateGroup()` with a Builder state-group projector. This keeps one semantic action coherent at the renderer boundary and avoids making rapidly-following actions stale merely because the Builder internally updated several dependent slots.

## Definition manifest invariant

Every definition instantiated by an authoritative snapshot must be authorised by the current renderer-profile manifest. The live v0.11 acceptance specifically locks `WUIB_SOURCE_FILES@1` into the DESIGN prefetch manifest because the initial Studio snapshot creates that instance even when SOURCE is not the active composition.

## Protocol version

`WIRE-UI/0.1` remains sufficient. Additive `compositions` and `compositionHints` remain renderer/preview hints; they do not change action authority, state authority, or transport semantics.
