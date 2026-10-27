# General ooRexx Deployment Component

## 1. Purpose

The Deployment component provides a general mechanism for bringing a target execution environment into a declared, verifiable state.

Its core operation is:

`desired state + observed target state -> deployment plan -> executed state -> verified result`

It MUST be independent of the application being deployed.

The same component should be usable to deploy:

- audio processing workers;
- queue workers;
- web services;
- ooRexx applications;
- native libraries;
- ML components;
- databases or supporting processes;
- development/test environments;
- distributed services;
- command-line applications.

Application-specific knowledge belongs in deployment manifests and application-provided deployment extensions, not in the core Deployment classes.

---

# 2. Core authority boundary

Deployment owns:

- target discovery;
- capability discovery;
- dependency requirements;
- artifact placement;
- runtime preparation;
- configuration placement;
- deployment planning;
- action execution;
- verification;
- launch preparation;
- process launch where requested;
- deployment evidence;
- rollback information;
- reproducibility.

Deployment does NOT own:

- application semantics;
- business logic;
- scheduling policy;
- application-level worker allocation;
- ML decisions;
- application data interpretation;
- application result processing.

A deployment object MAY execute an application-defined verification command.

It MUST NOT interpret application-domain results beyond success/failure and declared verification outputs.

---

# 3. Principal classes

The initial general package should contain approximately:

`Deployment.cls`

`DeploymentManifest.cls`

`DeploymentTarget.cls`

`DeploymentDiscovery.cls`

`DeploymentCapability.cls`

`DeploymentRequirement.cls`

`DeploymentArtifact.cls`

`DeploymentPlan.cls`

`DeploymentAction.cls`

`DeploymentResult.cls`

`DeploymentEvidence.cls`

`DeploymentProvider.cls`

All classes MUST use:

`::options numeric inherit`

Executable `.rex` roots in this project ecosystem should continue to establish the required numeric environment explicitly.

---

# 4. Deployment

`Deployment` is the principal coordinator object.

It should expose operations conceptually equivalent to:

```text
deployment~discover(target)
deployment~assess(target, manifest)
deployment~plan(target, manifest)
deployment~apply(plan)
deployment~verify(target, manifest)
deployment~status(target, manifest)
deployment~rollback(result)

```

These names are semantic suggestions; the eventual ooRexx API may refine them.

The important separation is:

`discover != plan != apply != verify`

Merely examining a machine MUST NOT modify it.

---

# 5. DeploymentTarget

`DeploymentTarget` identifies where deployment is to occur.

A target may represent:

- the local machine;
- a remote machine;
- a container;
- a VM;
- a cloud instance;
- a chroot;
- a user-owned execution directory;
- another deployment provider implementation.

A target contains identity and connectivity information but not application requirements.

Typical properties:

```text
targetId
transport
host
port
user
workingRoot
platformHint
providerHint
metadata

```

`targetId` is an opaque deployment identity.

Deployment MUST NOT assume that:

`targetId == hostname`

or:

`targetId == IP address`

or:

`targetId == application worker name`

Those identities may coincide, but they are separate concepts.

---

# 6. DeploymentManifest

`DeploymentManifest` describes the desired state.

It should be declarative.

A manifest may declare:

```text
manifestId
manifestVersion
artifacts
runtimeRequirements
capabilityRequirements
filesystemRequirements
environmentRequirements
configuration
verificationRequirements
processRequirements
resourceRequirements
policy
metadata

```

The core deployment engine MUST treat unknown application metadata as opaque.

A manifest should be serialisable so the exact desired state can be retained as deployment evidence.

---

# 7. Requirements

All desired conditions should derive from a common:

`DeploymentRequirement`

Examples include:

`RuntimeRequirement`

`CommandRequirement`

`LibraryRequirement`

`FileRequirement`

`DirectoryRequirement`

`EnvironmentRequirement`

`ResourceRequirement`

`ArchitectureRequirement`

`OperatingSystemRequirement`

`ProcessRequirement`

`VerificationRequirement`

`CapabilityRequirement`

Requirements should expose approximately:

```text
id
kind
required
expected
actual
satisfied
reason

```

A requirement MUST be testable.

A requirement that cannot be tested should not masquerade as verified state.

---

# 8. Capabilities

A capability describes what a target can actually do.

Examples:

```text
command:tar
command:unzip
command:ffmpeg
runtime:oorexx
runtime:python
compiler:c
architecture:x86_64
filesystem:executable
network:https
service:systemd
hash:sha256

```

