# Relationship Case change log

## v0.2
- Adds a neutral durable object-graph persistence contract for RelationshipCase, RelationshipCaseElement and RelationshipCaseEvent.
- Adds Queue Fabric v0.9-dev4 restore factories as an integration adapter rather than a core dependency.
- Makes generated domain event IDs restart-safe by deriving the next sequence from the restored case event history.
- Adds exact queue-graph round-trip, repository re-index and post-restart mutation tests.

## v0.1
- Initial policy-driven case domain model.
