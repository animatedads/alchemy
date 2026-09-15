# Alchemy Transport v0.3

Transport-only ooRexx component for Alchemy.

It materializes package bytes into one transport-neutral `AlchemyMaterializedPackage` object with source provenance. It does not resolve dependencies, compose execution environments, execute tests, or publish accepted source.

Adapters:

- `AlchemyLocalDirectoryTransport`
- `AlchemyManagedZipTransport`
- `AlchemyGitBranchTransport`

Supporting components include `AlchemyGitSubmissionDiscovery`, `AlchemyCommandRunner`, archive-path validation, materialized-tree safety checks, and provenance objects.

The Git adapter reads an exact commit/tree with `git archive`; it never checks out, merges, or rebases the submission branch.

## Repository coordination

Git operations which fetch/update refs or administer worktrees use the shared
`AlchemyRepositoryLease`.  Accepted-main snapshots release the lease after the
exact detached snapshot has been created and reacquire it only for cleanup.
Accepted-main write transactions retain the lease through commit, push and
worktree removal.
