parse source . . here
pkg=filespec('location',here)
catalog=.McpProjectComponentCatalog~fromJsonFile(pkg||'../catalog/components.json')
service=.McpProjectWireService~new(catalog,.McpProjectMemoryJournal~new)
protocol=.McpProtocolAdapter~new(service)
route=.McpHttpsRoute~new(protocol)
ctx=.FakeContext~new; ctx~put('mcp.principal','architect')
headers=.directory~new; headers['mcp-protocol-version']='2026-07-28'; headers['mcp-method']='tools/call'; headers['mcp-name']='project.request.create'
meta=.directory~new; meta['io.modelcontextprotocol/protocolVersion']='2026-07-28'
args=.directory~new; args['componentId']='wire_ui_server'; args['body']='Review this.'
params=.directory~new; params['_meta']=meta; params['name']='project.request.create'; params['arguments']=args
msg=.directory~new; msg['jsonrpc']=.JsonString~new('2.0'); msg['id']=1; msg['method']='tools/call'; msg['params']=params
req=.FakeRequest~new(headers,.json~toJSON(msg),ctx)
resp=route~post(req)
call assert resp~status=200,'route returns HTTP JSON response'
d=.json~fromJSON(resp~body)
call assert d['result']['isError']=.false,'context principal reaches semantic service'
call assert d['result']['structuredContent']['value']['senderId']~string='architect','sender comes from trusted context'
call assert d['result']['structuredContent']['value']['recipientId']~string='component:wire_ui_server','component mailbox default'
call assert resp~headers['MCP-Protocol-Version']~string='2026-07-28','response protocol header'
call assert resp~isA(.HttpResponse),'route returns real HTTPS v0.4.4 HttpResponse'
call assert resp~body~isA(.String),'real HTTPS response body is serialized text, not a Directory'

/* Stateless GET remains an explicit 405 rather than a fake SSE stream. */
probe=route~probe(req)
call assert probe~status=405,'stateless GET probe is 405'
call assert probe~headers['Allow']~string='POST','stateless GET advertises POST'

/* Optional compatibility route uses the same real HttpResponse type. */
compatProtocol=.McpProtocolAdapter~new(service,'compat')
compatRoute=.McpHttpsRoute~new(compatProtocol)
legacy=.directory~new; legacy['jsonrpc']=.JsonString~new('2.0'); legacy['id']=2; legacy['method']='tools/list'; legacy['params']=.directory~new
emptyHeaders=.directory~new
compatReq=.FakeRequest~new(emptyHeaders,.json~toJSON(legacy),ctx)
compatResp=compatRoute~post(compatReq)
call assert compatResp~status=200,'compat route tools/list status'
compatJson=.json~fromJSON(compatResp~body)
call assert compatJson['result']['tools'][1]['name']~string='sphere_check','compat route advertises underscore tool names'
call assert compatResp~isA(.HttpResponse) & compatResp~body~isA(.String),'compat route returns serialized real HttpResponse'
say 'PASS test_https_route'
exit 0
assert: procedure
 use arg c,l
 if \c then do; say 'FAIL:' l; exit 1; end
 return

::class FakeContext
::attribute requestId get
::method init
 expose values requestId
 requestId=42
 values=.directory~new
::method put
 expose values
 use arg k,v
 values[k]=v; return self
::method get
 expose values
 use arg k,d=.nil
 if values~hasIndex(k) then return values[k]
 return d

::class FakeRequest
::attribute body get
::attribute context get
::method init
 expose headers body context
 use arg headers,body,context
::method header
 expose headers
 use arg name,default=''
 key=name~lower
 if headers~hasIndex(key) then return headers[key]
 return default

::requires 'McpHttpsRoute.cls'
::requires 'json.cls'
