/* Small N must not become a statistical conclusion merely because the effect
   looks dramatic; high materiality may justify investigation, not proof. */
f=.BrandEvidenceFrame~new('enterprise-small','CURRENT','ENTERPRISE_SUPPORT_INTERACTION','2026-08-01','2026-08-07',7,7,'ACCOUNT_EXIT',4,'DISMISSIVENESS','HIGH',5,4,'TONE-MODEL-V7','COMMUNICATION-STYLE-0.4',172800)
f~setMateriality(96,4,2400000)
f~addSupportPoint('BRAND_INTERACTION:EVIDENCE:ENTERPRISE-1')
call assertTrue f~seal~ok,'frame seals'
t=.BrandEvidenceThreshold~new('ENTERPRISE-TONE-V1',1000,25,20,5,14,1,1.25,80)
r=.BrandEvidenceEngine~new~evaluate(f,t); call assertTrue r~ok,'evaluates'; a=r~value
call assertFalse a~statisticalSufficient,'small sample not statistically sufficient'
call assertTrue a~materialInvestigation,'materiality recognised'
call assertEqual 'MATERIAL_INVESTIGATION',a~status,'investigate not generalise'
call assertTrue a~thresholdCoveragePct<100,'threshold figure says undersized'
p=.BrandEffectEvidencePacket~new('enterprise-p1','HIGH_DISMISSIVENESS_REQUIRES_INVESTIGATION','DISMISSIVENESS',f,t,a)
p~addSupportPoint('BRAND_INTERACTION:EVIDENCE:ENTERPRISE-1')
p~permitInterpretation('INVESTIGATE_HIGH_VALUE_EXIT_CASES')
p~prohibitInterpretation('POPULATION_WIDE_CAUSAL_CLAIM')
call assertTrue p~seal~ok,'material investigation packet seals'
call assertTrue p~canonicalText~pos('COMMERCIAL_VALUE_AT_RISK=2400000')>0,'material weight retained'
say 'PASS test_evidence_insufficient_materiality'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandEffectEvidence.cls'
