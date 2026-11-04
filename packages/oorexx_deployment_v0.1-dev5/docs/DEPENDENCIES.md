# Dependency deployment with Semantic Source Control

Deployment treats ooRexx dependency resolution as an authority problem, not as
an incidental file-copy problem.

## Authority split

Semantic Source Control / Semantic Source Store (SSC) owns semantic source,
module identity, accepted/qualified revisions, module dependency requirements and
sealed dependency deployments. Deployment owns placement, target/runtime
requirements, explicit load-path construction, activation and fresh verification.

There are now two deliberately different dependency paths.

### Development/archive intake

For older or loose source components that are not yet represented as qualified SSC
module deployments, the dev3 adapter can use:

```text
entry package(s)
  -> reachable ::requires graph
  -> active @source-requires ... AT_LEAST N
  -> SSC_MANIFEST component/lineage/sourceLevel bindings
  -> development dependency lock
```

This path remains useful for source intake and migration. It must not be confused
with a sealed production deployment.

### Sealed release deployment

For a qualified SSC module deployment the preferred path is:

```text
qualified SSC deployment id
  -> ssc_deployment exact module fixed point
  -> ssc_deployment_dependency exact dependency deployment ids
  -> source.get_deployment_package / getDeploymentPackage()
  -> immutable package/resource/revision closure
  -> Deployment dependency namespace
  -> explicit REXX_PATH
  -> package-load verification
  -> process/host activation
  -> live/application verification
```

`SemanticSourceModuleService~sealedDependencies()` and
`SemanticSourcePackageService~getDeploymentPackage()` are the current repository
contracts for this path. The latter uses resolution policy
`sealed-deployment-exact-closure` and does not float dependencies to newer
qualified deployments.

## `::requires` is not version authority

`::requires "X.cls"` is package-load authority: the ooRexx package loader needs a
file. It does not identify which module deployment is acceptable.

Older `@source-requires ... AT_LEAST N` declarations are semantic minimum evidence
for loose components. Current SSC module requirements are stronger for qualified
releases because `MINIMUM`/`EXACT` constraints resolve to qualified deployment ids
and a sealed deployment retains the exact ids actually qualified together.

`REXX_PATH` is neither semantic nor version authority. It is launch state produced
after dependency resolution.

## Entry packages remain explicit

Loose/archive resolution starts from declared entry packages, not every source
file in an archive. Tests and examples therefore do not become production
requirements merely by sharing a ZIP.

Sealed SSC deployments already define their fixed object/resource closure; the
Deployment consumer must not re-resolve that closure by rescanning a directory.

## Deterministic namespace materialisation

`bin/materialize_dependency_namespace.sh` takes:

- a satisfied portable lock;
- a component-root map supplied by the artifact/staging layer;
- one or more explicit entry packages; and
- an output namespace.

It copies only reachable locked package files under deterministic component
subdirectories, verifies the lock's component artifact hash against the supplied
root map when present, records SHA-256 for every copied file, and emits:

```text
evidence/dependency.lock.tsv
evidence/component-roots.tsv
evidence/materialized-files.tsv
evidence/rexx-path.relative.txt
evidence/rexx-path.txt
environment.sh
MANIFEST.sha256
```

`environment.sh` replaces ambient `REXX_PATH`; it does not append the user's
shell path. The same path is used for package-load qualification and final launch.

The current shell materialiser is the POSIX provider implementation. Other
providers may implement the same semantic result without using shell tools.

## Content authority and root substitution

A dependency lock is not permission to use any directory that happens to contain
a matching filename. When an artifact hash is present in the lock, the component
root map must name the same authority. A mismatched root fails before publication.
Every materialised file is then hashed again and sealed into the namespace
manifest.

The old dev3 resolver now emits explicit `artifact` rows for all consumer/provider
components so its portable lock can be materialised without embedding
controller-local paths.

## Bootstrap

SSC remains an optional controller/planning dependency. Minimal bootstrap may
stage ooRexx and Deployment without an SSC database on the remote target. A
previously resolved sealed package/lock can be deployed and verified without
re-running semantic resolution remotely.

## Runtime and native dependencies

SSC does not own libc/ABI, compiler, CPU architecture, filesystem capability,
service manager, FFmpeg/audio capability, native loadability or the ooRexx runtime.
Those remain ordinary Deployment requirements and probes.

## Hosted modules

MCP, Wire and other hosted modules must have their exact dependency package
materialised before host composition. The lifecycle remains:

```text
sealed dependency closure
  -> deterministic namespace
  -> package-loadable under exact REXX_PATH
  -> composed into exact host generation
  -> activated
  -> live-probed
```

A successful SSC package build or dependency namespace is not proof that a hosted
module is live.
