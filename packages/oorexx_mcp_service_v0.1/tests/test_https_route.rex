parse source . . here
pkg=filespec('location',here)
catalog=.McpProjectComponentCatalog~fromJsonFile(pkg||'../catalog/components.json')
service=.McpProjectWireService~new(catalog,.McpProjectMemoryJournal~new)
protocol=.McpProtocolAdapter~new(service)
route=.McpHttpsRoute~new(protocol)
.environment['HTTPRESPONSE']=.FakeHttpResponse
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
say 'PASS test_https_route'
exit 0
assert: procedure
 use arg c,l
 if \c then do; say 'FAIL:' l; exit 1; end
 return

::class FakeContext
::method init
 expose values
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

::class FakeHttpResponse public
::attribute status get
::attribute body get
::attribute headers get
::method init
 expose status body headers
 use arg status,body
 headers=.directory~new
::method json class
 use arg text='{}',status=200
 return self~new(status,text)
::method header
 expose headers
 use arg name,value
 headers[name]=value; return self

::requires 'McpHttpsRoute.cls'
::requires 'json.cls'
