a=.array~new
/* Same intervention/outcome: 4 eligible proposals, two applied. */
o1=.BrandInterventionOutcomeObservation~new('o1','BRAND_JOURNEY:J1','BRAND_INTERVENTION:PROPOSAL:P1','SERVICE_RECOVERY_GUIDANCE',.true,'2026-08-02T12:00:00Z','CANCELLATION',.false,100); o1~seal; a~append(o1)
o2=.BrandInterventionOutcomeObservation~new('o2','BRAND_JOURNEY:J2','BRAND_INTERVENTION:PROPOSAL:P2','SERVICE_RECOVERY_GUIDANCE',.true,'2026-08-03T12:00:00Z','CANCELLATION',.true,100); o2~seal; a~append(o2)
o3=.BrandInterventionOutcomeObservation~new('o3','BRAND_JOURNEY:J3','BRAND_INTERVENTION:PROPOSAL:P3','SERVICE_RECOVERY_GUIDANCE',.false,'2026-08-04T12:00:00Z','CANCELLATION',.true,100); o3~seal; a~append(o3)
o4=.BrandInterventionOutcomeObservation~new('o4','BRAND_JOURNEY:J4','BRAND_INTERVENTION:PROPOSAL:P4','SERVICE_RECOVERY_GUIDANCE',.false,'2026-08-05T12:00:00Z','CANCELLATION',.true,100); o4~seal; a~append(o4)
/* unrelated outcome must not enter denominator */
o5=.BrandInterventionOutcomeObservation~new('o5','BRAND_JOURNEY:J5','BRAND_INTERVENTION:PROPOSAL:P5','TONE_APPROPRIATENESS_GUIDANCE',.true,'2026-08-05T12:00:00Z','CANCELLATION',.true,100); o5~seal; a~append(o5)
r=.BrandInterventionEffectivenessBridge~new~aggregateOutcomes('b',a,'SERVICE_RECOVERY_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','SUPPORT','2026-08-01','2026-08-21',21,86400)
call assertTrue r~ok,'bridge'; b=r~value
call assertEqual 4,b~eligibleCount,'only eligible matching intervention observations counted'
call assertEqual 2,b~appliedCount,'applied count'; call assertEqual 1,b~appliedOutcomeCount,'applied outcomes'
call assertEqual 2,b~notAppliedCount,'not applied controls'; call assertEqual 2,b~notAppliedOutcomeCount,'control outcomes'
say 'PASS test_outcome_bridge_eligibility'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInterventionEffectiveness.cls'
::requires 'BrandInterventionEffectivenessBridge.cls'
