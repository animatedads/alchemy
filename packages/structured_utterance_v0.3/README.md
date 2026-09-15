# Structured Utterance v0.3

`Structured Utterance` preserves what an agent or LLM knows about its reply **before** the reply is flattened into plain text.

The package exists because post-hoc transcript analysis throws away two classes of information which are extremely valuable to privacy, reputation, legal, commercial and brand-effect models:

1. **why a span was generated** (`WARNLAW`, `SALESPROP`, `SERVICE_RESOLUTION`, `APOLOGY`, etc.); and
2. **which source information a span depends on**, even when the output does not copy the source wording.

The model therefore keeps communicative purpose, customer-data role, lineage, privacy classification and brand/commercial significance orthogonal.



## v0.3: native Interaction Event handoff

v0.3 keeps the v0.2 pre-flattening model unchanged and upgrades its downstream handoff to Interaction Event v0.3. The bridge now emits native `InteractionInformationUseEvidence`, `InteractionGenerationIntentEvidence`, and `InteractionDerivedFinding` objects instead of relying only on routing tags and per-segment metadata. Compatibility tags remain for cheap routing, but they are no longer the sole evidence record.

The native Interaction Event seam uses Interaction Event's opaque-token identity grammar. Legacy Structured Utterance ids may be freer strings for standalone use; when such an id cannot be represented by the native Interaction Event contract, the bridge returns `INTERACTION_NATIVE_TOKEN_INCOMPATIBLE` rather than throwing an ooRexx syntax condition. Token-compatible ids are canonically normalised by Interaction Event.

This matters for the cross-act case: a sensitive recovery fact can influence the generic sentence `Would you like to add an extra bag?` even though the sales text contains no sensitive words. The native event retains the source privacy class, relation (`JUSTIFICATION`), effective use (`COMMERCIAL_PERSUASION`), intended act (`OFFER_EXTRA_BAG`) and derived findings while the raw recovery wording can disappear in the de-identified content projection.

## v0.2: preserve information use and generation intent

v0.2 adds the piece which is normally lost at the instant language generation finishes: the generating agent's contemporaneous account of **what act it was trying to realise**, together with explicit information-to-act relationships.

Three new structures are first-class:

- `UtteranceCommunicativeAct` groups the realised segments that perform an act such as `WARNLAW`, `INFORMATION` or `SALESPROP`;
- `UtteranceInformationUseEdge` links a customer-derived lineage edge to the communicative act it informed, with a relation such as `JUSTIFICATION`, `SAFETY_REASON`, `PERSONALISATION` or `RISK_AVOIDANCE`; and
- `UtteranceGenerationIntent` records the model's contemporaneous intended act/register/outcome and the information-use edges it believed it was using.

The declared use is evidence, not authority. `StructuredUtteranceAnalyzer` derives an `effectiveUse` from the structural relationship. A model can therefore declare `SUPPORTIVE_CONTEXT` while the same sensitive fact is structurally being used to justify a `SALESPROP`; the package exposes `DECLARED_INFORMATION_USE_MISMATCH` rather than silently trusting the label.

The important case is deliberately **cross-act**. Customer-sensitive context can influence a generic sales sentence without appearing inside that sentence at all:

```text
CUSTOMER_SENSITIVE recovery fact
        |
        | JUSTIFIES
        v
SALESPROP: "Would you like to add an extra bag?"
```

The sales text contains no customer-specific wording, yet the generation-time information dependency is still preserved. Post-hoc transcript analysis cannot reliably reconstruct that fact. v0.2 can expose `SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING` from the preserved edge.

`StructuredUtterance` itself now inherits `AlchemyObject` v0.4.3. The inherited house surface supplies object identity, lifecycle/usage telemetry, method contracts, bounded disclosure-labelled state and instrumentation. Raw utterance segments are deliberately **not** registered as ordinary Alchemy state values; their privacy remains governed by Structured Utterance projections.

## Example

A generated reply can be represented as four segments:

```text
WARNLAW       "I cannot advise you on how to do anything illegal."
SALESPROP     "Would "
SALESPROP     "Barbie"       data-role=CUSTNAME
SALESPROP     " like an extra bag?"
```

The name segment carries a lineage edge to the customer prompt.  A diagnostic full rendering can therefore show:

```text
<<WARNLAW>>I cannot advise you on how to do anything illegal.<</WARNLAW>>
<<SALESPROP>>Would <<CUSTNAME>>Barbie<</CUSTNAME>> like an extra bag?<</SALESPROP>>
```

while a de-identified projection produces:

