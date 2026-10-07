# ooRexx Intentions Scientific Solver — v0.1-dev2

A provider-facing Intentions package for the **rent-a-PhD** seam: other components
submit native ooRexx domain objects and dynamically obtain an appropriate scientific
specialist without embedding Maths, ML, ML Graph, Physics, Rexxtronics, or
consumer-domain semantics into Intentions itself.

## Provider contract

`scientific.solver/0.1` remains source-compatible with dev1.

Supported Intentions routes include Maths, ML, ML Graph, Physics, Rexxtronics,
coupled/multidisciplinary work, and an AUTO scientific fallback.

## dev2 seam strengthening

- named capability registration is replaceable and removable;
- the live registry has a monotonic `capabilityRevision`;
- capabilities advertise an open native property directory;
- requests can state hard capability requirements;
- requirement filtering occurs before specialist scoring;
- `ScientificSolverSelection` records registry revision, eligible candidates,
  candidate scores/reasons, and the selected capability object;
- selection evidence is attached to `ScientificSolverResult`;
- subject/context/evidence/result objects remain native ooRexx objects throughout.

Default capability properties are `SIDE_EFFECT_CLASS=READ_ONLY`,
`OBJECT_TRANSPORT=NATIVE_REXX`, and `AUTHORITY_ROLE=SPECIALIST`.

The provider does **not** claim scientific authority. A selected specialist owns its
science and evidence. The provider owns dynamic discovery, contract matching,
selection, and transport.

## Qualification

Run:

```sh
tools/test_environment.sh
```

The environment qualification covers the original dev1 routing/object/discovery
contracts plus dev2 requirement matching, selection evidence, registry revision,
capability replacement/removal, and native subject identity preservation.

The separate ONS spreadsheet → Intentions → Scientific Solver → MLGraph → PDF
qualification is the reference consumer pattern for this seam.
