h=.BrandEffectHypothesis~new('h1','P1','P2','COMMERCIAL_EXIT',90,'ESTABLISHED_BY_EXTERNAL_AUTHORITY')
r=h~seal
call assertFalse r~ok,'engine object cannot self-promote to established causality'
call assertEqual 'EXTERNAL_CAUSAL_AUTHORITY_REQUIRED',r~code,'authority boundary code'
say 'PASS test_causal_authority'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