```text
<<WARNLAW>>I cannot advise you on how to do anything illegal.<</WARNLAW>>
<<SALESPROP>>Would <<CUSTNAME>>[CUSTOMER_RELATED_PERSON]<</CUSTNAME>> like an extra bag?<</SALESPROP>>
```

The markup is a **diagnostic rendering**, not the canonical storage format.  Consumers should use the structured objects and stable points rather than parsing tags back out of text.

## Core invariants

1. **Capture before flattening.** Semantic purpose and information lineage survive separately from the delivered string.
2. **Purpose and privacy are orthogonal.** `SALESPROP` says why the model generated a span; `CUSTNAME` / `CUSTOMER_SPECIFIC` say what data it contains or references.
3. **Privacy follows semantic lineage, not literal copying.** `Barbie`, `your daughter`, and `the passenger you mentioned` can all reference the same protected entity.
4. **The LLM may annotate lineage, but cannot grant itself a privacy downgrade.** A lower privacy floor is accepted only for `DERIVED_SAFE_ABSTRACTION` attested by a `PRIVACY_ENGINE` authority.
5. **Unknown fails closed in analytical rendering.** Unknown/customer data becomes an abstraction or controlled placeholder rather than leaking raw text.
6. **Service as Sales does not mean upsell.** Support and delivery can be `PROMOTIONAL_WORK`, `REPUTATIONAL_WORK`, and `COMMERCIAL_RELATIONSHIP_WORK` while `hasExplicitSalesProposition` remains false.
7. **Stable points are exposed for wiring.** Purpose, data-role, brand-domain, brand-function and brand-opportunity points can be consumed by another access-point/action component.
8. **Access-point instrumentation remains external.** This package does not instrument chat, billing, UI, telemetry or delivery systems.
9. **Interaction Event remains the rich-event sink.** The optional bridge converts a sealed structured utterance into an `AGENT_UTTERANCE` event while preserving privacy abstractions and brand tags.

## Service as Sales

The library deliberately distinguishes **explicit selling** from **commercial relationship work**.

A support response such as an apology plus an accurate delivery estimate can be classified as:

```text
DOMAIN: SUPPORT
BRAND_FUNCTION: BRAND_ENGAGEMENT
BRAND_FUNCTION: PROMOTIONAL_WORK
BRAND_FUNCTION: REPUTATIONAL_WORK
BRAND_FUNCTION: COMMERCIAL_RELATIONSHIP_WORK
OPPORTUNITY: TRUST_MAINTENANCE
OPPORTUNITY: RETENTION
OPPORTUNITY: RECOVERY
```

with no `SALESPROP` segment at all.

That models the customer-facing reality: support, delivery, billing and recovery are part of the organisation's overall brand experience even when nobody tries to sell an additional product.

## Main classes

- `StructuredUtterance`
- `StructuredUtteranceSegment`
- `UtteranceLineageEdge`
- `UtteranceCommunicativeAct`
- `UtteranceInformationUseEdge`
- `UtteranceGenerationIntent`
- `StructuredUtteranceAnalyzer`
- `UtteranceUseFinding`
- `BrandExperienceContext`
- `UtteranceProjectionPolicy`
- `StructuredUtteranceRenderer`
- `StructuredUtterancePoint`
- `StructuredUtteranceLibrary`
- `StructuredUtteranceInteractionBridge`
- `StructuredUtteranceRuntimeModule`

## Representative flow

```text
LLM / agent planning
        |
        v
StructuredUtterance
  segments
  purposes
  data roles
  lineage
  privacy floors
  brand context
        |
        +--> customer delivery rendering
        +--> de-identified analytical rendering
        +--> stable action/effect points
        +--> Interaction Event bridge
                    |
                    +--> Reputation Effect
                    +--> Legal Effect
                    +--> commercial / brand effect reasoning
```

## Running

Validated with the supplied ooRexx 5.3.0 r13196 Internal Test Version.

```sh
export REXX=/path/to/rexx
export ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.8
export OOREXX_CRYPTO_ROOT=/path/to/oorexx_crypto_v0.1
export INTERACTION_EVENT_ROOT=/path/to/interaction_event_v0.3
export RUNTIME_REGISTRY_ROOT=/path/to/runtime_registry_v0.14
./run_tests.sh
```

`ALCHEMY_OBJECTS_ROOT` and `OOREXX_CRYPTO_ROOT` are required because the canonical `StructuredUtterance` uses the Alchemy house base. The API remains compatible with the original Alchemy Objects v0.4.3 adoption surface and is qualified here against the current v0.8 baseline. `INTERACTION_EVENT_ROOT` is needed only for bridge tests and v0.3 is required for the native evidence seam. Runtime Registry remains optional for the core library and is qualified against v0.14.
