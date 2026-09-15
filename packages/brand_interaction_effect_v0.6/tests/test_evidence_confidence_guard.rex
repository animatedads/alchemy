/* Passing the raw size and point-estimate effect gates is not enough when the
   interval remains compatible with no association. */
f=.BrandEvidenceFrame~new('wide-ci','CURRENT','UNRESOLVED_SUPPORT_INTERACTION','2026-08-01','2026-08-14',14,1000,'CANCELLATION',20,'SASS','HIGH',25,1,'TONE-MODEL-V7','COMMUNICATION-STYLE-0.4',86400)
call assertTrue f~seal~ok,'frame seals'
t=.BrandEvidenceThreshold~new('WIDE-CI-V1',1000,25,20,1,14,1,1.25,80,95,.true)
r=.BrandEvidenceEngine~new~evaluate(f,t); call assertTrue r~ok,'evaluates'; a=r~value
call assertTrue a~statisticalSufficient,'count/time threshold met'
call assertTrue a~effectGate,'point estimate clears effect gate'
call assertFalse a~confidenceGate,'interval crosses null'
call assertEqual 'WEAK_SIGNAL',a~status,'confidence guard prevents supported claim'
call assertTrue a~reasons~items>0,'reason present'
text=a~canonicalText
call assertTrue text~pos('CONFIDENCE_INTERVAL_CROSSES_NULL')>0,'reason is explicit'
call assertTrue text~pos('CONFIDENCE_EXCLUDES_NULL=0')>0,'interval result exposed'
say 'PASS test_evidence_confidence_guard'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandEffectEvidence.cls'
