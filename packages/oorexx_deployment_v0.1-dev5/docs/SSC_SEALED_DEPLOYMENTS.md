# SSC sealed deployments as Deployment dependency authority

The current Semantic Source Store gives Deployment a stronger production contract
than the original source-level adapter.

## SSC owns the fixed point

`SemanticSourceModuleService` defines a Deployment as a qualified immutable fixed
point of one logical module. `sealDeployment()` records its manifest SHA-256 and
makes the deployment `QUALIFIED`. `recordResolvedDependency()` accepts only a
qualified dependency deployment belonging to the declared target module.

After sealing, `sealedDependencies(deploymentId)` exposes the exact rows from
`ssc_deployment_dependency`.

Deployment must treat those ids as pins. It must not call development dependency
resolution and silently replace one with a later qualified deployment.

## SSC owns reconstruction of semantic bytes

`SemanticSourcePackageService~getDeploymentPackage(deploymentId)` reconstructs the
root deployment and recursively follows the exact `resolved_deployment_id` values.
It returns exact semantic revision/resource evidence with resolution policy:

```text
sealed-deployment-exact-closure
```

Deployment consumes that package. It should not independently rebuild the semantic
closure from filenames or re-run latest-accepted selection.

## Deployment owns the machine namespace

Once SSC has produced the immutable package closure, Deployment owns its execution
projection:

1. stage the package under content authority;
2. materialise it into a release-local dependency namespace;
3. construct a deterministic `REXX_PATH` containing only that namespace and any
   explicitly declared runtime package roots;
4. perform a real ooRexx package-load probe in that exact environment;
5. activate the process/host generation;
6. perform application/protocol live verification;
7. retain the SSC deployment ids, SSC manifest hash, namespace manifest, launch
   environment and verification evidence together.

The remote host need not have access to SSC persistence merely to execute a sealed
package already delivered by the controller.

## Development resolution is intentionally different

`source.get_package` may select latest accepted unpinned source revisions for review
or development. `resolveDevelopmentDependency()` may select the highest qualified
deployment satisfying an effective minimum requirement.

Neither behavior is appropriate after a release is sealed. Production deployment
must consume `source.get_deployment_package`/`getDeploymentPackage()` or equivalent
exact sealed evidence.

## Migration from the dev3 adapter

The existing `SscDeploymentDependencies.cls` remains useful for components that
still publish `SSC_MANIFEST`/`sourceLevel` metadata and have not yet been registered
as SSC module deployments. Its output is therefore classified as
**development/archive dependency evidence**.

As components acquire qualified SSC module deployments, their Deployment manifests
should carry the sealed deployment id instead. The old source-level lock should not
be used to override an available sealed deployment receipt.
