# Brand Interaction Effect v0.6

`Brand Interaction Effect` treats support, delivery, billing, sales and recovery as one customer-facing **brand experience**.  Service may be promotional, reputational and commercial-relationship work without containing an upsell.



## v0.6: cohort provenance and selection-quality evidence

v0.6 records **how the analyzed cohort was constructed**, not merely how large it became. `BrandEvidenceCohortProvenance` preserves controlled, privacy-minimised lineage for the source system, source-unit kind, selection-rule id, sampling method, inclusion/exclusion policy, deduplication method/key kind, feature classifier/taxonomy, and outcome-ascertainment rule. It carries counts for source candidates, selected units, analyzable units, exclusions, unresolved selection, incomplete selected units, missing exposure/outcome and duplicate attempts. Opaque interaction keys and customer prose do not travel into the provenance object.

`BrandEvidenceCohortAccumulator~consider` now distinguishes `INCLUDE`, `EXCLUDE` and `UNKNOWN` source-candidate decisions and can retain controlled exclusion/unknown reasons without treating unknown exposure or outcome as false. The existing `observe` method remains a shorthand for an included unit with known exposure/outcome.

A new cohort-quality gate is separate from sample-size, effect-size and confidence gates. A frame may therefore have impressive analyzable counts and a large association while remaining only `WEAK_SIGNAL` because provenance is absent, selected-unit completeness is too low, unresolved eligibility is too high, or an explicit selection rule is required but missing. A low selection rate is **not itself classified as bias**: the sampling/selection evidence is preserved so another reasoning process can judge whether the cohort is appropriate for the claim.

```text
source candidates
      |
      +-- INCLUDE ------+-- complete ------> analyzable 2x2 frame
      |                 +-- incomplete ----> missingness evidence
      +-- EXCLUDE --------------------------> exclusion reason counts
      +-- UNKNOWN --------------------------> unresolved selection evidence
      |
      +-- duplicate attempt ---------------> counted, never double-counted

2x2 size/time gate
  x effect gate
  x confidence gate
  x cohort-quality gate
        -> scoped evidence status
```

This is selection evidence, not a claim that a particular sampling strategy is good or bad and not causal authority.

## v0.5: confidence bounds and counted cohort construction

v0.5 strengthens the **weight and measure** beneath aggregate tone/appropriateness reports.  Passing a raw population/count threshold and showing a large point estimate is no longer enough for `SUPPORTED` or `STRONG` when the uncertainty interval still crosses the no-association value.

`BrandStatisticalEvidence` derives an explicitly labelled approximate 2x2 association record from every sealed evidence frame:

- exposed/unexposed outcome counts;
- exposed and unexposed risk;
- relative-risk estimate and confidence interval;
- absolute risk-difference estimate and conservative Wilson-derived interval;
- confidence level and statistical method; and
- whether the RR and risk-difference intervals exclude their null values in the observed direction.

Zero cells use a recorded Haldane-Anscombe 0.5 correction for the log relative-risk interval.  The method remains **association evidence**, not causal proof.  `BrandEvidenceThreshold` now carries the confidence-level gate explicitly; by default a supported claim requires both configured effect size and a 95% interval excluding the null.

A second addition, `BrandEvidenceCohortAccumulator`, constructs frames from deduplicated privacy-minimised analysis units instead of relying on somebody hand-entering four totals.  It counts population, outcome, exposed and exposed+outcome once per opaque interaction key and emits a normal sealed `BrandEvidenceFrame`.  It is an Alchemy Object operational service and records duplicate attempts rather than double-counting them.

This means a reasoning packet can now distinguish:

```text
COUNTS/TIME THRESHOLD MET = true
POINT EFFECT GATE          = true
CONFIDENCE GATE            = false
STATUS                     = WEAK_SIGNAL
```

from a genuinely supported scoped association.  Large commercial materiality remains a separate investigation route and still does not become statistical proof merely because the monetary consequence is important.


## v0.4: native evidence authority at the bridge

v0.4 consumes Interaction Event v0.2 native pre-flattening evidence. The bridge no longer treats a convenient string tag such as `STRUCTURED_FINDING/SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING` as sufficient evidence. Structured finding/intent/effective-use tags copied directly from a producer event are filtered and regenerated only from native `InteractionDerivedFinding`, `InteractionGenerationIntentEvidence`, and `InteractionInformationUseEvidence` objects.

This closes an authority gap: a producer cannot manufacture a brand-effect finding merely by inserting a tag. Native evidence still does not establish illegality or causality; it establishes that the pre-flattening structure recorded a particular information-use relationship/finding.

v0.3 consumes the new pre-flattening evidence emitted by Structured Utterance v0.3. A brand-effect decision no longer has to infer from prose that a sensitive recovery/safety disclosure was reused as a sales rationale: the Interaction Event bridge can carry the controlled `STRUCTURED_FINDING/SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING` point directly.

