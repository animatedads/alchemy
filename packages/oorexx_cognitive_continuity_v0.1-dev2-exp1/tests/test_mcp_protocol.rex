p=.CognitiveAccessPolicy~new
ignore=p~grant('codex:mcp','cognitive.effects.propose.model','project:mcp')
ignore=p~grant('codex:mcp','cognitive.records.query','project:mcp')
ignore=p~grant('codex:mcp','cognitive.context.project','project:mcp')
ignore=p~grant('codex:mcp','cognitive.context.explain','project:mcp')
ignore=p~grant('codex:mcp','cognitive.learning.delta','project:mcp')
svc=.CognitiveContinuityService~new(.CognitiveMemoryJournal~new,p)
semantic=.CognitiveMcpAdapter~new(svc); protocol=.CognitiveMcpProtocolAdapter~new(semantic)
headers=.directory~new; headers['mcp-protocol-version']='2026-07-28'; headers['mcp-method']='tools/list'
body='{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"}}}'
r=protocol~handle(headers,body,'codex:mcp'); call eq 200,r~status,'list status'; parsed=.json~fromJSON(r~jsonText); call eq 8,parsed['result']['tools']~items,'tool count'
headers2=.directory~new; headers2['mcp-protocol-version']='2026-07-28'; headers2['mcp-method']='tools/call'; headers2['mcp-name']='cognitive.effects.propose'
body2='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"},"name":"cognitive.effects.propose","arguments":{"scopeRef":"project:mcp","effects":[{"kind":"DECISION","subjectRef":"mcp","statement":"MCP uses authenticated actor","basisRefs":[]}]}}}'
r2=protocol~handle(headers2,body2,'codex:mcp'); call eq 200,r2~status,'call status'; p2=.json~fromJSON(r2~jsonText); call eq 0,p2['result']['isError'],'call not error'; call eq 'oorexx.cognitive.compat-structured-response/0.1',p2['result']['structuredContent']['schema'],'compat structured response'
/* Identity smuggling rejected at semantic adapter. */
a=.directory~new; a['scopeRef']='project:mcp'; a['actorId']='operator'; a['effects']=.array~new
rr=semantic~call('cognitive.effects.propose',a,'codex:mcp'); call must \rr~ok,'identity smuggle rejected'; call eq 'MCP_IDENTITY_FIELD_FORBIDDEN',rr~code,'smuggle code'
say 'PASS test_mcp_protocol'; exit 0
must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
::requires 'CognitiveMcpAdapter.cls'
::requires 'CognitiveMcpProtocolAdapter.cls'
::requires 'json.cls'
