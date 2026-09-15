a=.BrandInterventionEffectivenessAggregate~new('r','SERVICE_RECOVERY_GUIDANCE','RELATIONSHIP_PRESERVED','INCREASE','PRIMARY','SUPPORT','2026-08-01','2026-08-21',21,2000,1000,800,1000,600,86400,'RANDOMIZED','EXPERIMENT-SERVICE-V1'); call assertTrue a~seal~ok,'randomized aggregate seals'
x=.BrandInterventionEffectivenessEngine~new~analyze(a,.BrandInterventionEffectivenessThreshold~new('t',1000,100,100,10,10,14,1))~value
s=.BrandInterventionEffectivenessStudy~new('r-study',x); s~seal
call assertEqual 'ASSOCIATION_ONLY',s~causalStatus,'randomized provenance is not autonomous causal promotion'
call assertTrue s~reasoningMaterial~pos('ASSIGNMENT_METHOD=RANDOMIZED')>0,'assignment design retained'
call assertTrue s~reasoningMaterial~pos('TREAT_OBSERVED_DIFFERENCE_AS_CAUSATION')>0,'causal promotion still external'
say 'PASS test_randomized_still_not_self_causal'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInterventionEffectiveness.cls'
