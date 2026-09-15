# Brand Intervention Effectiveness v0.2

This package measures the *observed association* between an intervention being applied and later outcomes among journeys where the same intervention was eligible/proposed.

It exists to close the learning loop without converting a plausible intervention into doctrine merely because it sounds sensible.

## Core rules

- The denominator is intervention-eligible journeys, not all customers.
- Applied and eligible-not-applied groups remain explicit.
- Every result is scoped by time, journey classification, outcome window, classifier/taxonomy and process/model release.
- `RANDOMIZED` is study-design provenance, not permission for this library to self-assert causality.
- A primary target outcome is insufficient on its own. Guardrail outcomes prevent one-metric optimisation.
- A promising primary association plus an adverse guardrail is `MIXED_EFFECTS`.
- A promising primary result with an underpowered guardrail is `REVIEW_REQUIRED`.
- Evidence point fields accept only opaque stable evidence references; free prose is rejected.
- Directional labels require the configured confidence gate as well as denominator sufficiency and effect magnitude.
- By default the confidence gate requires non-overlapping 95% Wilson intervals; overlapping intervals remain `NO_CLEAR_ASSOCIATION` even when the point estimate looks material.
- The confidence requirement is explicit in `BrandInterventionEffectivenessThreshold`, so a deliberately relaxed policy is visible in reasoning material rather than hidden.
- Reports retain uncertainty, confidence-gate state, controlled failure reasons and explicit anti-overclaim language for reasoning LLMs.

## Confidence is a separate gate

Effectiveness v0.1 already calculated Wilson intervals, but the directional status did not consume them. That allowed a numerically material point estimate to become `PROMISING_ASSOCIATION` while the package's own uncertainty intervals still overlapped.

v0.2 separates:

```text
STATISTICAL_SUFFICIENT
EFFECT_MATERIAL
CONFIDENCE_GATE
```

With the default threshold, all three must pass before `PROMISING_ASSOCIATION` or `ADVERSE_ASSOCIATION` is emitted. If the first two pass but the intervals overlap, status is `NO_CLEAR_ASSOCIATION` and `REASON=CONFIDENCE_INTERVALS_OVERLAP` is retained. This is still association evidence, never causal authority.

## Example

An intervention can be associated with fewer cancellations while simultaneously being associated with more disengagement. That is not a successful intervention result; it is a mixed result requiring reasoning and review.

The package does not execute interventions, modify prompts, or promote statistical association to causal fact.

## Validated dependencies

- ooRexx 5.3.0 r13196 Internal Test Version
- Alchemy Objects v0.8
- ooRexx Crypto v0.1
- Brand Interaction Effect v0.6
- Brand Journey v0.1
- Brand Journey Population v0.2
- Brand Intervention v0.2
- Runtime Registry v0.14
