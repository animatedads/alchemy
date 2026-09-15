# Recovery handover — Wire UI Swing v0.2-dev6

## Lineage

The supplied `oorexxapis(20260828-193048).zip` contains `wire_ui_swing_v0.2-dev3.zip`, but not the later dev5/dev6 working trees from the prior chat. The prior workstream handover records dev5 as sealed and dev6 as having reached 52/52 with current structural collection operations before its build backend disappeared; dev6 was deliberately not sealed because Server v0.17 workspace-context work remained.

This package is therefore a **semantic reconstruction and continuation**, not a claim of byte identity with the missing dev5/dev6 source trees. It was rebuilt from the preserved dev3 package plus the recovered workstream contract and requalified against the exact current uploaded runtime/API inputs.

## What is sealed here

- dev5 definition authority/cache/material/field/collection/lifecycle semantics reconstructed;
- dev6 structural collection operations retained and requalified;
- Server v0.17 authoritative `workspaceContext` event-time passthrough completed;
- 52/52 strict Java tests green;
- native ooRexx/BSF roundtrip green;
- Server v0.17 ordered/windowed collection contract green;
- Server v0.17 workspace-context server-validation contract green;
- Builder v0.11 GRID12 contract green;
- real JFrame ooRexx/BSF test green under Xvfb;
- executable JAR version, smoke-window, and no-argument launch green under Xvfb.

## Continuation boundary

Treat `wire_ui_swing_v0.2-dev6.zip` as the candidate baseline for subsequent Swing work unless explicitly superseded. Preserve the central rule: server `workspaceContext` is opaque authoritative evidence captured at event time, not local Swing state to reconstruct.
