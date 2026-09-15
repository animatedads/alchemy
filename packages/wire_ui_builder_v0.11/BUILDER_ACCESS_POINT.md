# Builder Access Point — v0.11

A human browser and an AI/programmatic author use the same semantic mutation model. The supported live development entry point is `./run_builder_studio.sh`; serving `web/` with Python or another generic static server does not start the application runtime.

## First-party live path

```text
run_builder_studio.sh
  -> ooRexx builder_live_backend.rex
       -> one ObjectQueueManager
       -> WireUIServer v0.16
       -> WireUIBuilderApplication
       -> WireUIWebAccessPointBinding on that SAME manager
  -> official Queue Fabric Web Gateway v0.2
  -> Builder/Alchemy Wire UI JS browser shell
```

The private gateway bridge and `WireUIServer` must share the same in-process Queue Fabric manager. Starting a second queue manager, or starting only an HTTP server, creates a superficially loaded page with no authoritative authoring session.

## Human path

```text
rendered Builder Studio
  -> UI_ACTION
  -> Queue Fabric Web Gateway
  -> shared Queue Fabric manager
  -> Wire UI Server validation
  -> WireUIBuilderApplication
  -> WireUIDesignOperation
  -> target WireUIBuilderProject
```

## AI/programmatic path

```text
typed proposal/tooling
  -> WireUIDesignOperation
  -> target WireUIBuilderProject
```

Both paths use project compare-and-swap revision semantics. The Builder action adapter is not an authentication boundary; the owning Wire UI application/server authorises the subject before mutation logic.

## Visual manipulation path

```text
canvas select / drag / span / region / alignment
  -> COMPOSITION.SELECT or DESIGN.COMPOSITION.MOVE / RESIZE / RELOCATE / ALIGN
  -> Server action binding / revision / ownership validation
  -> WireUIBuilderApplication
  -> typed WireUIDesignOperation
  -> target composition draft
```

Selection and direct manipulation remain separate semantic actions on the same canvas instance. DOM/CSS is renderer output, never authoring authority.