Capabilities are observations, not requirements.

Thus:

```text
DeploymentCapability

```

should remain distinct from:

```text
DeploymentRequirement

```

The planner compares them.

This distinction allows one application to require FFmpeg while another has no interest in it.

---

# 9. Discovery

Discovery MUST be non-destructive.

`DeploymentDiscovery` is a snapshot of facts observed about a target.

Possible observations include:

```text
operating system
OS version
kernel
architecture
libc
hostname
current user
home directory
shell
PATH
available disk
available memory
CPU count
commands
runtimes
runtime versions
libraries
compiler/toolchain
archive facilities
hash facilities
service manager
filesystem permissions
existing artifacts
running processes
environment variables

```

Discovery plugins/providers may extend this set.

The core MUST NOT contain hard-coded assumptions such as:

```text
Ubuntu => apt
Amazon Linux => dnf

```

That knowledge belongs to providers.

---

# 10. DeploymentProvider

Platform-specific mechanics belong behind:

`DeploymentProvider`

Examples may eventually include:

```text
PosixDeploymentProvider
LinuxDeploymentProvider
DebianDeploymentProvider
RpmDeploymentProvider
WindowsDeploymentProvider
SshDeploymentProvider
LocalDeploymentProvider
ContainerDeploymentProvider

```

A provider answers questions such as:

- how to execute a command;
- how to transfer an artifact;
- how to inspect a filesystem;
- how to determine available commands;
- how to create a directory;
- how to install or stage a dependency;
- how to launch a process;
- how to inspect a process.

The deployment model itself MUST remain provider-neutral.

---

# 11. Artifact model

`DeploymentArtifact` represents something whose exact contents matter.

It should support:

```text
artifactId
source
destination
size
hashAlgorithm
hash
mode
owner
group
executable
unpack
contentType
metadata

```

Artifacts may be:

- zip files;
- tar files;
- binaries;
- ooRexx source;
- native libraries;
- configuration files;
- data manifests;
- models;
- application packages.

Deployment MUST distinguish:

`artifact transport`

from:

`artifact installation`

and from:

`artifact verification`.

---

# 12. Content authority

Where a manifest supplies a cryptographic hash, the hash is content authority.

A file with the correct filename but wrong hash is not the required artifact.

Artifact verification SHOULD support at least SHA-256.

A deployment result should retain the hashes actually observed.

---

# 13. Runtime model

Runtime requirements should be general.

For example:

```text
RuntimeRequirement(
    name      = "oorexx",
    version   = "5.3.0",
    build     = "13196"
)

```

or:

```text
RuntimeRequirement(
    name      = "ffmpeg",
    capability = "decode:vorbis"
)

```

The deployment engine should not require that a runtime came from an OS package manager.

A valid deployment strategy may be:

- use existing runtime;
- install system package;
- stage application-private runtime;
- unpack a portable binary;
- build from supplied source.

The manifest/provider decides which strategies are permitted.

---

# 14. Private runtime preference

The design should explicitly support application-private runtimes:

```text
deploymentRoot/runtime/...
deploymentRoot/bin/...
deploymentRoot/lib/...

```

This is important for reproducibility.

Deployment SHOULD prefer an explicitly staged executable over ambient PATH when the manifest defines one.

The resulting launch environment should record the exact resolved executable path.

---

# 15. Archive abstraction

Deployment MUST NOT make `unzip` a semantic requirement merely because an artifact is ZIP formatted.

The requirement is:

`artifact can be materialised`

Possible providers may satisfy this using:

- unzip;
- tar;
- bsdtar;
- 7z;
- an ooRexx/native archive implementation;
- pre-expanded transport.

The planner should select a valid implementation.

Applications should not contain archive-tool workarounds.

---

# 16. DeploymentPlan

`DeploymentPlan` is the deterministic difference between desired and observed state.

For identical:

`manifest + discovery + policy`

the resulting plan should be identical.

A plan consists of ordered `DeploymentAction` objects.

Example:

```text
VERIFY_ARTIFACT
TRANSFER_ARTIFACT
CREATE_DIRECTORY
EXTRACT_ARTIFACT
STAGE_RUNTIME
SET_PERMISSION
WRITE_CONFIGURATION
BUILD_NATIVE_COMPONENT
VERIFY_RUNTIME
VERIFY_CONTENT
RUN_VERIFICATION
LAUNCH_PROCESS

```

Every action MUST state:

```text
actionId
actionType
reason
requirementsSatisfied
inputs
outputs
provider
destructive
reversible

```

