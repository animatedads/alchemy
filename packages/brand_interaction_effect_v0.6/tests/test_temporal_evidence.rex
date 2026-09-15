/* Aggregate history must not wash out a recent change.  Current, previous and
   long baseline are separate frames with their own dates and denominators. */
base=.BrandEvidenceFrame~new('base','LONG_BASELINE','UNRESOLVED_SUPPORT_INTERACTION','2026-02-01','2026-07-31',181,80000,'CANCELLATION',1600,'SASS','HIGH',400,12,'TONE-MODEL-V7','COMMUNICATION-STYLE-0.4',86400); call assertTrue base~seal~ok,'baseline'
prev=.BrandEvidenceFrame~new('prev','PREVIOUS','UNRESOLVED_SUPPORT_INTERACTION','2026-08-01','2026-08-07',7,4200,'CANCELLATION',90,'SASS','HIGH',30,1,'TONE-MODEL-V7','COMMUNICATION-STYLE-0.4',86400); call assertTrue prev~seal~ok,'previous'
cur=.BrandEvidenceFrame~new('cur','CURRENT','UNRESOLVED_SUPPORT_INTERACTION','2026-08-08','2026-08-21',14,8400,'CANCELLATION',190,'SASS','HIGH',400,40,'TONE-MODEL-V7','COMMUNICATION-STYLE-0.4',86400); call assertTrue cur~seal~ok,'current'
s=.BrandTemporalEvidenceSeries~new('sass-emergence'); s~addFrame(base); s~addFrame(prev); s~addFrame(cur); call assertTrue s~seal~ok,'series seals'
call assertTrue s~featurePrevalenceDelta('PREVIOUS')>0,'sass prevalence rose'
call assertTrue s~exposedOutcomeRateDelta('LONG_BASELINE')>0,'current exposed outcome rate above baseline'
text=s~canonicalText
call assertTrue text~pos('CURRENT_V_PREVIOUS_FEATURE_PREVALENCE_DELTA_PCT')>0,'recent change exposed'
call assertTrue text~pos('CURRENT_V_BASELINE_EXPOSED_OUTCOME_RATE_DELTA_PCT')>0,'baseline comparison exposed'
say 'PASS test_temporal_evidence'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandEffectEvidence.cls'
