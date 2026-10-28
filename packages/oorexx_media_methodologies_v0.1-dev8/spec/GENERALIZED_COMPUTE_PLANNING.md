# Generalized Compute planning projection

Media Methodologies dev8 can project a `MediaExperimentTask`, its exact `MediaImplementationExecutionProfile`, and immutable source references into Generalized Compute Intentions.

The projection is **planning only**.  It does not reserve capacity, allocate a node, acquire a lease, route material, dispatch a job or move Memory Fabric state.  A READY route means only that the supplied compute/allocation/WLU/router adapters found an admissible route at planning time.

Every media planning observation therefore declares:

- `mutationAuthority = NONE`
- `revalidationRequired = true`

A prepared `PlannedAdmittanceHandoff` must retain the original workload object and must itself require revalidation by `COMPUTE`, `ALLOCATION`, `WLU` and `ROUTER` authorities before a mutating execution path proceeds.
