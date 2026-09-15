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

A separately sealed `wire_ui_swing_v0.2-dev5.zip` (SHA-256 `a75f79844711c583e1ee4f3a8efa24ea533bfbdd81aa9153376faeeb36efc271`) is newer than the roll-up Swing artifact and is the current implementation recovery baseline. A successor must be requalified against Server v0.17 + Builder v0.11 before superseding it.
