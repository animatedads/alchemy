# Rexx-tronics — intentions and experimental authority sphere

Sphere status: **development evidence / not an acceptance certificate**  
Component: Rexx-tronics (`rexxtronics/0.1`)  
Reviewed line: dev25–dev29 candidate  
Repository publication: review branch; do not infer main-branch release.

## Purpose

Capture the semantic contracts and negative boundaries of Rexx-tronics' conversational virtual laboratory. This sphere documents how natural-language intentions become verifiable actions on real ooRexx objects without replacing the domain engines.

## Owned boundaries

| Concern | Owner | Rexx-tronics responsibility |
| --- | --- | --- |
| Parsing, ambiguity, readiness | ooRexx Intention Service (dev11 qualified reference) | Discover domain capabilities and execute only READY proposals |
| Circuit/device/instrument | Rexx-tronics | Authoritative electrical model and meter loading |
| Physical/mechanical evolution | Physics World | Consume physical state and observations; no duplicate solver |
| Dimensions and numeric comparison | Units / Maths | Preserve typed quantities; delegate RMS/spectrum/difference |
| Rewind/checkpoint | StateOfNationController and JPS | Register state participant; retain native checkpoint references |
| UI | Wire renderer | Project state, not own it |

## Development chronology

- **dev25**: finite-input-resistance `.VoltageMeter` and journalled meter movement; voltage measurement is a physical load, not a passive query.
- **dev26**: live discovery, native object targets, stale-generation rejection, READY-gated mutation.
- **dev27**: `RexxTronicsExperimentPlan`; validate all proposal targets before the first operation to avoid partial stale execution.
- **dev28**: CHECKPOINT and REWIND bound to the shared `StateOfNationController`; checkpoint remains a native object.
- **dev29 source candidate**: dynamic MEASURE discovery for `VOLTAGE_METER`; capture native observation. Not runtime-qualified. RUN and typed numerical COMPARE remain pending.

## Invariants

1. Discovery occurs against the live workspace, not remembered conversation state.
2. An intention target is the identical ooRexx object discovered, not a reconstructed name or DTO.
3. Any removed/replaced target invalidates the plan before mutation.
4. All effectful operations require the Intention Service READY decision plus domain revalidation.
5. Journal checkpoint and rewind use the existing controller; never create a Rexx-tronics-private rewind history.
6. Physical instruments load the circuit. Measuring must not silently change the experiment without an explicit instrument-connection operation.
7. Comparison requires compatible Units dimensions, measurement methods, time windows, excitation and solver assumptions.
8. A/B runs must begin from the same checkpoint and independently record all changed parameters.
9. A stale, ambiguous or unsupported action fails closed; no speculative execution.
10. The assistant's prose is not qualification evidence. A release requires actual runtime test receipts and hashes.

## Next qualification scenario

```text
discover bench + participants
checkpoint A
configure excitation E
RUN duration T using existing simulation authority
MEASURE meter M (typed quantity, sim-time, provenance)
rewind A via shared controller
change exactly parameter P (READY-gated)
configure identical excitation E
RUN same duration T
MEASURE meter M
COMPARE only after dimensional and experimental alignment checks
```

Expected negative tests: stale meter replacement; removed journal participant; mismatched dimension; unequal sample windows; absent READY; invalid checkpoint ownership; solver failure; partially executed proposal rejected before mutation.

## GitHub gap and publication rule

At this review, code search in `animatedads/alchemy` showed historical `packages/rexxtronics_v0.1-dev5` and `packages/rexxtronics_v0.1-dev15` entries, while later dev25–dev29 deliveries were in the chat working history. **Do not promote a sphere into a substitute for source publication.** Reconcile the latest source against the repository, publish owned code/tests/docs without embedded dependency trees, then run the full ooRexx r13196 suite before merging.

## Evidence classification

- Library: Project Alchemy evidence register reports Intention Service dev11 and scientific-intention native object preservation.
- Earlier Rexx-tronics development-turn artifacts: dev25 through dev28 qualified claims; dev29 explicitly a source candidate.
- Current GitHub inspection: public historical source trees and a dev29 review branch.
- No fresh dev29 runtime qualification or complete source synchronization is claimed by this sphere.