---

# 17. No hidden mutation

`plan` MUST NOT mutate a target.

Only `apply` may execute actions.

The caller should be able to inspect and serialise a plan before execution.

This is important both operationally and for security review.

---

# 18. Idempotence

Deployment actions SHOULD be idempotent wherever possible.

Running deployment twice against an already-compliant target should normally produce:

`NO_ACTION_REQUIRED`

rather than reinstalling or recreating everything.

A second discovery after successful deployment should produce zero unsatisfied requirements.

---

# 19. Fail-closed behaviour

Deployment MUST fail closed where required state cannot be established.

Examples:

- artifact hash mismatch;
- unsupported architecture;
- required runtime cannot be obtained;
- verification program fails;
- insufficient filesystem permissions;
- required source/data absent;
- conflicting process already running;
- declared filesystem state cannot be created;
- insufficient free storage.

The planner MUST NOT silently weaken a requirement.

---

# 20. Policy

Deployment strategy and deployment requirement are different concepts.

For example, an application may require:

`ffmpeg capability`

while deployment policy states:

```text
allowSystemPackages = false
allowPortableBinaries = true
allowCompilation = true
allowNetworkDownload = false

```

This separation is essential.

The target might be capable of satisfying the application requirement through several mechanisms, while policy determines which mechanisms are allowed.

---

# 21. Privilege

Deployment MUST model privilege explicitly.

An action should state whether it requires:

```text
ordinary user
elevated privilege
root/administrator
service account

```

Deployment MUST NOT casually prepend `sudo`.

If elevation is unavailable or forbidden, the planner should seek a permitted user-local strategy or declare the requirement unsatisfied.

---

# 22. Environment construction

Deployment should build an explicit launch environment.

It should not rely blindly on an interactive user's shell startup files.

The launch environment may include:

```text
PATH
LD_LIBRARY_PATH
REXX_PATH
application variables
runtime variables
temporary directory
locale
timezone

```

Every material environment value used for execution should be recorded in deployment evidence.

Secrets are an exception and MUST NOT be copied into ordinary deployment evidence.

---

# 23. Process deployment

Applications may declare a `ProcessRequirement`.

It describes things such as:

```text
processId
executable
arguments
workingDirectory
environment
stdout
stderr
stdin
restartPolicy
identity

```

The deployment component may launch it.

The deployment component does not own what the application subsequently computes.

---

# 24. Existing process detection

Before launching a declared process, deployment should be capable of establishing:

```text
ABSENT
RUNNING_EXPECTED
RUNNING_DIFFERENT
STALE
UNKNOWN

```

A process with a similar command string MUST NOT automatically be accepted as the desired process.

Where possible, application/package identity and manifest identity should also be compared.

---

# 25. Verification

Verification is separate from installation.

After `apply`, the deployment engine MUST perform a fresh discovery and verification pass.

A successful action sequence is not sufficient evidence that deployment succeeded.

The required invariant is:

`post-deployment observed state satisfies manifest`

not:

`commands returned rc=0`

---

# 26. DeploymentResult

A `DeploymentResult` should include:

```text
manifestId
targetId
startTime
endTime
initialDiscovery
plan
actionResults
finalDiscovery
verificationResults
satisfied
failureReason
evidence

```

The result should be serialisable.

---

# 27. DeploymentEvidence

Deployment should produce durable evidence sufficient to answer:

- what was intended;
- what machine was inspected;
- what state existed beforehand;
- what actions were selected;
- what actions actually executed;
- what artifacts were installed;
- what hashes were observed;
- which executable paths were selected;
- what versions were observed;
- what verification ran;
- whether the final state satisfied the manifest.

This is much stronger than keeping a shell transcript.

---

# 28. Dry run

Deployment MUST support:

`dryRun`

A dry run performs:

`discover -> assess -> plan`

but not:

`apply`

The generated plan should be the same plan that would subsequently be executed against the same discovery state.

---

# 29. Explain

The API should support an explanation operation.

For example:

```text
deployment~explain(plan)

```

or:

```text
requirement~explain
action~explain

```

It should be possible to determine:

> Why is this action necessary?

and receive an answer tracing back to an unsatisfied manifest requirement.

---

# 30. Deployment adapters

Applications should be able to contribute additional deployment requirements without subclassing the entire deployment engine.

For example, an application package might supply:

```text
MyApplicationDeploymentRequirements.cls

```

which constructs ordinary deployment requirement objects.

The central engine remains unchanged.

---

# 31. Data deployment

