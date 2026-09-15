/* Aggregate sass evidence must arrive with denominator, time scope, thresholds,
   classifier provenance, support/counter evidence and interpretation bounds. */
f=.BrandEvidenceFrame~new('sass-q3','CURRENT','UNRESOLVED_SUPPORT_INTERACTION','2026-06-01T00:00:00Z','2026-08-21T23:59:59Z',82,29234,'CANCELLATION',109,'SASS','HIGH',29,12,'TONE-MODEL-V7','COMMUNICATION-STYLE-0.4',86400)
f~addSupportPoint('BRAND_INTERACTION:EVIDENCE:CASE-17')
f~addCounterPoint('BRAND_INTERACTION:EVIDENCE:CASE-22')
call assertTrue f~seal~ok,'frame seals'
t=.BrandEvidenceThreshold~new('SUPPORT-SASS-V1',1000,25,20,5,14,1,1.25,80)
r=.BrandEvidenceEngine~new~evaluate(f,t); call assertTrue r~ok,'evidence evaluates'; a=r~value
call assertTrue a~statisticalSufficient,'statistical threshold met'
call assertEqual 'SUPPORTED',a~status,'supported not causal'
call assertEqual 100,a~thresholdCoveragePct,'threshold figure exposed'
call assertEqual 'ASSOCIATION_ONLY',a~causalStatus,'association only'
p=.BrandEffectEvidencePacket~new('sass-cancel-p1','HIGH_DISMISSIVE_SASS_ASSOCIATED_WITH_CANCELLATION','SASS',f,t,a)
p~addSupportPoint('BRAND_INTERACTION:EVIDENCE:CASE-17')
p~addCounterPoint('BRAND_INTERACTION:EVIDENCE:CASE-22')
p~addConfounder('PREEXISTING_CUSTOMER_DISSATISFACTION')
p~addConfounder('UNRESOLVED_ISSUE_SEVERITY')
p~addScopeExclusion('FRIENDLY_BANTER')
p~permitInterpretation('INVESTIGATE_SASS_WITHIN_THIS_COHORT_AND_TIME_WINDOW')
p~prohibitInterpretation('SASS_ALWAYS_CAUSES_CANCELLATION')
call assertTrue p~seal~ok,'packet seals with reasoning material'
report=.BrandToneAppropriatenessReport~new('tone-1',p)
text=report~reasoningMaterial
call assertTrue text~pos('POPULATION=29234')>0,'denominator travels'
call assertTrue text~pos('EXPOSED_COUNT=29')>0,'feature count travels'
call assertTrue text~pos('EXPOSED_OUTCOME_COUNT=12')>0,'joint count travels'
call assertTrue text~pos('MIN_EXPOSED=25')>0,'statistical threshold travels'
call assertTrue text~pos('FROM=2026-06-01')>0,'time scope travels'
call assertTrue text~pos('CLASSIFIER_ID=TONE-MODEL-V7')>0,'classifier provenance travels'
call assertTrue text~pos('COUNTER_POINT=')>0,'counterevidence travels'
call assertTrue text~pos('SASS_ALWAYS_CAUSES_CANCELLATION')>0,'overinterpretation explicitly prohibited'
say 'PASS test_evidence_reasoning_packet'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandEffectEvidence.cls'
