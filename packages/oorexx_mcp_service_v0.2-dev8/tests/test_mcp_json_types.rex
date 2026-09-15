parse source . . here
pkg=filespec('location',here)
catalog=.McpProjectComponentCatalog~fromJsonFile(pkg||'../catalog/components.json')
service=.McpProjectWireService~new(catalog,.McpProjectMemoryJournal~new)
protocol=.McpProtocolAdapter~new(service)

/* Modern tools/list: assert the raw JSON token is boolean false, not numeric 0. */
headers=.directory~new
headers['mcp-protocol-version']='2026-07-28'
headers['mcp-method']='tools/list'; headers['mcp-name']=''
meta=.directory~new
meta['io.modelcontextprotocol/protocolVersion']='2026-07-28'
params=.directory~new; params['_meta']=meta
req=.directory~new
req['jsonrpc']='2.0'; req['id']=1; req['method']='tools/list'; req['params']=params
r=protocol~handle(headers,.json~toJSON(req),'')
call assert r~status=200,'tools/list HTTP status'
raw=r~jsonText
call assert raw~pos('"additionalProperties":false')>0,'schema additionalProperties is JSON false'
call assert raw~pos('"additionalProperties":0')=0,'schema does not emit numeric zero'
d=.json~fromJSON(raw)
tool=d['result']['tools'][1]
call assert tool['name']~string='sphere.check','sphere.check remains first tool'
call assert \tool['inputSchema']~hasIndex('$schema'),'tool schema omits optional $schema declaration'
call assert tool['inputSchema']['additionalProperties']~isA(.JsonBoolean),'additionalProperties parses as JsonBoolean'
call assert \tool['inputSchema']['additionalProperties']~value,'additionalProperties is false'

/* tools/call success: isError and structured ok must be JSON booleans. */
headers['mcp-method']='tools/call'; headers['mcp-name']='project.request.create'
args=.directory~new; args['componentId']='wire_ui_server'; args['recipientId']='llm:bob'; args['body']='wire boolean regression'
params['name']='project.request.create'; params['arguments']=args
req['id']=2; req['method']='tools/call'
r=protocol~handle(headers,.json~toJSON(req),'architect')
raw=r~jsonText
call assert raw~pos('"isError":false')>0,'success isError is JSON false'
call assert raw~pos('"ok":true')>0,'success structured ok is JSON true'
d=.json~fromJSON(raw)
call assert d['result']['isError']~isA(.JsonBoolean),'success isError parses as JsonBoolean'
call assert d['result']['structuredContent']['ok']~isA(.JsonBoolean),'success ok parses as JsonBoolean'

/* tools/call semantic failure: booleans reverse without becoming numbers. */
headers['mcp-name']='project.ownership.claim'
args=.directory~new; args['componentId']='wire_ui_server'
params['name']='project.ownership.claim'; params['arguments']=args
req['id']=3
r=protocol~handle(headers,.json~toJSON(req),'')
raw=r~jsonText
call assert raw~pos('"isError":true')>0,'failure isError is JSON true'
call assert raw~pos('"ok":false')>0,'failure structured ok is JSON false'
call assert raw~pos('"isError":1')=0 & raw~pos('"ok":0')=0,'tool result booleans are not numeric'

say 'PASS test_mcp_json_types'
exit 0
assert: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return
::requires 'McpProtocolAdapter.cls'
::requires 'json.cls'
