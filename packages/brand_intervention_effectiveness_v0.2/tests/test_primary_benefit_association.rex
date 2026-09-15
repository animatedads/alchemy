a=.BrandInterventionEffectivenessAggregate~new('primary-1','SERVICE_RECOVERY_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','UNRESOLVED_SUPPORT','2026-08-01T00:00:00Z','2026-08-21T23:59:59Z',21,2000,1000,30,1000,80,86400,'OBSERVATIONAL','OPS-ASSIGNMENT','JCLASS-V3','JTAX-1','PROC-8','MODEL-6.4')
a~addSupportPoint('BRAND_INTERVENTION:OUTCOME:O1'); a~addCounterPoint('BRAND_INTERVENTION:OUTCOME:O2'); call assertTrue a~seal~ok,'aggregate seals'
t=.BrandInterventionEffectivenessThreshold~new('t',1000,100,100,10,10,14,1)
r=.BrandInterventionEffectivenessEngine~new~analyze(a,t); call assertTrue r~ok,'analysis'; x=r~value
call assertTrue x~statisticalSufficient,'sufficient'
call assertEqual 'PROMISING_ASSOCIATION',x~status,'lower cancellation is promising'
call assertEqual 'ASSOCIATION_ONLY',x~causalStatus,'not causation'
call assertTrue a~desiredEffectPct>0,'desired effect positive'
say 'PASS test_primary_benefit_association'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInterventionEffectiveness.cls'
