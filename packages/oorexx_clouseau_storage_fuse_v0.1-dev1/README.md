# Clouseau Storage FUSE bridge v0.1-dev1

A separate, observational bridge between Inspector Clouseau and ooRexx Storage Fabric.

It takes a real `InspectorClouseau~snapshot` and republishes the observed object universe through Storage Fabric's existing `storage.fabric.fuse/0.1` semantic core. It does **not** inject application values, call application setters, or provide a write/control path back into the inspected program.

## Virtual tree

Typical paths:

```
/live/demo/schema
/live/demo/generated_at
/live/demo/objects/O000123/class
/live/demo/objects/O000123/path
/live/demo/objects/O000123/attributes/STATE/value
/live/demo/classes/PRIORITYORDER/super_class
/live/demo/classes/PRIORITYORDER/inheritance/lineage
/live/demo/classes/PRIORITYORDER/methods/ADVANCE/origin_kind
/live/demo/classes/PRIORITYORDER/methods/ADVANCE/origin_class
/live/demo/classes/PRIORITYORDER/methods/ADVANCE/source_available
/live/demo/triggers/.count
```

Each refresh is a fresh Clouseau observation. Existing virtual files are updated in the Storage FUSE generation store, so a second read can reveal changed live values without the bridge writing anything into the application.

## Demo

`examples/illuminating_app.rex` intentionally contains:

- ordinary class inheritance (`WorkItem -> Order -> PriorityOrder`),
- multiple inheritance through mixins (`Auditable`, `Prioritised`, `InspectorCooperative`),
- inherited and overridden methods,
- mutable instance state,
- a Clouseau method trigger,
- a read-only Storage FUSE projection.

The demo inspects the application, runs a live method that changes state, refreshes Clouseau, and then reads the changed state and method-origin evidence through virtual FUSE paths.

## Dependencies

Authoritative development dependencies:

- Inspector Clouseau from `oorexxapis(20260917-220404).zip` -> `current/alchemy_oorexx_core_rollup_v0.5.zip` -> `alchemy_objects_v0.4.3/inspector/InspectorClouseau.cls`.
- Storage Fabric v0.1-dev17, API `storage.fabric.fuse/0.1`.
- ooRexx 5.3.0 r13196.

Exact dependency sources used for qualification are vendored under `vendor/` for reproducibility only. They remain upstream authorities and are not modified by this module.

## r13196 compatibility findings

The Inspector source recovered from the September 17 API roll-up required a narrowly scoped qualification patch for stock ooRexx 5.3.0 r13196:

1. `.Method~new` is fed the source Array directly for dynamic probe methods rather than a newline-joined String.
2. `safeMethodLookup` walks the `Class~methods` Supplier instead of sending unsupported `Class~method(name)`.
3. Probe source falls back to a public getter for a Clouseau-inferred slot when dynamic method scope cannot `EXPOSE` that slot.
4. Scalar object nodes retain their observed printable value so attribute-reference edges can be rendered as virtual value files.
5. `refreshObservation` re-walks registered roots observationally while suppressing trigger reinstallation during the refresh.

The exact diff is `compat/InspectorClouseau-r13196-observation.patch`. The unmodified authority source is retained as `vendor/inspector/InspectorClouseau.authority.cls`.

The current demo proves method-origin and live-state observation. Its method-trigger rule is retained as an integration fixture, but the stock r13196/API-copy trigger interception path is not claimed as freshly qualified by this package; the read-only refresh path is independently qualified.