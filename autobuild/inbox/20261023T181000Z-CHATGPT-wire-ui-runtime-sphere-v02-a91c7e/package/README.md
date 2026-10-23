# Wire UI Runtime Gopher Sphere v0.2

Authoritative continuity sphere for the Wire UI runtime/access-point layer: logical Comms, Queue Fabric gateway semantics, Web readiness, precompiled/constrained-network delivery, ResourceRef consumption and **cross-renderer semantic conformance across Web, Swing, GTK/Direct Linux and Android**.

This sphere is deliberately complementary to sibling authorities:

- `wire-ui` owns shared authoritative presentation/application semantics.
- `wire-ui-builder` owns Builder authoring/compilation continuity.
- `wire-ui-swing` owns Swing-specific EDT/JComponent/BSF mechanics.
- `wire-ui-runtime` owns runtime/access-point and cross-renderer agreement seams.

## Non-negotiable renderer rule

Web, Swing, GTK/Direct Linux and Android may present differently, but must agree on exact semantic identity, definitions, revisions, actions, bounded demand, ResourceRef authority, observation/subscription meaning, capability boundaries and fail-closed behaviour. Native widget identity is never application identity.

The executable companion `wire_ui_renderer_conformance_v0.2` defines the canonical normalized semantic transcript. A renderer is not marked PASS until a real adapter produces that transcript.

## Current evidence boundaries

- Builder integration: `wire_ui_builder_v0.12-dev1.zip`.
- Server: `wire_ui_server_v0.17.1.zip`.
- Web integration: `alchemy_wire_ui_js_v0.4-dev6.zip` (separately qualified later browser lineage is preserved, not silently substituted).
- Resource publication: `wire_ui_resource_editor_v0.3.zip` + `wire_ui_resource_contract_v0.1.zip`.
- Swing renderer: `wire_ui_swing_v0.2-dev11.zip`.
- GTK/Direct Linux archive: `wire_direct_linux_v0.1-dev38.zip`, with explicit internal version/README metadata debt.
- Android renderer checkpoint: dev7 semantic convergence evidence; resident native ooRexx host tooling separately progressed to dev16.

## Start here

- `ref.wire-ui-runtime.architecture`
- `ref.wire-ui-runtime.renderer-conformance`
- `ref.wire-ui-runtime.renderer-neutrality`
- `ref.wire-ui-runtime.resource-policy`
- `ref.wire-ui-runtime.web-readiness`
- `ref.wire-ui-runtime.current-baseline`
- `ops.wire-ui-runtime.missing-work`
- `ops.wire-ui-runtime.continuation`

## Qualification

Use LLM Gopher v0.19-dev1 or later for structural validation/lint/package and run `tests/run.sh` against the packaged sphere. The sphere is continuity authority only; it does not supersede executable renderer/runtime packages.