# Alchemy ooRexx Core v0.5

Composition checkpoint for the resident ooRexx Autobuild system.

v0.5 combines:

- `alchemy_repository_lease_v0.2` — one kernel-backed cross-process repository lease;
- `alchemy_transport_v0.4` — leased accepted-main writes and snapshot administration;
- `alchemy_dependency_floor_v0.5` — manifest-first accepted dependency identity;
- `alchemy_executor_v0.4` — immutable-version cut for the leased transport closure;
- `alchemy_publisher_v0.4`, `alchemy_orchestrator_v0.5`, `alchemy_submission_v0.4`;
- `alchemy_inbox_v0.3`, `alchemy_autobuild_evidence_v0.3`, `alchemy_autobuild_service_v0.4`.

The ordinary repository checkout remains a Git handle only. The resident daemon
executes from an immutable local runtime capsule.
