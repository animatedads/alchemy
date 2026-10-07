# Scientific Solver seam contract

The Scientific Solver is deliberately a seam between Intentions and specialist
scientific components. It does not become a replacement for Maths, ooRexx ML,
ML Graph, Physics World, Rexxtronics, or consumer-domain specialists.

## Native object transport

`ScientificSolverRequest` carries `subject`, `context`, `evidence`, and the
originating `IntentionDecision` as ooRexx objects. No JSON/text conversion is
required by the provider. A specialist result may likewise be any native object.

## Capability registry

A capability is registered under a stable name. Re-registering that name replaces
the previous live capability atomically; it does not create an ambiguous duplicate.
Removal is explicit. Every registry mutation increments `capabilityRevision`.

Availability is still evaluated for every request. Registry revision is therefore
not a cache version: it is selection evidence identifying the specialist set from
which a request was routed.

## Capability properties and request requirements

A `ScientificSolverCapability` carries an open property directory. The provider
supplies these defaults:

- `SIDE_EFFECT_CLASS=READ_ONLY`
- `OBJECT_TRANSPORT=NATIVE_REXX`
- `AUTHORITY_ROLE=SPECIALIST`

Consumers and domain adapters may add properties such as `EVIDENCE_POLICY`,
`AUTHORITY`, `MODEL_FAMILY`, `PRECISION`, `UNIT_SYSTEM`, or other domain-neutral
contract facts. The provider does not assign scientific meaning to those values.

A request may express hard requirements with `request~require(name, value)`.
Discovery rejects a capability that does not advertise an equal property value.
This filtering occurs before priority/scoring, so a high-priority but unsuitable
specialist cannot win simply because it scores well.

## Selection evidence

`provider~select(request)` returns a native `ScientificSolverSelection` containing:

- the original request object;
- the capability registry revision;
- the eligible candidate observations;
- each candidate's score and optional specialist selection explanation;
- the selected capability object and winning score.

`solve()` attaches this selection object to `ScientificSolverResult`. Selection
provenance is therefore inspectable without flattening the request or specialist.

## Authority rule

Properties describe the contract a capability claims. They do not transfer domain
authority to the solver. The selected specialist remains responsible for the
scientific semantics of its returned object and evidence. The provider is
responsible for discovery, requirement matching, selection, and transport.
