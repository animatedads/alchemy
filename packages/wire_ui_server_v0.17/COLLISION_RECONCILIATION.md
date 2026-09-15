# v0.9 Collision Reconciliation

Two independently developed packages were both labelled `wire_ui_server_v0.8`.
v0.9 is the explicit reconciliation release; neither v0.8 archive should be treated
as a complete successor to the other.

## Input branches

### Renderer-profile / manifest branch

SHA-256:

`8ea0eae89dae8f8430b94707a9ac0b16ae9a212bc838235e091c249429498130`

Retained capabilities include:

- `WireUIRenderProfilePolicy`
- `WireUIDefinitionManifest`
- server-authoritative `UI_HELLO`
- `UI_RENDER_PROFILE`
- `UI_DEFINITION_MANIFEST`
- exact manifest/profile/content-address validation for `UI_DEFINITION_REQUIRED`
- stale-manifest rejection
- duplicate definition-delivery suppression
- deterministic parent-before-child snapshots
- renderer-profile/cache acceptance
- historical `wire_ui_queue_gateway_v0.1-dev1` integration fixtures

### Material-delivery branch

SHA-256:

`6bb22d9cdcea97a084677112f1cbfb670aec4fd07d4da1575706e7cdc23c25cd`

Retained capabilities include:

- `UI_MATERIAL_SET`
- `WireUICompiledCatalogue~materialMessages()`
- `WireUIApplication~materialSetMessages()`
- `WireUIServer~offerMaterials()`
- `WireUIServer~enqueueMaterialsToAccessPoint()`
- exact Builder material token / recipe / content-address preservation
- exact sealed site-release provenance on material messages
- Builder -> Server -> Queue Fabric material acceptance

## Merge policy

The renderer-profile/manifest branch is used as the structural base because it adds
new runtime object types and changes bootstrap/cache behaviour. Material delivery is
then merged as an orthogonal additive capability.

No `latest` resolution is introduced. `WIRE-UI/0.1` is unchanged.

The mandatory v0.9 suite runs both former-v0.8 feature sets plus
`test_v09_reconciliation.rex`, which binds one compiled release and proves its exact
site-release identity is shared by both the renderer manifest and material set.

The historical gateway fixture remains in `tests/gateway`, but is optional because it
targets `wire_ui_queue_gateway_v0.1-dev1`. Current validation is performed separately
against `oorexx_queue_fabric_web_gateway_v0.2`.
