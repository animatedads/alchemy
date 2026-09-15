# Structured Utterance v0.3 Architecture

## v0.3 bridge boundary

```text
Generation planning
      |
      v
StructuredUtterance
  - realised segments
  - communicative acts
  - lineage/privacy floors
  - information-use edges
  - generation intents
  - derived use findings
      |
      | native bridge
      v
InteractionEvent v0.2
  - InteractionInformationUseEvidence
  - InteractionGenerationIntentEvidence
  - InteractionDerivedFinding
  - privacy-classified delivered content
```

The bridge passes only controlled ids/tokens/scalars in the native generation-evidence channel. Sensitive/raw wording stays in privacy-classified content elements and remains subject to Interaction Event projection. Compatibility tags are routing hints, not the authoritative evidence copy.


## Boundary

The package sits immediately after agent/LLM response planning and before final text is discarded as the only representation.

```text
                  policy / customer context
                           |
                           v
                    Agent / LLM planner
                           |
             rich generation annotations
                           v
                +-----------------------+
                | Structured Utterance  |
                +-----------------------+
                  |       |       |
        delivery --+       |       +-- semantic/action points
                          |
                    safe projection
                          |
                          +----------> Interaction Event
```

It does not decide whether a legal basis exists for processing data, whether a promotion should be shown, or which UI hook fires an action.  It preserves enough structure for those components to make informed decisions.

## Two independent annotation axes

### Communicative purpose

A segment has a primary purpose such as `WARNLAW`, `SALESPROP`, `APOLOGY`, or `SERVICE_RESOLUTION`, plus optional additional roles.

This answers: **what organisational/linguistic act is this text performing?**

### Data role and lineage

The same segment may carry `CUSTNAME`, `CUSTREF`, `CUSTDATA`, or `CUSTSENSITIVE` plus one or more lineage edges.

This answers: **what information does this text depend on, and what privacy floor follows it?**

A sales proposition can therefore contain customer data without the whole sales proposition being treated as customer data.

## Semantic lineage

Lineage supports:

- `COPIED_FROM_CUSTOMER`
- `REFERENCES_CUSTOMER_ENTITY`
- `DERIVED_FROM_CUSTOMER_FACT`
- `INFERRED_FROM_CUSTOMER_DATA`
- `DERIVED_FROM_EXTERNAL_DATA`
- `MODEL_GENERATED`
- `SYSTEM_POLICY`
- `DERIVED_SAFE_ABSTRACTION`

The source can be an entity/fact/span reference rather than literal text.  Therefore privacy can follow `your daughter` even if those words never occurred in the customer's prompt.

Each lineage edge carries a source privacy class and a privacy floor.  The model may conservatively classify output, but it may not lower the floor.  A downgrade requires the special `DERIVED_SAFE_ABSTRACTION` lineage and `PRIVACY_ENGINE` authority.

## Service as Sales / brand experience

`BrandExperienceContext` distinguishes operational domain from brand/commercial effect.

Operational domains include support, delivery, sales, billing, operations and security.

Brand functions include:

- `BRAND_ENGAGEMENT`
- `PROMOTIONAL_WORK`
- `REPUTATIONAL_WORK`
- `COMMERCIAL_RELATIONSHIP_WORK`

Opportunities/risks include trust maintenance, recovery, retention, advocacy, acquisition, purchase, commercial opportunity, churn risk and reputational risk.

A support interaction can be promotional and reputational work **without** containing a `SALESPROP`.  This prevents `Service as Sales` from degenerating into `upsell every support caller`.

## Points

A sealed captured utterance exposes stable points such as:

```text
STRUCTURED_UTTERANCE:service-1
STRUCTURED_UTTERANCE:service-1:SEGMENT:s1:PURPOSE:APOLOGY
STRUCTURED_UTTERANCE:service-1:BRAND_FUNCTION:PROMOTIONAL_WORK
STRUCTURED_UTTERANCE:service-1:BRAND_OPPORTUNITY:RETENTION
```

Another component can wire those points to actions, effect models, event capture, auditing or experimentation.

## Interaction Event bridge

The bridge emits one sealed `InteractionEvent` of kind `AGENT_UTTERANCE`.

Each structured segment becomes an `InteractionContentElement` with the segment's raw value, abstraction, privacy class and retention class.  Event metadata retains purpose, data role and lineage summary.  Brand domains/functions/opportunities become controlled event tags.

This is intentionally one-way: the system should not reconstruct canonical structured utterances from flattened interaction events.


## Generation intent is captured before flattening

A transcript retains only rendered language. v0.2 separately persists the generating agent's contemporaneous declaration of the act/register/outcome it was trying to realise. This record is **not** treated as truth about how the language was received. It is generation-intent evidence which can later be compared with independent communication-style assessment, customer behaviour and commercial/reputational outcomes.

```text
DECLARED GENERATION INTENT
          |
          v
REALISED LANGUAGE
          |
          v
INDEPENDENT ASSESSMENT
          |
          v
CUSTOMER BEHAVIOUR / OUTCOME
```

That preserves the distinction between a strategy/policy failure (the agent intended the wrong act), a language-realisation failure (the intended act was reasonable but the wording came out sassy/dismissive), and a downstream effect which may or may not be causally attributable.

## Information-use graph

Lineage says where information came from. `UtteranceInformationUseEdge` says how that information participated in another communicative act. The source segment does not have to be lexically inside the target act. This permits pre-flattening capture of dependencies which disappear from the final sales sentence.

`declaredUse` is the model's own contemporaneous label. `effectiveUse` is derived from structural act + relation evidence. The analyzer currently exposes two candidate findings:

- `SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING`;
- `DECLARED_INFORMATION_USE_MISMATCH`.

These are evidence points, not legal or moral conclusions. Legal Effect, Reputation Effect, Brand Interaction Effect or organisational policy remains responsible for deciding significance.

## Alchemy house base

The canonical `StructuredUtterance` inherits `AlchemyObject` v0.4.3. The integration intentionally registers bounded identity/lifecycle state and method/instrumentation contracts without duplicating raw segment content into generic base-class state. Structured Utterance privacy projections remain the content-disclosure authority for this package.
