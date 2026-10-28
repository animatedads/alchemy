# Dynamic Methodology Intention Discovery

API: `media.methodologies.intentions/0.1`

The methodology catalogue is large by design. It must not become a static menu
that is treated as permanently applicable to every media object.

## Live surface

`MediaMethodologyIntentionSurface` retains the exact caller-owned media/evidence
target. `discover()` asks the provider again every time. The provider refreshes
dynamic catalogue providers and re-evaluates applicability against current
context.

This follows the same architectural principle now used by current Vision and
Layered Audio intention surfaces: object identity can persist while the evidence
and available operations around that object change.

## Applicability is separate from existence

A methodology can be:

- `APPLICABLE`
- `NOT_APPLICABLE`
- `UNKNOWN`

`UNKNOWN` is important. Lack of a current assessor is not evidence that the
method fails, and merely being in the 175-method catalogue is not evidence that
it applies.

Multiple `MediaMethodologyApplicabilityProvider` objects may inspect the exact
live target, current evidence, policy and available implementation profiles.
Their evidence is retained. A positive assessment makes a method applicable; a
negative assessment makes it not applicable only when no provider supplies a
positive assessment. Conflicting assessments therefore remain observable rather
than being hidden behind a single opaque score.

## Execution availability is separate again

A method may be applicable but have no currently available implementation
profile. `proposeExperiment()` therefore requires both current applicability and
at least one declared `MediaImplementationExecutionProfile` before constructing
an executable experiment selection.

This prevents semantic discovery from silently promising a runtime, GPU,
library, jurisdiction or node capability that does not currently exist.

## Intention Service boundary

This module deliberately does not vendor or require Intention Service. It exposes
live discovery/proposal objects suitable for an Intention Service adapter. The
exact bridge should use the then-current public dynamic discovery contract rather
than freezing a copied NLP/parser implementation inside Media Methodologies.
