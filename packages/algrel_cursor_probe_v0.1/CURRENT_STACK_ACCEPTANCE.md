# Current native-evidence → Algorithm Relation cursor acceptance

This acceptance path is intentionally narrow. It proves the integration boundary without assigning
SQL semantics to Structured Relation, HardWorld semantics to the probe, or PNRGOV parsing to Shannon.

## Evidence selected

The supplied fictional Shannon PNRGOV fixture is parsed by Structured Relation's native EDIFACT model.
The probe projects `SEGMENT:SSR` and selects exactly the three functional-group `G07` `NSST` facts.
Each `service_value` fact is adapted to the existing HardWorld rich-evidence contract without copying or
stringifying its native EDIFACT source object.

## Boundary assertions

Before Algorithm Relation execution the server asserts, by object identity, that:

- `RichEvidenceValue.nativeObject` is the original Structured Relation fact source object;
- its `RichEvidenceSourceRef.nativeObject` is the same object;
- its structured context retains the original `RichBusinessFact` and `EdiFactProjectedRow` objects;
- the frozen `AlgorithmInputRelationSnapshot` still contains those same rich evidence objects.

The Algorithm Relation provider is registered through the externally supplied HardWorld external engine. The
probe records the engine's reported `NOSQL-ALGREL-EXTERNAL-*` identity instead of owning that version string;
a release run may require an exact expected identity. No provider execution occurs during catalog or
prepared-statement metadata discovery. First cursor EXECUTE
materialises the provider once. Batched `COM_STMT_FETCH` and subsequent reads reuse that frozen result.

The MySQL consumer receives scalar columns (`fact_id`, `source_format`, `source_path`, `lexical_value`)
for queryability. It receives three distinct source paths and `SEAT NOT PURCHASED` values; the provider's
provenance relation reports `NATIVE_OBJECT_PRESERVED`, while the pre-boundary rich objects remain intact.

## Non-ownership

- NoSQLServer owns SQL/federation semantics.
- HardWorld owns the rich-evidence bridge and Algorithm Relation materialisation semantics used here.
- msqlshim owns MySQL cursor framing.
- Shannon owns application interpretation of the PNRGOV booking fixture.
- This probe owns only the deterministic integration seam and its assertions.


## Requalification

`REQUALIFICATION_20260825.md` records the current declared target stack and the exact rules for rerunning this seam when those external archives are mounted.
