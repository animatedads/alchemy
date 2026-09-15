e=.BrandInterventionEffectivenessEngine~new; t=.BrandInterventionEffectivenessThreshold~new('t',500,100,100,5,5,14,1)
current=makeStudy('CURRENT','2026-08-01','2026-08-21',21,2000,1000,20,1000,80,'MODEL-6.4')
previous=makeStudy('PREVIOUS','2026-07-10','2026-07-31',22,2000,1000,55,1000,60,'MODEL-6.3')
baseline=makeStudy('BASELINE','2026-02-01','2026-07-31',181,10000,5000,280,5000,300,'MODEL-6.3')
r=.BrandInterventionEffectivenessTemporalReport~new('temp',current,previous,baseline)
text=r~reasoningMaterial
call assertTrue text~pos('MODEL_VERSION=MODEL-6.4')>0,'current release retained'
call assertTrue text~pos('MODEL_VERSION=MODEL-6.3')>0,'comparison release retained'
call assertTrue r~primaryDesiredEffectDeltaCurrentPrevious>0,'current desired effect stronger than previous'
call assertTrue text~pos('TEMPORAL_CHANGE_PROVES_INTERVENTION_CAUSATION')>0,'temporal change not causal proof'
say 'PASS test_temporal_release_effectiveness'
exit 0
makeStudy: procedure expose e t
  parse arg id,from,to,days,eligible,applied,aout,notap,nout,model
  a=.BrandInterventionEffectivenessAggregate~new(id,'SERVICE_RECOVERY_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','SUPPORT',from,to,days,eligible,applied,aout,notap,nout,86400,'OBSERVATIONAL','OPS','JCLASS','JTAX','PROC',model); a~seal
  x=e~analyze(a,t)~value; s=.BrandInterventionEffectivenessStudy~new(id||'-STUDY',x); s~seal
  return s
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandInterventionEffectiveness.cls'
