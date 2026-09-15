parse source . . here
pkg=filespec('location',here)
catalog=.McpProjectComponentCatalog~fromJsonFile(pkg||'../catalog/components.json')
service=.McpProjectWireService~new(catalog,.McpProjectMemoryJournal~new)
protocol=.McpProtocolAdapter~new(service)
headers=.directory~new

/* ChatGPT/initialize-era compatibility probe. */
params=.directory~new
params['protocolVersion']='2025-11-25'
params['capabilities']=.directory~new
client=.directory~new; client['name']='compat-client'; client['version']='1.0'; params['clientInfo']=client
req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=1; req['method']='initialize'; req['params']=params
r=protocol~handle(headers,.json~toJSON(req),'')
call assert r~status=200,'legacy initialize status'
d=.json~fromJSON(r~jsonText)
call assert d['result']['protocolVersion']~string='2025-11-25','legacy version selected'
call assert d['result']['capabilities']~hasIndex('tools'),'legacy advertises tools'
call assert d['result']['serverInfo']['name']~string='oorexx-mcp-project-service','legacy serverInfo'

req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['method']='notifications/initialized'; req['params']=.directory~new
r=protocol~handle(headers,.json~toJSON(req),'')
call assert r~status=202 & r~jsonText='','legacy initialized notification accepted'

req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=2; req['method']='tools/list'; req['params']=.directory~new
r=protocol~handle(headers,.json~toJSON(req),'')
call assert r~status=200,'legacy tools/list status'
d=.json~fromJSON(r~jsonText)
call assert d['result']['tools']~items=8,'legacy tools/list eight tools'
call assert \d['result']~hasIndex('resultType'),'legacy response omits modern resultType'

args=.directory~new; args['componentId']='wire_ui_server'; args['body']='Legacy compatibility request.'
params=.directory~new; params['name']='project.request.create'; params['arguments']=args
req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=3; req['method']='tools/call'; req['params']=params
r=protocol~handle(headers,.json~toJSON(req),'architect')
d=.json~fromJSON(r~jsonText)
call assert r~status=200 & d['result']['isError']=.false,'legacy tools/call succeeds'
call assert \d['result']~hasIndex('resultType'),'legacy tool result omits modern resultType'

/* Unsupported old revisions fail explicitly rather than entering modern parsing. */
params=.directory~new; params['protocolVersion']='2024-01-01'; params['capabilities']=.directory~new
req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=4; req['method']='initialize'; req['params']=params
r=protocol~handle(headers,.json~toJSON(req),'')
d=.json~fromJSON(r~jsonText)
call assert d['error']['code']=-32602,'unsupported legacy protocol rejected'

say 'PASS test_mcp_legacy_protocol'
exit 0
assert: procedure
 use arg c,l
 if \c then do; say 'FAIL:' l; exit 1; end
 return

::requires 'McpProtocolAdapter.cls'
::requires 'json.cls'
