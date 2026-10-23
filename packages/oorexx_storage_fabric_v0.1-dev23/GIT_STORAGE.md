# Storage Fabric Git provider (`storage.fabric.git/0.1`)

Git is a Storage Fabric **location provider**, never object identity.  A
`StorageRef` remains authoritative while a Git commit/path is durable location
evidence.

Large objects are represented as bounded content-addressed chunks plus a small
manifest:

```
.storage-fabric/
  chunks/sha256/ab/<chunk-sha256>
  objects/sha256/cd/<object-sha256>/manifest.tsv
```

The manifest binds the Storage object id, whole-object SHA-256, byte length,
chunk size and ordered chunk digests.  Materialisation reads the exact commit
recorded in the `StorageLocation`, independently checks every chunk and then
checks the reconstructed whole-object SHA-256.

This means a Git provider can be used for bulk durable/offload storage without
requiring one giant Git blob.  Existing chunks are reused across repeated
stores.  Provider capacity is advertised as `ELASTIC`; Storage Fabric does not
invent a fake finite byte count for a service whose usable capacity is governed
externally.

## Security boundary

Credentials are **not** constructor arguments and are never placed in a
StorageRef, catalogue locator, manifest or repository configuration by Storage
Fabric.  Normal Git credential mechanisms provide authentication.  For the
included Azure DevOps live qualification use `GIT_ASKPASS` through
`tests/azure_git_environment_test.sh`; the script accepts the secret only via
`STORAGE_GIT_PASSWORD`.

Production wiring should launch Git through Secret Broker (or an equivalent
short-lived credential boundary) rather than persisting a PAT.

## Durability and failure domains

A successful push is not enough.  Storage only returns an AVAILABLE, VERIFIED,
SAFE location after reading the committed manifest back from the selected Git
commit and matching it to the StorageRef digest.  The provider is annotated
with vendor/site/failure-domain metadata so normal `StorageReplicaRequirement`
assessment can decide whether it is an independent replica.

Git can therefore participate in automatic replica repair after a removable or
peer location becomes unavailable, subject to the ordinary safety and site
policy.

## Qualification

Local deterministic provider test:

```
REXX_BIN=/path/to/rexx tests/test_git_provider.sh
```

Live Azure DevOps test resource:

```
export STORAGE_GIT_PASSWORD='...'
REXX_BIN=/path/to/rexx tests/azure_git_environment_test.sh
```

The password is intentionally not accepted on the command line because command
arguments are observable by other processes on many systems.