The engine adds two findings:

- `SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING` — customer-sensitive information structurally participated in commercial persuasion;
- `DECLARED_INFORMATION_USE_MISMATCH` — the generating model's declared use differs from the effective use derived from the preserved act/relation graph.

These are brand-effect assessments, not declarations of illegality or causality. The raw customer text is not needed by the brand engine. `BrandInteractionEngine` now inherits AlchemyObject v0.4.3 for standard identity, lifecycle, contracts and instrumentation.

v0.2 adds the missing **weight and measure** beneath tonality and appropriateness reports.  A downstream reasoning model must not receive `SASS_BAD` or `EXTREME_APOLOGY_BAD` as naked conclusions.  It receives the population, joint counts, time scope, classifier provenance, thresholds, effect measures, supporting and counter evidence, confounders and explicit limits on interpretation.

## Evidence before verdict

A tone report can now carry, for example:

```text
classification = UNRESOLVED_SUPPORT_INTERACTION
from/to        = 2026-06-01 .. 2026-08-21
population     = 29234
cancellations  = 109
high-sass      = 29
sass+cancel    = 12
classifier     = TONE-MODEL-V7
taxonomy       = COMMUNICATION-STYLE-0.4
outcome window = 86400 seconds
```

alongside the threshold actually used:

```text
min population       = 1000
min exposed           = 25
min outcomes          = 20
min exposed+outcome   = 5
min observation days  = 14
min effect size        = ...
```

`THRESHOLD_COVERAGE_PCT` exposes how much of the required statistical support is present.  `SUPPORTED` and `STRONG` mean the configured statistical/time threshold is met and the observed effect clears the configured effect-size gate.  They still mean **association**, not causation.

## Material significance is not statistical proof

Seven interactions may be far too few for a population claim but still matter if four enterprise accounts leave and millions of pounds are at risk.  v0.2 reports that as `MATERIAL_INVESTIGATION`, not `SUPPORTED`.

Thus:

```text
STATISTICAL_SUFFICIENT = false
MATERIAL_INVESTIGATION = true
```

is a valid and useful result.

## Time is part of the evidence

`BrandTemporalEvidenceSeries` keeps `CURRENT`, `PREVIOUS` and `LONG_BASELINE` frames separate.  A sudden rise after a model/prompt release therefore does not disappear inside a large lifetime denominator.  The series exposes changes in feature prevalence and exposed-outcome rate while preserving each frame's dates and sample counts.

## Reasoning material for another LLM

`BrandEffectEvidencePacket` requires supporting evidence and explicit interpretation bounds.  Supported/strong claims also require counterevidence or a scope boundary.  A packet can therefore say, structurally:

```text
PERMITTED:  investigate high dismissive sass in this cohort/window
PROHIBITED: sass always causes cancellation
SCOPE OUT:  friendly banter
CONFOUNDER: pre-existing customer dissatisfaction
```

The goal is not to make a rewarded LLM obedient to a label.  It is to provide enough scoped evidence for the LLM to reason about the weight of the claim.

## Causal authority

Episode-level style/outcome chains remain `CANDIDATE_NOT_PROVEN`.  v0.2 adds `BrandCausalAuthority` and `BrandCausalPromotion`: established causality is a separate immutable assertion carrying a named authority, authority type, scope and decision reference.  The original candidate is not rewritten.

## Assessment disagreement

Multiple assessors may disagree.  The bridge retains immutable assessment records with assessment id/type/value, assessor, model id and confidence.  A later classifier does not erase the model that caused an earlier decision.

## Privacy

The bridge remains privacy-minimising.  Raw customer text/identity is not required here.  `UNKNOWN` structured-segment privacy now fails closed at the Interaction Event -> Brand Interaction boundary: transformation does not confer safety.

## Stable points

- `BRAND_INTERACTION:<episode-id>`
- `BRAND_INTERACTION:FINDING:<finding-id>`
- `BRAND_INTERACTION:HYPOTHESIS:<hypothesis-id>`
- `BRAND_INTERACTION:CAUSAL_PROMOTION:<promotion-id>`
- `BRAND_INTERACTION:EVIDENCE_FRAME:<frame-id>`
- `BRAND_INTERACTION:EVIDENCE_PACKET:<packet-id>`
- `BRAND_INTERACTION:EVIDENCE_COHORT:<accumulator-id>`
- `BRAND_INTERACTION:EVIDENCE_COHORT_PROVENANCE:<provenance-id>`

## Dependencies

Core model/evidence layer: ooRexx plus the standard RxMath library, Alchemy Objects v0.4.3, and ooRexx Crypto v0.1 for the inherited house base.

Optional bridges/tests:

- Interaction Event v0.2
- Structured Utterance v0.3
- Runtime Registry v0.12

Validated with the supplied ooRexx 5.3.0 r13196 Internal Test Version.
