# Alchemy Orchestrator v0.4

Composition root for transport, accepted-main snapshot, dependency catalogue,
execution and publication.

The orchestrator resolves dependencies exclusively from an exact detached
accepted-main snapshot. Catalogue identity is manifest-first. A package may live
under an arbitrary/misleading directory name; `integration.json` name/version is
the semantic dependency identity.

Snapshot/workspace cleanup is explicit on planning/execution errors.
