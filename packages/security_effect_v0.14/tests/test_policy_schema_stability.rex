now=.DateTime~new
p=.SecurityTestSupport~basePolicy(now)
call assertEqual 'security.effect/0.14',.SecurityEffectBuild~API_VERSION,'component API advances to v0.14'
call assertEqual 'security.policy/0.5',.SecurityEffectBuild~POLICY_SCHEMA,'unchanged policy canonical schema does not churn merely because deployment governance advanced'
call assertTrue pos('SCHEMA=security.policy/0.5',p~canonicalText)>0,'policy semantic identity names retained schema'
call assertEqual 'security.continuation.policy/0.1',.SecurityEffectBuild~CONTINUATION_POLICY_SCHEMA,'continuation policy schema introduced separately'
call assertEqual 'security.continuation.binding/0.1',.SecurityEffectBuild~CONTINUATION_BINDING_SCHEMA,'continuation evidence schema introduced separately'
say 'PASS test_policy_schema_stability'
exit 0
assertTrue: procedure
 use arg v,l
 if v=.false then do; say 'FAIL:' l; exit 1; end
 return
assertEqual: procedure
 use arg e,a,l
 if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
 return
::requires 'TestSupport.cls'
