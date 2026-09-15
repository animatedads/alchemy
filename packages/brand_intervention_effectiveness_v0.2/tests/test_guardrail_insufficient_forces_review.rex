e=.BrandInterventionEffectivenessEngine~new; t=.BrandInterventionEffectivenessThreshold~new('t',1000,100,100,10,10,14,1)
p=.BrandInterventionEffectivenessAggregate~new('p','SERVICE_RECOVERY_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','SUPPORT','2026-08-01','2026-08-21',21,4000,2000,40,2000,100); p~seal
g=.BrandInterventionEffectivenessAggregate~new('g','SERVICE_RECOVERY_GUIDANCE','EXTREME_APOLOGY','DECREASE','GUARDRAIL','SUPPORT','2026-08-01','2026-08-05',5,80,40,1,40,1); g~seal
s=.BrandInterventionEffectivenessStudy~new('review',e~analyze(p,t)~value); s~addGuardrail(e~analyze(g,t)~value); s~seal
call assertEqual 'REVIEW_REQUIRED',s~status,'promising primary with unmeasured guardrail is review, not victory'
say 'PASS test_guardrail_insufficient_forces_review'
exit 0
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInterventionEffectiveness.cls'
