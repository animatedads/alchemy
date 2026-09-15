f=.BrandEvidenceFrame~new('sass-q3','CURRENT','UNRESOLVED_SUPPORT_INTERACTION','2026-06-01','2026-08-21',82,29234,'CANCELLATION',109,'SASS','HIGH',29,12,'TONE-MODEL-V7','COMMUNICATION-STYLE-0.4',86400)
f~addSupportPoint('CASE:SUPPORTING-17'); f~addCounterPoint('CASE:COUNTER-22'); f~seal
t=.BrandEvidenceThreshold~new('SUPPORT-SASS-V1',1000,25,20,5,14,1,1.25,80)
a=.BrandEvidenceEngine~new~evaluate(f,t)~value
p=.BrandEffectEvidencePacket~new('sass-cancel','HIGH_DISMISSIVE_SASS_ASSOCIATED_WITH_CANCELLATION','SASS',f,t,a)
p~addSupportPoint('CASE:SUPPORTING-17'); p~addCounterPoint('CASE:COUNTER-22')
p~addConfounder('PREEXISTING_CUSTOMER_DISSATISFACTION')
p~addScopeExclusion('FRIENDLY_BANTER')
p~permitInterpretation('INVESTIGATE_WITHIN_THIS_COHORT_AND_WINDOW')
p~prohibitInterpretation('SASS_ALWAYS_CAUSES_CANCELLATION')
p~seal
say .BrandToneAppropriatenessReport~new('tone-demo',p)~reasoningMaterial
::requires 'BrandEffectEvidence.cls'
