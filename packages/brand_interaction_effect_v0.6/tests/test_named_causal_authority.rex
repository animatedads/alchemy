h=.BrandEffectHypothesis~new('h-auth','P:TRIGGER','P:OUTCOME','COMMERCIAL_EXIT',80,'CANDIDATE_NOT_PROVEN','BRAND_INTERACTION_ENGINE')
h~addEvidencePoint('P:TRIGGER'); h~addEvidencePoint('P:OUTCOME'); call assertTrue h~seal~ok,'candidate seals'
/* Engine object still cannot self-issue established causality. */
bad=.BrandEffectHypothesis~new('h-bad','P:T','P:O','COMMERCIAL_EXIT',99,'ESTABLISHED_BY_EXTERNAL_AUTHORITY','BRAND_INTERACTION_ENGINE')
call assertFalse bad~seal~ok,'self-promotion denied'
a=.BrandCausalAuthority~new('CAUSAL-REVIEW-BOARD-1','DESIGNATED_CAUSAL_REVIEW','COMMERCIAL_EXIT','DECISION-2026-081')~seal
p=.BrandCausalPromotion~new('prom-1',h,a,'EVIDENCE:REVIEW-081'); call assertTrue p~seal~ok,'named authority promotes separately'
text=p~canonicalText
call assertTrue text~pos('CAUSAL-REVIEW-BOARD-1')>0,'authority named'
call assertTrue text~pos('ESTABLISHED_BY_EXTERNAL_AUTHORITY')>0,'promotion status explicit'
call assertEqual 'CANDIDATE_NOT_PROVEN',h~causalStatus,'original hypothesis immutable'
say 'PASS test_named_causal_authority'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
