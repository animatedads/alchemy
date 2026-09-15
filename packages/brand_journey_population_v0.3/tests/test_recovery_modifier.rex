p=.BrandJourneyPopulation~new('recovery-strata')
b=.BrandJourneyPopulationAggregateBucket~new('recovery-bucket','2026-08-01T00:00:00Z','2026-08-15T23:59:59Z','SUPPORT_TO_DELIVERY_UNRESOLVED','CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',1000,50,200,40,'JOURNEY-V3','JTAX-1','PROC-8','MODEL-5',86400,'SERVICE_RECOVERY_ACROSS_DOMAIN',100,5)
b~addSupportPoint('BRAND_JOURNEY:CASE:RECOVERY-OUTCOME'); b~addCounterPoint('BRAND_JOURNEY:CASE:RECOVERY-SUCCESS'); call assertTrue b~seal~ok,'bucket seals'; p~addBucket(b); p~seal
c=.BrandJourneyCohortDefinition~new('recovery-current','CURRENT','SUPPORT_TO_DELIVERY_UNRESOLVED','2026-08-01T00:00:00Z','2026-08-15T23:59:59Z',15,'CROSS_DOMAIN_CONTEXT_LOSS','ABANDONMENT',86400,'JOURNEY-V3','JTAX-1','PROC-8','MODEL-5'); c~seal
r=.BrandJourneyPopulationAnalyzer~new~analyze(p,c,.BrandEvidenceThreshold~new('T',100,20,10,5,7,1,1.2,80),'SERVICE_RECOVERY_ACROSS_DOMAIN'); call assertTrue r~ok,'analysis succeeds'
m=r~value~modifierEvidence
call assertEqual 100,m~withModifierCount,'recovery exposed count'
call assertEqual 5,m~withModifierOutcomeCount,'recovery outcome count'
call assertEqual 100,m~withoutModifierCount,'non-recovery exposed count'
call assertEqual 35,m~withoutModifierOutcomeCount,'non-recovery outcome count'
call assertTrue m~rateDelta < 0,'recovery stratum associated with lower abandonment rate'
call assertEqual 'ASSOCIATION_ONLY',m~causalStatus,'modifier evidence is not treatment causality'
say 'PASS test_recovery_modifier'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
