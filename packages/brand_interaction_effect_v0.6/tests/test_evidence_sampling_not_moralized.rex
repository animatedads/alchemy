/* Selection facts are evidence, not morality. A narrow or convenience sample is
   not automatically labelled biased by the capture/evidence layer. */
c=.BrandEvidenceCohortAccumulator~new('sampling-demo','SUPPORT_INTERACTION','2026-08-01','2026-08-20',20,'CANCELLATION','SASS','HIGH','TONE-MODEL-V8','COMMUNICATION-STYLE-0.5',86400)
call assertTrue c~configureProvenance('sampling-prov','INTERACTION_EVENT','SUPPORT_EVENT_STORE','INTERACTION','MANUAL_REVIEW_QUEUE_V1','CONVENIENCE','MANUAL_REVIEW_SCOPE_V1','NOT_IN_REVIEW_QUEUE_V1','OPAQUE_EVENT_KEY','INTERACTION_EVENT_ID_HASH','BILLING_CANCEL_WITHIN_24H')~ok,'configure convenience provenance'
do i=1 to 80
  exposed=(i<=25); outcome=(i<=12) | (i>=26 & i<=30)
  call assertTrue c~consider('C-'||i,'INCLUDE',exposed,outcome)~ok,'included'
end
do i=81 to 200
  call assertTrue c~consider('C-'||i,'EXCLUDE','UNKNOWN','UNKNOWN','','NOT_IN_MANUAL_REVIEW_QUEUE')~ok,'excluded'
end
r=c~buildFrame('sampling-frame','CURRENT'); call assertTrue r~ok,'frame builds'; f=r~value
p=f~cohortProvenance
call assertTrue p~selectedPct<50,'selection rate is narrow'
call assertEqual 'CONVENIENCE',p~samplingMethod,'sampling fact preserved'
t=.BrandEvidenceThreshold~new('NO-MORALIZE',60,20,10,5,10,1,1.25,80,95,.false,.true,95,5,0,.true)
r=.BrandEvidenceEngine~new~evaluate(f,t); call assertTrue r~ok,'evaluates'; a=r~value
call assertTrue a~cohortQualityGate,'narrow convenience sampling not automatically failed'
call assertEqual 'SUPPORTED',a~status,'scoped claim may still be supported under configured gates'
say 'PASS test_evidence_sampling_not_moralized'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandEffectEvidence.cls'
