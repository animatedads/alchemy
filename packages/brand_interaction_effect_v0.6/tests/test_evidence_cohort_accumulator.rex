/* Population counts can be constructed from privacy-minimised analysis units
   rather than hand-entered totals. Duplicate units must not double count. */
c=.BrandEvidenceCohortAccumulator~new('cohort-1','SUPPORT_INTERACTION','2026-08-01','2026-08-20',20,'CANCELLATION','SASS','HIGH','TONE-MODEL-V8','COMMUNICATION-STYLE-0.5',86400)
do i=1 to 100
  exposed=(i<=20)
  outcome=.false
  if i<=8 then outcome=.true
  else if i>20 & i<=24 then outcome=.true
  r=c~observe('INTERACTION-'||i,exposed,outcome)
  call assertTrue r~ok,'unit accepted'
end
r=c~observe('INTERACTION-1',.true,.true); call assertFalse r~ok,'duplicate rejected'
call assertEqual 'COHORT_DUPLICATE_UNIT',r~code,'duplicate code'
call assertEqual 100,c~populationCount,'population deduped'
call assertEqual 20,c~exposedCount,'exposed count'
call assertEqual 12,c~outcomeCount,'outcome count'
call assertEqual 8,c~exposedOutcomeCount,'joint count'
call assertEqual 1,c~duplicateCount,'duplicate recorded'
r=c~buildFrame('cohort-frame','CURRENT'); call assertTrue r~ok,'frame built'; f=r~value
call assertTrue f~sealed,'frame sealed'
call assertEqual 100,f~populationCount,'frame population'
call assertEqual 20,f~exposedCount,'frame exposed'
call assertEqual 12,f~outcomeCount,'frame outcome'
call assertEqual 8,f~exposedOutcomeCount,'frame joint'
t=.BrandEvidenceThreshold~new('COHORT-TEST',60,15,10,5,10,1,1.25,80,95,.true)
r=.BrandEvidenceEngine~new~evaluate(f,t); call assertTrue r~ok,'frame evaluates'; a=r~value
call assertTrue a~confidenceGate,'cohort supports bounded association'
call assertEqual 'SUPPORTED',a~status,'cohort can support scoped association'
say 'PASS test_evidence_cohort_accumulator'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandEffectEvidence.cls'
