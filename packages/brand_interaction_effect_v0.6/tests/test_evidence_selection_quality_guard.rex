/* A large/effectful frame is not promoted merely because its 2x2 counts look
   impressive when cohort selection provenance is absent or materially incomplete. */

/* No provenance at all: counts/time/effect can pass, cohort quality cannot. */
f=.BrandEvidenceFrame~new('no-prov','CURRENT','SUPPORT_INTERACTION','2026-08-01','2026-08-20',20,100,'CANCELLATION',20,'SASS','HIGH',30,15,'TONE-MODEL-V8','COMMUNICATION-STYLE-0.5',86400)
call assertTrue f~seal~ok,'manual frame seals'
t=.BrandEvidenceThreshold~new('REQUIRE-PROV',60,20,10,5,10,1,1.25,80,95,.false,.true,90,10,10,.true)
r=.BrandEvidenceEngine~new~evaluate(f,t); call assertTrue r~ok,'manual frame evaluates'; a=r~value
call assertTrue a~statisticalSufficient,'count/time threshold passes'
call assertTrue a~effectGate,'effect threshold passes'
call assertFalse a~cohortQualityGate,'missing provenance blocks cohort quality'
call assertEqual 'WEAK_SIGNAL',a~status,'missing provenance prevents supported claim'
call assertContains a~reasons,'COHORT_PROVENANCE_REQUIRED','missing provenance reason'

/* Explicit provenance, but half the selected units have unknown exposure or
   outcome.  The analyzable 2x2 frame remains strong-looking; quality gate fails. */
c=.BrandEvidenceCohortAccumulator~new('incomplete','SUPPORT_INTERACTION','2026-08-01','2026-08-20',20,'CANCELLATION','SASS','HIGH','TONE-MODEL-V8','COMMUNICATION-STYLE-0.5',86400)
call assertTrue c~configureProvenance('prov-incomplete','INTERACTION_EVENT','SUPPORT_EVENT_STORE','INTERACTION','ALL_SUPPORT_V1','ALL_ELIGIBLE','SUPPORT_SCOPE_V1','NONE','OPAQUE_EVENT_KEY','INTERACTION_EVENT_ID_HASH','BILLING_CANCEL_WITHIN_24H')~ok,'configure incomplete provenance'
do i=1 to 100
  if i>50 then do
    r=c~consider('U-'||i,'INCLUDE','UNKNOWN','UNKNOWN')
  end
  else do
    exposed=(i<=20)
    outcome=(i<=10) | (i>=21 & i<=25)
    r=c~consider('U-'||i,'INCLUDE',exposed,outcome)
  end
  call assertTrue r~ok,'candidate accepted'
end
r=c~buildFrame('incomplete-frame','CURRENT'); call assertTrue r~ok,'incomplete frame builds'; f2=r~value
call assertEqual 50,f2~populationCount,'only complete units analyzed'
call assertEqual 50,f2~cohortProvenance~incompleteSelectedCount,'incomplete units retained in provenance'
t2=.BrandEvidenceThreshold~new('MISSINGNESS-GATE',40,15,10,5,10,1,1.25,80,95,.false,.true,80,20,10,.true)
r=.BrandEvidenceEngine~new~evaluate(f2,t2); call assertTrue r~ok,'incomplete frame evaluates'; a2=r~value
call assertTrue a2~statisticalSufficient,'analyzable counts pass threshold'
call assertTrue a2~effectGate,'effect passes threshold'
call assertFalse a2~cohortQualityGate,'missingness fails cohort gate'
call assertEqual 'WEAK_SIGNAL',a2~status,'missingness prevents supported claim'
call assertContains a2~reasons,'COHORT_SELECTED_ANALYSIS_COVERAGE_BELOW_THRESHOLD','coverage reason'
call assertContains a2~reasons,'COHORT_INCOMPLETE_SELECTED_ABOVE_THRESHOLD','incomplete reason'

/* Complete selected units but unresolved eligibility for too many source
   candidates is separately visible and can be thresholded. */
c3=.BrandEvidenceCohortAccumulator~new('selection-unknown','SUPPORT_INTERACTION','2026-08-01','2026-08-20',20,'CANCELLATION','SASS','HIGH','TONE-MODEL-V8','COMMUNICATION-STYLE-0.5',86400)
call assertTrue c3~configureProvenance('prov-unknown','INTERACTION_EVENT','SUPPORT_EVENT_STORE','INTERACTION','ELIGIBILITY_V1','ALL_ELIGIBLE','SUPPORT_SCOPE_V1','OUT_OF_SCOPE_V1','OPAQUE_EVENT_KEY','INTERACTION_EVENT_ID_HASH','BILLING_CANCEL_WITHIN_24H')~ok,'configure unknown provenance'
do i=1 to 80
  exposed=(i<=25); outcome=(i<=12) | (i>=26 & i<=30)
  call assertTrue c3~consider('S-'||i,'INCLUDE',exposed,outcome)~ok,'selected unit'
end
do i=81 to 100
  call assertTrue c3~consider('S-'||i,'UNKNOWN','UNKNOWN','UNKNOWN','','SOURCE_SCOPE_UNRESOLVED')~ok,'selection unknown unit'
end
r=c3~buildFrame('selection-unknown-frame','CURRENT'); call assertTrue r~ok,'unknown frame builds'; f3=r~value
t3=.BrandEvidenceThreshold~new('SELECTION-UNKNOWN-GATE',60,20,10,5,10,1,1.25,80,95,.false,.true,95,5,5,.true)
r=.BrandEvidenceEngine~new~evaluate(f3,t3); call assertTrue r~ok,'unknown frame evaluates'; a3=r~value
call assertFalse a3~cohortQualityGate,'selection uncertainty fails gate'
call assertContains a3~reasons,'COHORT_SELECTION_UNKNOWN_ABOVE_THRESHOLD','selection unknown reason'
say 'PASS test_evidence_selection_quality_guard'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
assertContains: procedure; use arg arr,needle,label; do x over arr; if x==needle then return; end; say 'FAIL:' label 'missing='needle; exit 1
::requires 'BrandEffectEvidence.cls'
