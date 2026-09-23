parse source . . here
root=filespec('location',here) || '..'; call directory root
schema=.json~fromJSON(charin('schemas/cognitive.effect-proposal-0.2.json',1,chars('schemas/cognitive.effect-proposal-0.2.json'))); call stream 'schemas/cognitive.effect-proposal-0.2.json','c','close'
call eq 'cognitive.effect.proposal/0.2',schema['$id'],'proposal schema id'
p=.CognitiveAccessPolicy~new; svc=.CognitiveContinuityService~new(.CognitiveMemoryJournal~new,p); m=.CognitiveMcpAdapter~new(svc)
call eq 8,m~tools~items,'mcp tools'
say 'PASS test_schema_and_mcp'; exit 0
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
::requires 'CognitiveMcpAdapter.cls'
::requires 'json.cls'
