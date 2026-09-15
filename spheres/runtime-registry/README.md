# Runtime Registry Knowledge Sphere v0.14

This sphere provides grounded knowledge of the `runtime.registry/0.3` authority, which manages the lifecycle of immutable code closures.

## Core Invariants
- **Immutable Generations**: A runtime generation represents an immutable code closure. Once published, it never changes.
- **Separate Boundaries**: Code upgrades (RuntimeGeneration) and client configuration upgrades (AbilityGeneration) are separate atomic operations.
- **Pinned Sessions**: A request receives an `AbilitySession` and remains pinned to that generation for its lifetime.
- **Dependency Closures**: A live generation keeps every generation in its declared dependency closure alive.

## Key Components
- **RuntimeRegistry**: Manages the loading, activation, and draining of runtime generations.
- **AbilityRegistry**: Bridges runtime generations to client-facing Ability Profiles.
- **AbilitySession**: The pinned execution context for a specific request.
- **RuntimeBundleBuilder**: Creates generation-private source closures from multiple files.

## Lifecycle
`VERIFIED -> LOADED -> READY -> ACTIVE -> DRAINING -> RETIRED -> RELEASED`
