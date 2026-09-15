/* A large scoped sass/cancellation frame must carry uncertainty bounds, not
   merely denominator and effect-size thresholds. */
f=.BrandEvidenceFrame~new('sass-q3','CURRENT','UNRESOLVED_SUPPORT_INTERACTION','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z',82,29234,'CANCELLATION',109,'SASS','HIGH',29,12,'TONE-MODEL-V7','COMMUNICATION-STYLE-0.4',86400)
f~addSupportPoint('BRAND_INTERACTION:EVIDENCE:CASE-17')
f~addCounterPoint('BRAND_INTERACTION:EVIDENCE:CASE-22')
call assertTrue f~seal~ok,'frame seals'
t=.BrandEvidenceThreshold~new('SUPPORT-SASS-V2',1000,25,20,5,14,1,1.25,80,95,.true)
r=.BrandEvidenceEngine~new~evaluate(f,t); call assertTrue r~ok,'evaluates'; a=r~value
call assertTrue a~statisticalSufficient,'count/time threshold met'
call assertTrue a~effectGate,'effect-size gate met'
call assertTrue a~confidenceGate,'confidence interval excludes null'
call assertEqual 'SUPPORTED',a~status,'supported with uncertainty gate'
s=a~statisticalEvidence
call assertTrue s~relativeRiskLow>1,'RR lower bound above null'
call assertTrue s~riskDifferenceLowPct>0,'risk-difference lower bound above null'
call assertFalse s~continuityCorrectionApplied,'no correction needed'
p=.BrandEffectEvidencePacket~new('sass-cancel-p2','HIGH_DISMISSIVE_SASS_ASSOCIATED_WITH_CANCELLATION','SASS',f,t,a)
p~addSupportPoint('BRAND_INTERACTION:EVIDENCE:CASE-17')
p~addCounterPoint('BRAND_INTERACTION:EVIDENCE:CASE-22')
p~permitInterpretation('INVESTIGATE_SASS_WITHIN_THIS_COHORT_AND_TIME_WINDOW')
p~prohibitInterpretation('SASS_ALWAYS_CAUSES_CANCELLATION')
call assertTrue p~seal~ok,'packet seals'
text=p~canonicalText
call assertTrue text~pos('STATISTICAL_METHOD=LOG_RR_PLUS_WILSON_RISK_DIFFERENCE_APPROXIMATION')>0,'method labelled'
call assertTrue text~pos('CONFIDENCE_LEVEL_PCT=95')>0,'confidence level travels'
call assertTrue text~pos('RELATIVE_RISK_CI_LOW=')>0,'RR interval travels'
call assertTrue text~pos('RISK_DIFFERENCE_CI_LOW_PCT=')>0,'RD interval travels'
call assertTrue text~pos('CONFIDENCE_EXCLUDES_NULL=1')>0,'uncertainty gate travels'
say 'PASS test_evidence_confidence_bounds'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandEffectEvidence.cls'
