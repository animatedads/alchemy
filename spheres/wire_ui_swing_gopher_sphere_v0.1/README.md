# Wire UI Swing Gopher sphere v0.1

Authoritative project sphere for the defensive Java Swing renderer of compiled `WIRE-UI/0.1` journeys.

It records the renderer-neutral Builder boundary, Swing EDT/action discipline, transactional rendering, exact definition/manifest authority, semantic materials, GRID12 mapping, collection/window patch semantics, Server v0.17 workspace command/result context, ooRexx/BSF4ooRexx integration, desktop lifecycle, qualification evidence and continuation policy.

The sphere deliberately does **not** make Swing a journey/business/permission authority. Generic Java/Swing language rules remain in the separate `java` sphere; this sphere owns Wire-specific renderer and project continuity knowledge.

## Load and use

```sh
gopher sphere load wire-ui-swing --override wire_ui_swing_gopher_sphere_v0.1.zip
gopher --profile wire-ui-swing context wire-ui-swing --full
gopher --profile wire-ui-swing search workspaceContext --sphere wire-ui-swing
gopher --profile wire-ui-swing search GRID12 --sphere wire-ui-swing
gopher --profile wire-ui-swing search 'sealed dev5' --sphere wire-ui-swing
```

## Current continuity statement

The exact `oorexxapis(20260828-191940).zip` roll-up (SHA-256 `5885f1906dc5ae7307e6fc7d557b88d1770b0c401f5a62063b999834222d5d66`) carries:

- Wire UI Server v0.17 — nested ZIP SHA-256 `82c3a9d270d123dcbedabed1b57ed5e0944b828b1a184a5b71d47d9f9f188441`
- Wire UI Builder v0.11 — nested ZIP SHA-256 `dd48908e49e8ee00c94f931c3a1cfdfc8d5324e2e0fbf64e2cdd7d82c510ad3f`
- Alchemy Wire UI JS v0.4-dev4 — nested ZIP SHA-256 `f7649a521de7ff9b619cc230e74d77fc2c8ae31884d5ce97c649bd862c41d205`
- Wire UI Swing v0.2-dev3 — nested ZIP SHA-256 `10823e3937eb02104c42b8990cef6349c4b587b5dbe198766d64804d89cbe9d3`

`wire_ui_swing_v0.2-dev11.zip` (SHA-256 `294be3939be9ff0fc32c057c1d7e0287ba7d3f074fdda9663c6da48fe9bd8ad7`) is the current source-qualified continuation baseline. Dev10 (`db8e19d5e79c9a95f6491ba8f48544e299fe220cfbbd2a700eeb31d07bb001ee`) remains the full semantic/runtime qualification baseline; dev11 is a presentation-only successor with 59/59 strict renderer tests, Xvfb NotNotes smoke and actual desktop visual qualification.


## Current NotNotes Java presentation

The NotNotes fixture is now an explicit visual/conformance target. Java/Swing should approach the web client's presentation quality while remaining a renderer: projected document label, stable identity and projected status may be styled into hierarchy and chips, but documents, relationships, lifecycle, reports, intentions and action feasibility remain outside Swing.

Large document collections use the same bounded virtual-window contract as other Wire collections: renderer viewport movement emits `RangeRequested(start,count)` and only the application/server supplies replacement rows.