Large datasets should use the same general artifact/content model.

A dataset may declare:

```text
file count
total size
per-file hashes
manifest hash
directory layout

```

The Deployment component does not need to know what those files represent.

Thus the current CCTV corpus is simply one instance of:

`VerifiedDatasetRequirement`

rather than something special inside Deployment.

---

# 32. Remote deployment

Remote transport is orthogonal to deployment semantics.

The same manifest should be deployable through:

```text
LocalProvider
SSHProvider
ContainerProvider
CloudAgentProvider

```

Changing transport MUST NOT change desired state.

---

# 33. Concurrency

Deployment should permit several independent targets to be prepared concurrently.

However, the `Deployment` object must retain one distinct:

`DeploymentResult`

per target.

Target completion order must not affect any target's desired state.

---

# 34. Reconciliation

Deployment should support repeated reconciliation:

```text
discover
assess
plan
apply
verify

```

This allows the same object model to handle:

- initial installation;
- repair;
- dependency drift;
- runtime upgrades;
- corrupted artifacts;
- configuration changes;
- redeployment.

---

# 35. Rollback

Actions should describe reversibility.

Rollback should be evidence driven.

Deployment MUST NOT claim that every operation can be rolled back.

Examples:

```text
CREATE_DIRECTORY     reversible
COPY_ARTIFACT        reversible
REPLACE_CONFIGURATION conditionally reversible
PACKAGE_INSTALL      provider-dependent
EXTERNAL_SCRIPT      unknown unless declared

```

If rollback is unavailable, that fact must be explicit before execution.

---

# 36. Security

Deployment MUST:

- verify supplied artifact hashes when available;
- avoid shell construction from untrusted strings where possible;
- retain argument boundaries;
- avoid logging secrets;
- distinguish privilege from ordinary execution;
- not download arbitrary replacements merely because a dependency is missing;
- observe deployment policy;
- fail closed where provenance cannot be established.

---

# 37. Native code

Native libraries are ordinary deployment artifacts plus verification requirements.

A manifest may require either:

```text
exact prebuilt native artifact

```

or:

```text
rebuild native artifact from supplied source

```

If rebuilding, the compiler and build environment become deployment requirements and resulting binary hashes become deployment evidence.

---

# 38. ooRexx runtime

ooRexx itself should be handled by the same general runtime mechanism.

The deployment component MUST be capable of deploying the runtime that executes application code without relying on a pre-existing system `rexx`.

This avoids the circular assumption:

> ooRexx deployment requires ooRexx already to be correctly installed remotely.

A minimal bootstrap may therefore be shell/native/provider code, after which the ooRexx Deployment object assumes control.

The bootstrap is transport/bootstrap infrastructure, not application deployment semantics.

---

# 39. Bootstrap boundary

A deliberately small bootstrap layer is permitted to:

- transfer the Deployment package;
- obtain/stage the required ooRexx runtime;
- invoke the Deployment entry point.

Everything after that should be represented through Deployment objects.

This bootstrap should remain minimal because it cannot benefit from the full ooRexx deployment model until ooRexx itself is available.

---

# 40. Object model principle

The central abstraction is not:

`install package`

It is:

`reconcile target with declared state`

Thus installation is merely one possible deployment action.

This lets Deployment represent already-correct machines without modifying them.

---

# 41. Suggested initial public API

A useful first API could be:

```text
d = .Deployment~new

target = .DeploymentTarget~new(...)
manifest = .DeploymentManifest~fromFile(...)

discovery = d~discover(target)

assessment = d~assess(target, manifest, discovery)

plan = d~plan(target, manifest, assessment)

result = d~apply(plan)

verification = d~verify(target, manifest)

say verification~satisfied

```

Convenience:

```text
result = d~reconcile(target, manifest)

```

may later perform the complete sequence while retaining every intermediate object.

---

# 42. Required invariant

The fundamental invariant of this component is:

> Deployment never changes the application's declared meaning in order to accommodate a target.

It changes the target until the target satisfies the declaration, selects another permitted deployment strategy, or fails.

That is the authority boundary which makes it safe to use across all of our ooRexx systems.

---

# 43. First implementation scope

The first executable version should implement the general model with:

- local target;
- SSH target;
- POSIX/Linux discovery provider;
- artifact transfer/staging;
- SHA-256 verification;
- runtime requirements;
- command/capability requirements;
- directory/file requirements;
- environment construction;
- declarative deployment plans;
- dry-run;
- apply;
- post-apply verification;
- process launch;
- deployment evidence serialization;
- user-local dependency staging;
- explicit failure reasons.

