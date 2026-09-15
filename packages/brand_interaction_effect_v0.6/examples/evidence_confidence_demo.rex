f=.BrandEvidenceFrame~new('sass-q3','CURRENT','UNRESOLVED_SUPPORT_INTERACTION','2026-06-01','2026-08-21',82,29234,'CANCELLATION',109,'SASS','HIGH',29,12,'TONE-MODEL-V7','COMMUNICATION-STYLE-0.4',86400)
f~addSupportPoint('BRAND_INTERACTION:EVIDENCE:CASE-17')
f~addCounterPoint('BRAND_INTERACTION:EVIDENCE:CASE-22')
f~seal
t=.BrandEvidenceThreshold~new('SUPPORT-SASS-V2',1000,25,20,5,14,1,1.25,80,95,.true)
a=.BrandEvidenceEngine~new~evaluate(f,t)~value
say a~canonicalText
::requires 'BrandEffectEvidence.cls'
