# Reputation Effect v0.2 architecture

## Boundary

Reputation Effect remains separate from HardWorld, Legal Effect and feed acquisition.

- HardWorld: what is known/unknown/conflicted as fact.
- Legal Effect: what normative authority applies.
- Reputation Feed: how publication/evidence streams are acquired, lineage-grouped, and measured for reach/range.
- Reputation Effect: how a proposed action intersects current salience, associations, audience/brand expectations, geography, and communication behaviour.

## Evaluation path

```text
ReputationObservation / evidence
              |
              v
        ReputationEvent
       / subjects / concepts
      / geographic effects
              |
              v
      ReputationSnapshot  <--- brand norms / actor relationships
              |
              +------------------------------+
                                             |
                                  ReputationActionSurface
                                 / actor / equipment / concepts
                                / audience / geography / behaviour
                               / optional communication surface
                                             |
                                             v
                                  ReputationEngine
                              / association distance
                             / semantic collision
                            / freshness / brand norm
                           / human-harm boundary
                          / communication consistency
                                             |
                                             v
                            ReputationGeographicDecision[]
                                             |
                                             v
                                ReputationDecision
```

## Geographic model

`ReputationGeographyCatalog` provides explicit parentage. Event effects select `NONE`, `DESCENDANTS`, `ANCESTORS`, or `BOTH`. Snapshot coverage and event-effect propagation are separate questions.

## Association and semantic model

Actions carry explicit associations (`MANUFACTURER`, `EQUIPMENT`, `SECTOR`, etc.). Events carry independent subject links. The concept graph is deterministic and shallow; it can retain exact/one-hop/two-hop collision evidence without letting an LLM make the governed disposition.

## Brand norms and relationships

`ReputationBrandNorm` represents evidenced audience expectation, not moral permission. `ReputationRelationship` records actor relationships such as `COMPETITOR`. Historic mockery can support a response to embarrassment; human harm is evaluated separately and can dominate.

## Communication model

`ReputationCommunicationSurface` is attached to an action rather than treated as free text. It contains explicit acts and unresolved failures.

This allows deterministic relations such as:

```text
OPEN PROCESS FAILURE + SALES_PROMPT
    -> COMMERCIAL_PRESSURE_COLLISION

REDIRECT -> ROUTE ALREADY REPRESENTED AS FAILED
    -> PROCESS_CIRCULARITY

DECLARED STOP_SELLING + SALES_PROMPT/PROCUREMENT CONTINUATION
    -> DECLARED_INTENT_ACTION_MISMATCH

RETRACTION + CORRECTIVE_STATEMENT + EVIDENCE_LIMIT/PROCESS_OWNERSHIP
    -> REPUTATIONAL_RECOVERY (support)
```

Support signals are retained as evidence; they do not erase concern history or subtract from concern severity by magic.

## Freshness

Default maximum context age:

| Reach class | Max age |
| --- | ---: |
| NORMAL | 120 min |
| HIGH_REACH | 30 min |
| LIVE_MAJOR_EVENT | 15 min |
| CRITICAL | 5 min |

Unknown coverage and stale context fail closed with distinct codes.

## Evidence and replay

Events, snapshots, action surfaces and communication surfaces seal before canonicalisation. Corrections are represented as new communication acts/evidence rather than historical deletion.

## Runtime lifecycle

`ReputationRuntimeModule` supports `runtimeStart`, `runtimeQuiesce`, and `runtimeStop`, and publishes as module kind `REPUTATION_RULES` with API `reputation.effect/0.2` through Runtime Registry v0.11.

The Registry owns generation publication; Reputation Effect owns reputation semantics.
