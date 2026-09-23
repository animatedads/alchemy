r=.CognitiveResult~success(.directory~new,'OK_TEST')
s=.CognitiveStructuredResponseBridge~wrap(r,'TEST','actor:x')
call eq 'oorexx.cognitive.compat-structured-response/0.1',s['schema'],'bridge schema'
call eq 1,s['compatibilityOnly'],'compat marker'
call eq 'SUCCESS',s['status'],'status'
call eq 'actor:x',s['provenance']['actorId'],'actor provenance'
say 'PASS test_structured_bridge'
exit 0
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
::requires 'CognitiveStructuredResponseBridge.cls'
