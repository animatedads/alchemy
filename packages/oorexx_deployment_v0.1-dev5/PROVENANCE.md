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

## dev5 Rasen Falcon identity-role input

The concrete identity-role integration uses the Library artifact
`oorexx_ldap_identity_v0.1-dev22.zip`, SHA-256
`697c301c37ad1d77252a34db9028420c4c9a3e3dbe5c60de9be6fc91940341fc`.
The corrected Rasen Falcon deployment handoff is Git commit
`0495e8604c62fc780aff3c95b94c935415ffc57d` in PR #71. The library archive
contains the same daemon/bootstrap/unit/config deployment shape and is the
programmatic qualification input used by dev5.

General Deployment does not absorb LDAP identity, authorization, TLS or secret
authority. It verifies/package-stages those owned bytes plus an exact dependency
namespace and provides the process-launch boundary that discards ambient
`REXX_PATH`.
