# Design: scientific solver as an Intentions provider

The provider is a routing/orchestration layer, not a scientific implementation.

```text
caller component
      |
      v
IntentionService  -- clarify / confirm / policy / plan
      |
      v
ScientificSolverDirective
      |
      +--> native subject object
      +--> native context object
      +--> native evidence object
      +--> optional hard capability requirements
      |
      v
ScientificSolverProvider -- dynamic discovery each request
      |
      +--> registry revision
      +--> requirement matching
      +--> scored candidate observations
      +--> selected specialist object
      |
      +--> Maths capability
      +--> ML capability
      +--> ML Graph capability
      +--> Physics capability
      +--> Rexxtronics capability
      +--> consumer/domain specialist
      +--> coupled capability
      |
      v
ScientificSolverResult -- native value + native evidence + native selection evidence
```

The generic `AUTO` and `COUPLED` domains permit a capability to decide whether it can
accept a cross-domain problem. Availability is never permanently cached.

Capabilities self-describe contract properties and callers may state hard
requirements. Requirement matching is deliberately domain-neutral: the solver does
not reinterpret a specialist's science merely to route to it.

ML Graph is treated as explanatory/presentation authority only: upstream ML owns ML
meaning. Physics and Rexxtronics likewise retain their own model authority. The
provider routes objects; it does not silently re-derive domain conclusions.

See `SEAM.md` for the strengthened provider boundary and `REFERENCE_CONSUMER.md`
for the ONS spreadsheet qualification pattern.
