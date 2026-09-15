/* Cohort evidence must retain how source candidates became the analyzable
   population without persisting opaque unit identifiers or customer prose. */
c=.BrandEvidenceCohortAccumulator~new('cohort-prov','UNRESOLVED_SUPPORT_INTERACTION','2026-08-01','2026-08-20',20,'CANCELLATION','SASS','HIGH','TONE-MODEL-V8','COMMUNICATION-STYLE-0.5',86400)
r=c~configureProvenance('prov-1','INTERACTION_EVENT','SUPPORT_EVENT_STORE','INTERACTION','UNRESOLVED_SUPPORT_ALL_ELIGIBLE_V1','ALL_ELIGIBLE','SUPPORT_SCOPE_V2','BOT_TEST_AND_OUT_OF_WINDOW_V1','OPAQUE_EVENT_KEY','INTERACTION_EVENT_ID_HASH','BILLING_CANCEL_WITHIN_24H')
call assertTrue r~ok,'provenance configured'
c~addProvenanceLimitation('OUTCOME_CAPTURE_REQUIRES_BILLING_LINKAGE')

do i=1 to 100
  exposure=(i<=20)
  outcome=.false
  if i<=8 then outcome=.true
  else if i>=21 & i<=26 then outcome=.true
  if i=99 then exposure='UNKNOWN'
  if i=100 then outcome='UNKNOWN'
  r=c~consider('INTERACTION-'||i,'INCLUDE',exposure,outcome)
  call assertTrue r~ok,'included candidate accepted'
end
do i=101 to 110
  r=c~consider('INTERACTION-'||i,'EXCLUDE','UNKNOWN','UNKNOWN','','OUTSIDE_MODEL_RELEASE_WINDOW')
  call assertTrue r~ok,'excluded candidate accepted'
end
do i=111 to 120
  r=c~consider('INTERACTION-'||i,'UNKNOWN','UNKNOWN','UNKNOWN','','MISSING_SESSION_SCOPE')
  call assertTrue r~ok,'unknown-selection candidate accepted'
end
r=c~consider('INTERACTION-1','INCLUDE',.true,.true)
call assertFalse r~ok,'duplicate rejected'
call assertEqual 'COHORT_DUPLICATE_UNIT',r~code,'duplicate code'

call assertEqual 120,c~sourceCandidateCount,'candidate count'
call assertEqual 100,c~selectedCount,'selected count'
call assertEqual 98,c~populationCount,'analyzable population'
call assertEqual 10,c~excludedCount,'excluded count'
call assertEqual 10,c~selectionUnknownCount,'selection unknown count'
call assertEqual 2,c~incompleteSelectedCount,'incomplete selected count'
call assertEqual 1,c~missingExposureCount,'missing exposure count'
call assertEqual 1,c~missingOutcomeCount,'missing outcome count'
call assertEqual 1,c~duplicateCount,'duplicate attempts counted'

r=c~buildFrame('cohort-prov-frame','CURRENT'); call assertTrue r~ok,'frame built'; f=r~value
p=f~cohortProvenance
call assertTrue p\==.nil,'provenance attached'
call assertTrue p~sealed,'provenance sealed'
call assertEqual 120,p~sourceCandidateCount,'provenance candidates'
call assertEqual 98,p~analyzableCount,'provenance analyzable'
call assertTrue p~selectedAnalysisCoveragePct>97,'selected analysis coverage'
call assertTrue p~selectionUnknownPct>8,'selection unknown percentage'
text=f~canonicalText
call assertTrue text~pos('SELECTION_RULE_ID=UNRESOLVED_SUPPORT_ALL_ELIGIBLE_V1')>0,'selection rule travels'
call assertTrue text~pos('SAMPLING_METHOD=ALL_ELIGIBLE')>0,'sampling method travels'
call assertTrue text~pos('OUTCOME_ASCERTAINMENT_ID=BILLING_CANCEL_WITHIN_24H')>0,'outcome ascertainment travels'
call assertTrue text~pos('EXCLUSION_REASON=OUTSIDE_MODEL_RELEASE_WINDOW:10')>0,'exclusion reason count travels'
call assertTrue text~pos('SELECTION_UNKNOWN_REASON=MISSING_SESSION_SCOPE:10')>0,'unknown-selection reason count travels'
call assertTrue text~pos('COHORT_LIMITATION=OUTCOME_CAPTURE_REQUIRES_BILLING_LINKAGE')>0,'limitation travels'
call assertTrue text~pos('INTERACTION-1')=0,'opaque unit ids do not travel'

t=.BrandEvidenceThreshold~new('PROVENANCE-GATE',60,15,10,5,10,1,1.25,80,95,.false,.true,95,5,10,.true)
r=.BrandEvidenceEngine~new~evaluate(f,t); call assertTrue r~ok,'evaluates'; a=r~value
call assertTrue a~statisticalSufficient,'statistical gate'
call assertTrue a~effectGate,'effect gate'
call assertTrue a~cohortQualityGate,'cohort quality gate'
call assertEqual 'SUPPORTED',a~status,'scoped supported association'
say 'PASS test_evidence_cohort_provenance'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandEffectEvidence.cls'
