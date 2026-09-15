/* The uncertainty requirement is explicit policy, not hidden magic.  A caller
   may deliberately disable interval-separation gating; the packet records that
   choice so a reasoning model can see why directional status was permitted. */
a=.BrandInterventionEffectivenessAggregate~new('optional','SERVICE_RECOVERY_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','UNRESOLVED_SUPPORT','2026-08-01','2026-08-21',21,1000,500,40,500,50,86400,'OBSERVATIONAL','OPS','JCLASS','JTAX','PROC','MODEL')
call assertTrue a~seal~ok,'aggregate seals'
t=.BrandInterventionEffectivenessThreshold~new('NO-CONFIDENCE-REQUIREMENT',1000,100,100,0,0,14,1,20,.false)
r=.BrandInterventionEffectivenessEngine~new~analyze(a,t); call assertTrue r~ok,'analysis'; x=r~value
call assertFalse x~uncertainty~intervalSeparation,'same overlapping intervals'
call assertTrue x~confidenceGate,'configured gate passes because separation is not required'
call assertEqual 'PROMISING_ASSOCIATION',x~status,'explicitly relaxed policy permits directional label'
text=x~canonicalText
call assertTrue text~pos('REQUIRE_INTERVAL_SEPARATION=0')>0,'relaxed threshold is visible'
call assertTrue text~pos('CONFIDENCE_GATE=1')>0,'effective gate state is visible'
call assertNotContains x~reasons,'CONFIDENCE_INTERVALS_OVERLAP','overlap is not a failing reason when gate is disabled'
say 'PASS test_confidence_gate_optional'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
assertNotContains: procedure; use arg arr,needle,label; do x over arr; if x==needle then do; say 'FAIL:' label 'unexpected='needle; exit 1; end; end; return
::requires 'BrandInterventionEffectiveness.cls'
