# General ooRexx Deployment v0.1-dev4

This checkpoint implements common deployment authority for Audio workers, MCP,
Wire and other ooRexx systems. Deployment reconciles declared state with observed
target state and performs a fresh verification pass after mutation.

`NativeDeployment.cls` makes host-native repair a general contract: reuse a
supplied native artifact only when its target probe succeeds, otherwise rebuild
from supplied source when policy permits and probe again. `HostedModuleDeployment.cls`
defines the common hosted lifecycle for MCP, Wire and future modules.

## dev4: exact dependency materialisation

dev3 established an SSC-backed dependency lock but deliberately left final
`REXX_PATH` materialisation open. dev4 closes that gap for the POSIX provider.
`bin/materialize_dependency_namespace.sh` consumes an already-satisfied lock plus
an explicit component-root map and builds a release-local namespace containing
only entry packages and files reachable through the locked package graph. It
verifies component content-authority hashes where the lock carries them, hashes
every materialised file, emits the exact load path as evidence, and never consults
ambient `REXX_PATH` to decide dependency authority.

`bin/verify_dependency_namespace.sh` re-verifies the resulting namespace before
launch. A substituted component root, missing locked file, unsafe path, required
issue or unsatisfied binding fails closed.

## SSC authority update

The September dev3 resolver (`SscDeploymentDependencies.cls`) remains available
for development/archive intake where components still use `SSC_MANIFEST`,
`@source-requires ... AT_LEAST N`, and conventional `::requires` package graphs.
It is no longer described as the preferred production dependency authority.

Current Semantic Source Store/SSC provides a stronger sealed-deployment model:

- a Deployment is an immutable `QUALIFIED` module fixed point;
- exact dependency deployment ids are retained in `ssc_deployment_dependency`;
- `SemanticSourceModuleService~sealedDependencies()` exposes that exact closure;
- `SemanticSourcePackageService~getDeploymentPackage()` reconstructs the sealed
  package without floating to newer dependency deployments.

Production release deployment should therefore consume a sealed SSC deployment
receipt/package whenever one exists. Development resolution may float according
to SSC policy; deployment of a sealed release must not.

The optional SSC integration remains outside the minimal bootstrap. A target does
not need the SSC database merely to obtain ooRexx or receive a previously resolved
Deployment plan/package.

`deploy_tree.sh` supplies idempotent, content-addressed local/SSH staging.
`deploy_hosted_module.sh` refuses to call a module live unless package-load,
activation and live-probe stages all occur. On HTTPS Server v0.4.4 route activation
is compose-before-start because route registration is immutable after server start.

Audio V9 remains the first downstream consumer proving heterogeneous target
preparation and native ABI repair.

See `docs/DEPENDENCIES.md` and `docs/SSC_SEALED_DEPLOYMENTS.md`.
