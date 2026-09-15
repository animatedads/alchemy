# Database Core Runtime Registry integration

`DatabaseCoreRuntimeModule_v1.cls` and `_v2.cls` are deliberately tiny lifecycle
entry classes for Runtime Registry generation-private bundles.

They are not a second database implementation.  At staging time, Runtime
Registry v0.3's `RuntimeBundleBuilder` combines one wrapper with
`database_core.cls`; the bundle builder removes the local `::requires` and the
registry loads the resulting source into a generation-private `.Package`.

The module lifecycle surface is:

- `runtimePrepare(context)`
- `runtimeSelfTest`
- `runtimeStart`
- `runtimeQuiesce`
- `runtimeStop`

`beginTransaction()` returns a real Database Core `.DatabaseTransaction` created
inside that generation's private package/class universe.
