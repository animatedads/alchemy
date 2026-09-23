parse source . . here
root=filespec('location',here) || '..'; call directory root
schema=.json~fromJSON(charin('schemas/cognitive.effect-proposal-0.2.json',1,chars('schemas/cognitive.effect-proposal-0.2.json'))); call stream 'schemas/cognitive.effect-proposal-0.2.json','c','close'
call eq 'cognitive.effect.proposal/0.2',schema['$id'],'proposal schema id'
reqSchema=.json~fromJSON(charin('schemas/cognitive.learning.request-0.2.json',1,chars('schemas/cognitive.learning.request-0.2.json'))); call stream 'schemas/cognitive.learning.request-0.2.json','c','close'
call eq 'array',reqSchema['properties']['dogfoodObservations']['type'],'request dogfood schema'
resSchema=.json~fromJSON(charin('schemas/cognitive.learning.result-0.2.json',1,chars('schemas/cognitive.learning.result-0.2.json'))); call stream 'schemas/cognitive.learning.result-0.2.json','c','close'
call eq 'string',resSchema['properties']['modelId']['type'],'result model id schema'
call eq 'string',resSchema['properties']['completedAt']['type'],'result completion schema'
p=.CognitiveAccessPolicy~new; svc=.CognitiveContinuityService~new(.CognitiveMemoryJournal~new,p); m=.CognitiveMcpAdapter~new(svc)
call eq 12,m~tools~items,'mcp tools'
say 'PASS test_schema_and_mcp'; exit 0
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
::requires 'CognitiveMcpAdapter.cls'
::requires 'json.cls'
