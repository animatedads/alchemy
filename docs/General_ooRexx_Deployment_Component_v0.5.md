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