No Audio V9 classes should exist inside this package.

Audio V9 should merely become the **first consumer proving that the general Deployment component works across heterogeneous machines**.

---

# 44. Hosted module deployment

Deployment MUST support components whose executable meaning is completed only when they are composed into a host process. Examples include MCP routes, Wire UI access points/gateways, and later HTTPS-hosted services.

The generic hosted-module lifecycle is:

`staged -> package-loadable -> composed -> activated -> live-probed`

Only `live-probed` is deployment success. A copied module, a successful `rexxc`, or a unit test against a fake host MUST NOT be reported as a live deployment.

Application packages provide a hosted-module declaration containing the host kind/version, direct package requirement, adapter/binder class and method, activation strategy, and protocol-appropriate probe. Deployment remains unaware of MCP or Wire semantics.

For ooRexx HTTPS Server v0.4.4, route registration is immutable after the server starts accepting connections. Therefore the current activation strategy is `compose-before-start`: stage/load the module, bind it into the next host composition, start or replace that host generation, and perform a real endpoint probe. Deployment MUST NOT claim a route was activated merely because it was placed beside an already-running HTTPS Server.

Package visibility is part of deployment correctness. A hosted package that references a public HTTPS class such as `.HttpResponse` MUST directly `::requires 'https_server.cls'` in that package; a sibling package dependency is not sufficient.

# 45. Native binary compatibility and repair

A native artifact is accepted because its declared target load/use probe succeeds, not because its filename, controller hash, or build-host ABI looks plausible.

The default policy may be:

`reuse-if-loadable-else-rebuild`

Under that policy Deployment MUST first probe the supplied object on the target runtime. If it fails and source rebuilding is permitted, Deployment rebuilds from the supplied authoritative source using the target toolchain and runtime headers, records the resulting hash/toolchain evidence, and repeats the same probe. Failure of the rebuilt object is a deployment failure.

GLIBC symbol-version inspection is useful evidence but is not the acceptance test. Changing `LD_LIBRARY_PATH` MUST NOT be represented as repairing an ABI mismatch.

# 46. Audio V9 first deployment target

Audio V9 Voice Recovery is the first consumer of this mechanism. Its current fleet already provides x86_64, ooRexx 5.3.0 r13196, and unzip. Deployment therefore discovers and verifies those facts rather than reinstalling them.

The first concrete repair is Foreign Runtime v0.22.6. A supplied binary that fails its real ooRexx load probe on an older-glibc worker is rebuilt host-native from the packaged source and then probed again. Compatible workers retain the supplied binary. The Audio spatial native provider follows the same target-loadability rule.

Worker readiness and worker launch are separate states. Reconciliation may finish across the fleet while all workers remain stopped. Corpus verification remains mandatory before an explicit start action.

The general Deployment package MUST still contain no Audio V9 application classes; Audio contributes its requirements, probes and deployment adapter from the Audio package.

---

# 47. Dependency authority

Dependencies MUST be resolved before Deployment mutates a target.

For ooRexx components, Deployment MUST distinguish at least three different kinds of dependency evidence:

- semantic component/source requirements;
- ooRexx package-load requirements (`::requires`);
- target/runtime/native capabilities.

These are related but are not interchangeable.

A filename discovered through `REXX_PATH` MUST NOT become version authority. A semantic component version MUST NOT be inferred from a ZIP filename. A successful semantic source-level check MUST NOT masquerade as proof that a native object is loadable on the target.

A deployment manifest that declares component dependencies but has no satisfied dependency resolution/lock MUST fail before an executable mutation plan is produced.

---

# 48. Semantic Source Control authority

The shared ooRexx Semantic Source Control (SSC) component should be the authoritative source for ooRexx semantic dependency identity.

Deployment consumes, rather than reimplements, SSC concepts including:

```text
SSC_MANIFEST
component
lineage
sourceLevel
@source-requires ... AT_LEAST N
::requires package-contract evidence
```

The authority split is:

```text
SSC
  owns source/component identity,
       source lineage,
       source-level requirements,
       semantic package contracts,
       source-impact evidence

Deployment
  owns artifact selection,
       dependency closure materialisation,
       REXX_PATH construction,
       target placement,
       activation,
       target verification,
       deployment evidence
```

Deployment MUST NOT invent an alternative semantic source-level system.

---

# 49. `@source-requires` versus `::requires`

SSC exposes two different dependency signals that Deployment MUST preserve separately.

