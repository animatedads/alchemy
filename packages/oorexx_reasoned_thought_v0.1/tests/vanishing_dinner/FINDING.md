# Independent red-team finding: elimination by silence

Claude (Opus 4.8) identified that the original WorldEnsemble~survivors rejected a possible world if that world omitted an admitted observation's field. The assess method already treated omitted queried fields as UNKNOWN_IN_MODEL, so the two paths were inconsistent.

**Falsifier:** admit ACQUIRER_BATCH_ID=YES, which none of six worlds represent. Original survivors returned zero; assess('SETTLED','YES') incorrectly returned MODEL_OR_EVIDENCE_CONFLICT, though all six remained logically possible.

**Repair:** replace elimination on missing field with 'if \w~hasIndex(field) then iterate'. Silence remains unconstrained; explicit conflicting values still eliminate a world.

**Reproduced with isolated ooRexx 5.3.0 r13196:** original benchmark 39/39; original plus Claude's new regression fails; repaired 39/39 plus new regression 7/7 passes.

The suite demonstrates finite countermodel reasoning only; it does not authenticate documents or guarantee that an investigation's candidate worlds are complete.
