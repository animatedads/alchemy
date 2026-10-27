# Provenance

Design authority begins with the user-supplied General ooRexx Deployment design
and the direction that ooRexx dependency handling should use the shared Semantic
Source Control (SSC) authority rather than ambient file/path discovery.

Historical executable baseline:
- `oorexx_deployment_v0.1-dev3.zip` SHA-256 `796b4375b7abac6e13e5f23f632c8aa75f86fe777f3d7c130ea8e440ff5dbd79`.
- dev3 was qualified under ooRexx 5.3.0 r13196 against the older Semantic Source
  Control v0.2.3 source-level/package-contract adapter.

Current repository reconciliation (27 Oct 2026):
- `packages/oorexx_semantic_source_store/src/SemanticSourceModuleService.cls`
  defines qualified immutable module deployments, `sealedDependencies()`, and
  exact `ssc_deployment_dependency` bindings.
- `packages/oorexx_semantic_source_store/src/SemanticSourcePackageService.cls`
  defines `getDeploymentPackage()` with `sealed-deployment-exact-closure` policy.
- `packages/oorexx_semantic_source_store/MCP_COMMANDS.md` explicitly distinguishes
  floating development `source.get_package` from exact
  `source.get_deployment_package`.

The dev4 namespace materialiser consumes already-resolved authority. It never uses
ambient `REXX_PATH` to select a dependency and refuses a supplied component root
whose declared artifact authority differs from the lock.