An annotation such as:

```rexx
-- @source-requires SemanticSourceControl AT_LEAST 5
```

states semantic authority: the consumer requires at least source level 5 of the named component/surface inside the declared SSC lineage.

An ooRexx directive such as:

```rexx
::requires 'SemanticSourceControl.cls'
```

states package-load authority: the ooRexx package loader needs that source package to be resolvable.

`::requires` by itself does not state which component/version is authoritative.

`@source-requires` by itself does not state which concrete filename/path will satisfy the package loader.

For a cross-component ooRexx dependency, Deployment SHOULD normally require both forms of authority, directly or through an explicit equivalent component requirement in the deployment manifest.

A cross-component `::requires` for which no semantic component/source authority exists SHOULD fail closed rather than allowing incidental `REXX_PATH` ordering to choose a provider.

---

# 50. Entry-package-scoped closure

Dependency resolution MUST begin from one or more explicit deployment entry packages.

SSC intentionally analyzes tests, examples, launchers and production classes. Therefore Deployment MUST NOT treat every `::requires` found anywhere in a release tree as a production dependency.

The required algorithm is conceptually:

```text
entry package(s)
    -> reachable ::requires package graph
    -> active @source-requires declarations on reachable source
    -> transitive provider packages
    -> immutable component/file closure
```

A dependency that exists only in a test package remains test/qualification evidence unless the deployed entry package reaches it.

Hosted modules naturally use their declared host adapter/package as an entry package. Command-line applications and workers declare their executable/package entry point explicitly.

---

# 51. Component identity and source level

For SSC-aware components, `SSC_MANIFEST` is component identity authority.

For example:

```text
component=OorexxDeployment
lineage=MAIN
sourceLevel=1
```

Deployment MUST compare component names exactly according to SSC identity rules.

Different lineages are not numerically comparable.

A required whole-number source level must be satisfied by an authoritative whole-number source level. `UNKNOWN` MUST NOT silently satisfy `AT_LEAST`.

Marketing versions, filenames and timestamps MUST NOT be converted into SSC source levels.

---

# 52. Dependency lock

Successful dependency resolution should produce a durable dependency lock that is part of deployment evidence.

The lock should retain, at minimum:

```text
consumer component
entry package(s)
required semantic target
minimum source level
required lineage
selected provider component
selected provider source level
content authority/hash
resolved ::requires file
provider component/file
resolution status/reason
SSC authority/version used for resolution
```

The same lock should be used for planning and later verification. Deployment MUST NOT silently re-resolve to a newer provider between dry-run and apply.

Where supplied component manifests contain cryptographic content manifests, those manifests should be verified before dependency resolution and their content authority retained in the lock.

---

# 53. REXX_PATH is execution state, not dependency authority

Deployment MUST construct the ooRexx load environment explicitly.

`REXX_PATH` is part of deployment execution state and evidence. It MUST NOT be used as an implicit dependency resolver whose outcome changes according to ambient shell configuration.

For a reachable bare package name such as:

```rexx
::requires 'Widget.cls'
```

Deployment should resolve the owning file/component before launch.

If more than one candidate in the selected closure could satisfy the same package name, Deployment SHOULD fail as ambiguous unless the ambiguity is explicitly eliminated by a stronger package path or component-specific declaration.

The exact load path used by the package-load probe and final process/host generation should be retained as deployment evidence.

---

# 54. `AT_LEAST` does not prove forward compatibility

SSC source-level satisfaction answers only whether the consumer's known minimum is met.

It does not mean that every semantic change at a later source level is automatically compatible.

Deployment MUST therefore distinguish:

```text
minimum source requirement satisfied
```

from:

```text
semantic compatibility qualified
```

Where an accepted SSC repository/baseline is available, Deployment planning SHOULD consume SSC impact analysis for the selected closure.

Where such impact qualification is unavailable, later ooRexx package-load verification and application/host verification remain mandatory and the deployment evidence MUST NOT claim stronger semantic compatibility than has actually been established.

---

# 55. Bootstrap boundary for SSC

SSC is an important ooRexx planning authority but MUST NOT create a circular bootstrap requirement.

The minimal bootstrap remains capable of:

- obtaining/staging ooRexx;
- placing the Deployment core;
- invoking basic Deployment entry points.

The SSC adapter may be an optional Deployment package which directly requires SSC only when semantic dependency planning is requested.

Thus:

```text
minimal bootstrap != SSC dependency resolver
```

Once the controller/planning environment has ooRexx and SSC available, the SSC-backed resolver establishes the application dependency closure before target mutation.

