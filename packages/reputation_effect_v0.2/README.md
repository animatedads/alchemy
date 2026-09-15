# Reputation Effect v0.2

`Reputation Effect` is an independent ooRexx domain module for evaluating a proposed action against a time-bounded, geographic, audience-specific reputation context.

It deliberately does **not** expose `reputationScore(person)` or a universal good/bad score. The public question is:

> Given this proposed action, this actor, these associations, these audiences and geographies, the current evidence, and this frozen reputation snapshot, what reputation concerns or supports apply here and now?

## Core invariants

1. **Independent domain** — core `ReputationEffect.cls` does not depend on HardWorld, Legal Effect, Queue Fabric, NoSQLServer, Shannon, or Reputation Feed.
2. **Geography is first-class** — effects may differ by country, region, constituent territory, or market hierarchy; propagation is explicit.
3. **Observed geography and affected geography are distinct** — where evidence was observed is not assumed to be where it matters.
4. **Time/freshness is first-class** — stale or uncovered context fails closed with `HOLD_REFRESH_REQUIRED`.
5. **Action-in-context, not person score** — equipment, manufacturer, sector, target actor, semantic themes, audience, geography, brand norms, current events and communication behaviour are evaluated together.
6. **Brand history is evidence, not permission** — historic competitor mockery can support a cheeky response to embarrassment but does not erase human-harm concerns.
7. **Association distance matters** — affected equipment/manufacturer differs from unrelated competitor equipment; sector adjacency is weaker.
8. **Semantic collision is deterministic** — upstream models may propose concepts, but governed evaluation uses retained concepts and a shallow relation graph.
9. **Communication behaviour is first-class** — unresolved process failures, sales prompts, circular redirects, corrections, evidential limits and declared intent are represented explicitly.
10. **Recovery is representable** — correcting a prior claim can create `REPUTATIONAL_RECOVERY` support without pretending the original response never happened.
11. **Declared intent is checked against performed action** — saying “I will stop selling” while immediately qualifying a deal can produce `DECLARED_INTENT_ACTION_MISMATCH`.
12. **Sealed replay objects** — events, snapshots, actions and communication surfaces seal before canonical evaluation.
13. **Runtime publication is by registry** — Runtime Registry v0.11 owns executable generation lifecycle; Reputation Effect owns reputation semantics.

## Communication surface

`ReputationCommunicationSurface` attaches to a `ReputationActionSurface` and retains:

- unresolved communication/process failures (`ReputationCommunicationFailure`);
- response acts (`ReputationCommunicationAct`) such as `ACKNOWLEDGEMENT`, `EVIDENCE_LIMIT`, `PROCESS_OWNERSHIP`, `REDIRECT`, `SALES_PROMPT`, `PROCUREMENT_INFO`, `RETRACTION`, `CORRECTIVE_STATEMENT`, and `DECLARED_INTENT`;
- recipient relationship and institutional context;
- optional prior-response identity and evidence anchors.

The v0.2 evaluator adds these evidence-bearing signals:

- `COMMERCIAL_PRESSURE_COLLISION`
- `PROCESS_CIRCULARITY`
- `DECLARED_INTENT_ACTION_MISMATCH`
- `REPUTATIONAL_RECOVERY` (support)
- `COMMERCIAL_RESTRAINT` (support)
- `EVIDENTIAL_DISCIPLINE` (support)

The paired synthetic customer-service acceptance case deliberately evaluates two alternative responses to the **same unresolved customer state** rather than scoring vendors globally.

## Geographic dispositions

Per geography:

- `CLEAR`
- `WARN`
- `REVIEW`
- `HOLD`
- `HOLD_REFRESH_REQUIRED`

A multi-geography action whose geographic decisions differ reports `GEOGRAPHICALLY_CONFLICTED`; callers inspect the individual geographic decisions.

## Existing airline acceptance cases retained

- OurLadyAir + Boeing + affected equipment + `EXTRA_LEGROOM` can produce `HOLD` after a cabin-opening incident.
- FlyLo + Airbus does not inherit direct Boeing association.
- The same creative can be `HOLD` in GB and `WARN` in Greece.
- `MILE_HIGH_CLUB` / flat-bed creative can collide with recent passenger ejection/fatality context.
- Virgin-style competitor mockery can remain `CLEAR` for a non-harm embarrassment when supported by a historic geographic/audience brand norm and competitor relationship.
- The same mockery pattern against fatal human harm yields `EXPLOITATION_OF_HUMAN_HARM` and `HOLD`.
- Stale or unknown context fails closed.

## Running

Validated with the Architect-supplied ooRexx 5.3.0 r13196 debug build.

```sh
export REXX=/path/to/rexx
export RUNTIME_REGISTRY_ROOT=/path/to/runtime_registry_v0.11
./run_tests.sh
```

`RUNTIME_REGISTRY_ROOT` is optional; when present the staging/activation/acquisition test is run.

## Feeding boundary

Publication acquisition, syndication/AI-rewrite lineage, reach and range are deliberately **not** part of this module. Those live in companion `reputation_feed_v0.1`. The feed may promote evidence into `ReputationObservation`; it does not create authoritative `ReputationEvent` or decisions by itself.

## Supplied-base provenance

This cut supersedes `reputation_effect_v0.1` and was validated against the previous roll-up:

- `oorexx-libs(20260822-041619).zip`
- SHA-256 `d50ef7c77398de5ef8214c33c4b92cb9d058c3f9e72caa4963ee93e89dfc63e6`

Interpreter package:

- `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(5).deb`
- SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`
