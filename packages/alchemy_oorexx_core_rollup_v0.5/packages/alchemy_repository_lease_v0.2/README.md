# Alchemy Repository Lease v0.1

Kernel-backed cross-process coordination for one local Alchemy Git repository handle.

The ooRexx object owns lease policy and lifecycle.  A minimal shell holder owns the
`flock(2)` descriptor and watches the owning ooRexx PID/start-time.  Owner death therefore
releases the kernel lock without stale-directory cleanup heuristics.

Callers acquire the lease only while mutating/fetching local Git refs, object metadata or
worktree administration.  Read-only consumers of an already-created detached snapshot do
not hold the lease.