The remote target need not run SSC merely to execute a previously resolved and locked deployment plan.

---

# 56. Dependency types outside SSC

SSC MUST NOT be stretched to represent dependencies that are not source/component semantics.

Examples that remain ordinary Deployment requirements include:

- ooRexx runtime executable/version/build;
- libc/ABI properties;
- compiler/toolchain availability;
- native library target loadability;
- CPU architecture;
- filesystem capabilities;
- service manager;
- network capability;
- FFmpeg/audio codec capability;
- external service availability.

An ooRexx component may therefore have both an SSC source dependency and independent target/runtime/native requirements.

---

# 57. Hosted-module dependency ordering

MCP, Wire and other hosted ooRexx modules MUST resolve their complete ooRexx dependency closure before host composition.

The hosted lifecycle therefore expands conceptually to:

```text
resolve/lock dependencies
    -> materialise dependency closure
    -> package-loadable under explicit REXX_PATH
    -> composed into exact host generation
    -> activated
    -> live-probed
```

The host itself is a dependency and should be pinned to an exact compatible host component/generation for the deployment result.

A dependency lock that succeeds does not mean a hosted module is live. The existing hosted-module live-probe invariant remains authoritative.

---

# 58. Cycles, ambiguity and fail-closed resolution

Dependency resolution MUST detect and retain cycles rather than recursing indefinitely.

A legal package cycle, if ooRexx semantics permit it, must still resolve to one finite selected component/file closure and be verified through the target package-load probe.

The following are deployment failures unless explicitly governed otherwise:

- required component absent;
- duplicate supplied component identity;
- source lineage mismatch;
- source level below required minimum;
- authoritative source level absent where `AT_LEAST` is required;
- required package file absent;
- ambiguous package-file provider;
- cross-component package dependency with no semantic version authority;
- selected artifact/content-manifest verification failure.

Dependency resolution MUST produce explanations for these failures before mutation begins.

---

# 59. Qualified SSC deployments supersede loose source-level resolution for release deployment

The earlier SSC integration based on:

```text
SSC_MANIFEST
@source-requires ... AT_LEAST N
reachable ::requires
```

remains useful for development, archive intake, diagnostics and migration of components that have not yet been registered as qualified SSC module deployments.

It MUST NOT be the preferred authority for a sealed production deployment where the current Semantic Source Store provides a qualified module deployment.

For release deployment, the preferred semantic authority is:

```text
QUALIFIED SSC module deployment
    + immutable deployment manifest hash
    + exact ssc_deployment_dependency rows
    + exact source/resource revisions
```

A qualified SSC deployment is a fixed point. Deployment MUST NOT silently float any dependency of that fixed point to a newer deployment merely because a newer qualified provider now exists.

The distinction is therefore:

```text
development resolution
    may choose a newest acceptable provider according to SSC policy

sealed deployment resolution
    must reproduce the exact dependency deployment ids that were qualified together
```

Deployment consumes this authority; it does not reproduce SSC's module/deployment resolver.

---

# 60. Current SSC service boundary

Where the current Semantic Source Store services are available, Deployment SHOULD consume the existing service boundary rather than query SSC persistence directly.

The relevant semantic operations are conceptually:

```text
moduleService~deployment(deploymentId)
moduleService~sealedDependencies(deploymentId)
packageService~getDeploymentPackage(deploymentId, projectId)
```

The root and every dependency deployment MUST be `QUALIFIED` and MUST carry its immutable manifest content authority.

The package service result used for a sealed deployment MUST identify its resolution policy as an exact sealed closure. A development package whose policy permits latest-accepted/floating resolution MUST NOT be substituted for the sealed package.

Every materialised semantic object/resource returned for the package must be attributable to the root deployment or one of its exact transitively sealed dependency deployments.

Deployment SHOULD retain the SSC deployment ids, module ids, deployment sequences, manifest hashes, object/revision ids and source/resource hashes as deployment evidence.

---

# 61. Semantic closure and target namespace are separate artifacts

An SSC package/deployment receipt determines **which semantic bytes belong to the release**.

Deployment still owns **how those bytes become the target's deterministic runtime namespace**.

Thus:

```text
SSC sealed closure
    -> verified component/package material
    -> Deployment namespace materialisation
    -> exact REXX_PATH
    -> package-load probe
    -> process/host composition
```

The semantic dependency lock and the target namespace receipt MUST remain separately inspectable.

This separation matters because the same sealed semantic closure may be materialised on different target filesystem layouts without changing its semantic meaning.

