c=.BrandEvidenceCohortAccumulator~new('demo-cohort','UNRESOLVED_SUPPORT_INTERACTION','2026-08-01','2026-08-20',20,'CANCELLATION','SASS','HIGH','TONE-MODEL-V8','COMMUNICATION-STYLE-0.5',86400)
r=c~configureProvenance('demo-prov','INTERACTION_EVENT','SUPPORT_EVENT_STORE','INTERACTION','UNRESOLVED_SUPPORT_V1','ALL_ELIGIBLE','SUPPORT_SCOPE_V2','BOT_TEST_V1','OPAQUE_EVENT_KEY','INTERACTION_EVENT_ID_HASH','BILLING_CANCEL_WITHIN_24H')
if \r~ok then do; say 'ERROR' r~code; exit 1; end
do i=1 to 80
  exposed=(i<=25); outcome=(i<=12) | (i>=26 & i<=30)
  r=c~consider('U-'||i,'INCLUDE',exposed,outcome)
  if \r~ok then do; say 'ERROR' r~code; exit 1; end
end
do i=81 to 90
  r=c~consider('U-'||i,'EXCLUDE','UNKNOWN','UNKNOWN','','OUTSIDE_RELEASE_WINDOW')
  if \r~ok then do; say 'ERROR' r~code; exit 1; end
end
do i=91 to 100
  r=c~consider('U-'||i,'UNKNOWN','UNKNOWN','UNKNOWN','','SOURCE_SCOPE_UNRESOLVED')
  if \r~ok then do; say 'ERROR' r~code; exit 1; end
end
r=c~buildFrame('demo-frame','CURRENT')
if \r~ok then do; say 'ERROR' r~code; exit 1; end
f=r~value
say f~cohortProvenance~canonicalText
say 'ANALYZABLE_2X2_POPULATION='f~populationCount
exit 0
::requires 'BrandEffectEvidence.cls'
