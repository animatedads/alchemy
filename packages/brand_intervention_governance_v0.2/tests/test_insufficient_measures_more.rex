eng=.BrandInterventionEffectivenessEngine~new
t=.BrandInterventionEffectivenessThreshold~new('T',5000,2000,2000,0,0,30,1,50)
a=.BrandInterventionEffectivenessAggregate~new('SMALL','SERVICE_RECOVERY_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','SUPPORT','2026-08-01','2026-08-07',7,100,50,2,50,4,86400,'OBSERVATIONAL','OPS','J','T','P','M'); a~seal
an=eng~analyze(a,t)~value; s=.BrandInterventionEffectivenessStudy~new('S',an); s~seal
b=.BrandInterventionGovernanceEvidenceBinding~new('B',s,'2026-08-24',1,'CLOCK'); b~seal
rules=.BrandInterventionGovernanceRuleSet~new; rules~seal
r=.BrandInterventionGovernanceEngine~new~recommend(b,rules)~value
call assertEqual 'MEASURE_MORE',r~disposition,'insufficient evidence means measure more'
call assertTrue r~reasoningMaterial~pos('COLLECT_MORE_ELIGIBLE_APPLIED_AND_NOT_APPLIED_EVIDENCE')>0,'denominators requested'
say 'PASS test_insufficient_measures_more'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInterventionGovernance.cls'