---

# 62. Deterministic ooRexx dependency namespace

Deployment MUST be able to materialise a dependency lock into a release-local ooRexx package namespace.

The namespace MUST be derived from the resolved closure, not from an ambient user installation.

A POSIX implementation may use a layout similar to:

```text
release/dependencies/
    components/
        <component-stable-id>/...
    evidence/
        dependency.lock.tsv
        component-roots.tsv
        materialized-files.tsv
        rexx-path.relative.txt
        rexx-path.txt
    environment.sh
    MANIFEST.sha256
```

The exact directory naming is provider policy. The following semantics are not optional:

- only the declared entry packages and their reachable dependency files are materialised;
- the owning component for every materialised file is retained;
- content hashes are verified before the namespace becomes current;
- path traversal and unsafe relative paths fail closed;
- duplicate/ambiguous package providers fail closed unless the lock explicitly disambiguates them;
- the resulting load path is deterministic for the same lock + component roots + provider policy;
- the namespace receipt is content-verifiable after materialisation.

Deployment MUST NOT copy an entire source archive merely because one reachable package lives inside it, unless the manifest explicitly declares the whole archive as the deployable artifact.

---

# 63. Component-root substitution protection

A portable dependency lock should identify component artifact/content authority without embedding controller-local absolute paths.

A separate provider input may map:

```text
component -> local/provider root -> observed artifact/content hash
```

Before copying any package from that root, Deployment MUST prove that the supplied root satisfies the content authority recorded in the dependency lock or sealed SSC receipt.

A same-named component directory with a different artifact/content hash is not an acceptable provider.

This check prevents a correct semantic lock from being silently materialised from stale or substituted bytes.

---

# 64. REXX_PATH construction is replacement, not inheritance

For a locked deployment generation, Deployment MUST construct the package search path explicitly from the materialised namespace.

The launch environment SHOULD behave conceptually as:

```text
REXX_PATH = locked-release-local-directories
```

not:

```text
REXX_PATH = locked-release-local-directories + ambient-user-REXX_PATH
```

unless an explicitly declared policy adds a separately verified external package root.

This closes a common ooRexx failure mode where a correct dependency closure is shadowed by an older or unrelated package on the invoking user's environment.

The exact absolute and release-relative `REXX_PATH` used by package-load verification and final launch MUST be retained as evidence.

---

# 65. Production and development dependency modes

Deployment should expose the distinction between dependency modes rather than hide it.

A useful policy vocabulary is:

```text
SEALED
    require a qualified SSC deployment and exact transitive deployment closure

DEVELOPMENT
    allow SSC development resolution under explicit policy, then freeze the result into a lock before target mutation

LEGACY_INTAKE
    resolve SSC_MANIFEST / @source-requires / ::requires from supplied component archives when no qualified SSC module deployment exists
```

`SEALED` should be the default for production service/worker releases once the component is represented by SSC deployments.

A DeploymentResult MUST record which dependency mode was used. It MUST NOT describe DEVELOPMENT or LEGACY_INTAKE resolution as a sealed SSC deployment.

---

# 66. Hosted-module dependency generation

For MCP, Wire and other hosted modules, the exact host generation is part of the dependency closure.

A hosted deployment therefore becomes:

```text
resolve exact sealed module + host deployment closure
    -> materialise deterministic namespace
    -> verify package loading under that namespace
    -> compose exact host generation
    -> activate/replace host generation
    -> live probe protocol endpoint
```

The package namespace used during the package-load probe MUST be the same namespace supplied to the activated host generation.

A module MUST NOT be called deployed if it loaded under one dependency path during qualification but the live HTTPS/Wire/MCP host subsequently started with another ambient path.

---

# 67. Qualification state for the dev4 namespace increment

The dev4 dependency-namespace increment adds executable POSIX materialisation and verification of a portable dependency lock, including negative gates for substituted component-root authority and unsatisfied package bindings.

The current development environment used to prepare this revision did not expose the previously supplied ooRexx 5.3.0 r13196 binary. Therefore:

- the POSIX namespace/materialisation regression is qualified in this revision;
- the existing dev3 ooRexx r13196 model qualification remains historical evidence;
- the new dev4 ooRexx sealed-SSC adapter tests remain **candidate pending execution under r13196**;
- this document MUST NOT represent dev4 as fully runtime-qualified until that suite is rerun with the interpreter.

This qualification distinction is part of Deployment evidence and must be preserved in the sphere and repository documentation.
