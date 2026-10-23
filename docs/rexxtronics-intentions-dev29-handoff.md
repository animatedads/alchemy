# Rexx-tronics intentions — dev29 handoff

Status: SOURCE CANDIDATE; not a qualified release.

## Current source

The development archive `rexxtronics_v0.1-dev29_measure_source.zip` is available in the project ChatGPT delivery history. It was derived from Rexx-tronics dev28. The archive must be reconciled against the existing repository component tree before publication as authoritative source; this note is not a substitute for source code.

## Implemented candidate

- Discover MEASURE for registered VOLTAGE_METER instances dynamically.
- Retain actual native ooRexx target and observation objects.
- Preserve whole-experiment stale-discovery checks and READY gating.
- Preserve shared StateOfNationController as sole journal/checkpoint/rewind authority.

## Outstanding gates

1. Locate the repository's canonical Rexx-tronics component directory and compare dev28 source against its current head.
2. Import owned source, tests and docs from dev29, excluding bundled deps and generated archives.
3. Qualify against ooRexx 5.3.0 r13196, including inherited regression tests.
4. Bind RUN to the existing simulation stepper; do not create a competing solver.
5. Bind typed MEASURE and COMPARE to Units/Maths, rejecting incompatible dimensions and unaligned conditions.
6. Test A/B checkpoint–run–measure–rewind–run–measure–compare with deterministic replay.
7. Review and merge only after successful qualification.

## Authority

Intention Service: interpretation and READY. Rexx-tronics: electrical/instrument behaviour. Physics World: mechanics. Maths/Units: numerical and dimensional semantics. StateOfNationController: checkpoint and rewind.
