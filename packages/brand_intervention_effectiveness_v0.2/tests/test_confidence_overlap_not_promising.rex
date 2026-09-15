/* v0.1 could call this point-estimate improvement PROMISING even though the
   package's own 95% Wilson intervals overlap.  v0.2 makes that uncertainty an
   explicit gate before directional status can be promoted. */
a=.BrandInterventionEffectivenessAggregate~new('overlap','SERVICE_RECOVERY_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','UNRESOLVED_SUPPORT','2026-08-01','2026-08-21',21,1000,500,40,500,50,86400,'OBSERVATIONAL','OPS','JCLASS','JTAX','PROC','MODEL')
call assertTrue a~seal~ok,'aggregate seals'
t=.BrandInterventionEffectivenessThreshold~new('CONFIDENCE-V2',1000,100,100,0,0,14,1,20,.true)
r=.BrandInterventionEffectivenessEngine~new~analyze(a,t); call assertTrue r~ok,'analysis'; x=r~value
call assertTrue x~statisticalSufficient,'denominator/event/time thresholds pass'
call assertTrue x~effectMaterial,'point estimate clears configured magnitude'
call assertFalse x~uncertainty~intervalSeparation,'95 percent intervals overlap'
call assertFalse x~confidenceGate,'confidence gate fails'
call assertEqual 'NO_CLEAR_ASSOCIATION',x~status,'overlapping uncertainty cannot be promoted to promising'
call assertContains x~reasons,'CONFIDENCE_INTERVALS_OVERLAP','controlled reason retained'
text=x~canonicalText
call assertTrue text~pos('CONFIDENCE_GATE=0')>0,'confidence gate reaches reasoning material'
call assertTrue text~pos('REASON=CONFIDENCE_INTERVALS_OVERLAP')>0,'overlap reason reaches reasoning material'
call assertTrue text~pos('INTERVAL_SEPARATION=0')>0,'underlying interval fact retained'
say 'PASS test_confidence_overlap_not_promising'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
assertContains: procedure; use arg arr,needle,label; do x over arr; if x==needle then return; end; say 'FAIL:' label 'missing='needle; exit 1
::requires 'BrandInterventionEffectiveness.cls'
