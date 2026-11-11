# DOCY shared mutations — v0.2c

Architecture: Tom Dyer (DOCY shared-node and layered-event model).
Implementation: ChatGPT. Qualification: ooRexx 5.3.0 r13196.

## Added graph operations

- `graph~planPlacementAdd(documentKey, placementKey, nodeKey, ordering, parentKey, author, reason)`
- `graph~planOverrideChange(documentKey, layer, nodeKey, attribute, datum, author, reason)`

Both return a `DocyPlan` and **do not mutate** the graph. A rejected plan collects STOP diagnostics. An accepted `graph~apply(plan)` advances the graph revision and adds a predecessor-linked event. Stale plans are rejected. Duplicate inherited placement keys, missing nodes/documents and invalid override layers produce STOP.

The impact planner computes all affected output paths through the template inheritance chain. A shared template placement reaches its descendants even when the placed node did not previously appear in them. Template-layer overrides propagate to inheriting documents; document, project and variant overrides are local to their document in the current resolver semantics. When a lower-level template change is hidden by an inheriting document's document/variant override, the plan includes its output and adds `OVERRIDE.SHADOWS` WARN; the override is preserved.

## Important limitations

These methods are the intended edit path, but DOCY objects still expose direct mutators (`DocyDocument~place`, `~override`, `DocyNode~put`, and mutable storage directories). The object graph is **not** sealed: it remains possible for a caller to bypass planning. Consequently, this is a working planned-mutation API, **not yet an enforced event-only transaction boundary**. `DocyEvent` remains a logical predecessor chain, not a cryptographic hash chain. Plans are revision-fenced in-memory, not multi-agent transactional. Storage Fabric, real source adapters, StringTemplate, published ODT/PDF binary qualification and distributed publication remain outstanding.

The DOCY Gopher sphere candidate belongs under the separate `spheres/oorexx_docy_gopher_sphere_v0.1` artifact; it is not authority for executable runtime methods. A related StringTemplate sphere explicitly prohibits arbitrary Rexx execution, so `{d~Version}` requires a future scoped resolver and must not be evaluated as Rexx code.
