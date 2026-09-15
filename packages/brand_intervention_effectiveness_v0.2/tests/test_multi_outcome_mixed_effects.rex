e=.BrandInterventionEffectivenessEngine~new; t=.BrandInterventionEffectivenessThreshold~new('t',1000,100,100,10,10,14,1)
p=.BrandInterventionEffectivenessAggregate~new('p','TONE_APPROPRIATENESS_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','UNRESOLVED_SUPPORT','2026-08-01','2026-08-21',21,4000,2000,40,2000,100,86400); p~seal
pg=.BrandInterventionEffectivenessAggregate~new('g','TONE_APPROPRIATENESS_GUIDANCE','CUSTOMER_DISENGAGEMENT','DECREASE','GUARDRAIL','UNRESOLVED_SUPPORT','2026-08-01','2026-08-21',21,4000,2000,180,2000,80,86400); pg~seal
pa=e~analyze(p,t)~value; ga=e~analyze(pg,t)~value
call assertEqual 'PROMISING_ASSOCIATION',pa~status,'primary improved'
call assertEqual 'ADVERSE_ASSOCIATION',ga~status,'guardrail worsened'
s=.BrandInterventionEffectivenessStudy~new('mixed',pa); s~addGuardrail(ga); s~addConfounder('ISSUE_SEVERITY_MIX'); s~seal
call assertEqual 'MIXED_EFFECTS',s~status,'success on one metric cannot hide guardrail harm'
text=s~reasoningMaterial
call assertTrue text~pos('CUSTOMER_DISENGAGEMENT')>0,'guardrail evidence travels'
call assertTrue text~pos('TREAT_OBSERVED_DIFFERENCE_AS_CAUSATION')>0,'causal overclaim prohibited'
say 'PASS test_multi_outcome_mixed_effects'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInterventionEffectiveness.cls'
