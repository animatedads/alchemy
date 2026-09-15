parse source . . here
pkg=filespec('location',here)
catalog=.McpProjectComponentCatalog~fromJsonFile(pkg||'../catalog/components.json')
service=.McpProjectWireService~new(catalog,.McpProjectMemoryJournal~new)
protocol=.McpProtocolAdapter~new(service,'compat')
emptyHeaders=.directory~new

/* Exact xAI Remote MCP compatibility sequence: initialize without a version
 * header, then carry the negotiated 2025-11-25 version in Streamable HTTP.
 */
params=.directory~new
params['protocolVersion']='2025-11-25'
params['capabilities']=.directory~new
client=.directory~new; client['name']='xai-remote-mcp'; client['version']='probe'; params['clientInfo']=client
req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=1; req['method']='initialize'; req['params']=params
r=protocol~handle(emptyHeaders,.json~toJSON(req),'')
call assert r~status=200,'xAI initialize without version header succeeds'
d=.json~fromJSON(r~jsonText)
call assert d['result']['protocolVersion']~string='2025-11-25','xAI negotiated version selected'

versionHeaders=.directory~new
versionHeaders['mcp-protocol-version']='2025-11-25'
req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=2; req['method']='tools/list'; req['params']=.directory~new
r=protocol~handle(versionHeaders,.json~toJSON(req),'')
call assert r~status=200,'xAI tools/list with negotiated version header succeeds'
d=.json~fromJSON(r~jsonText)
call assert d['result']['tools']~items=8,'xAI compatibility endpoint advertises eight tools'
call assert d['result']['tools'][1]['name']~string='sphere_check','xAI compatibility names selected'

args=.directory~new; args['componentId']='wire_ui_server'
params=.directory~new; params['name']='project_components_list'; params['arguments']=args
req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=3; req['method']='tools/call'; req['params']=params
r=protocol~handle(versionHeaders,.json~toJSON(req),'mcp-test-client')
call assert r~status=200,'xAI tools/call with negotiated version header succeeds'
d=.json~fromJSON(r~jsonText)
call assert d['result']['isError']=.false,'xAI compatibility alias call reaches Wire service'

/* Some gateways attach the version header even to initialize. */
p2=.directory~new; p2['protocolVersion']='2025-11-25'; p2['capabilities']=.directory~new
c2=.directory~new; c2['name']='xai-remote-mcp'; c2['version']='probe'; p2['clientInfo']=c2
req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=4; req['method']='initialize'; req['params']=p2
r=protocol~handle(versionHeaders,.json~toJSON(req),'')
call assert r~status=200,'initialize with matching 2025-11-25 header succeeds'

/* Mismatched and unknown headers remain fail-closed. */
mismatch=.directory~new; mismatch['mcp-protocol-version']='2025-06-18'
r=protocol~handle(mismatch,.json~toJSON(req),'')
d=.json~fromJSON(r~jsonText)
call assert d['error']['code']=-32602,'mismatched initialize header/body rejected'

badHeaders=.directory~new; badHeaders['mcp-protocol-version']='2024-01-01'
req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=5; req['method']='tools/list'; req['params']=.directory~new
r=protocol~handle(badHeaders,.json~toJSON(req),'')
d=.json~fromJSON(r~jsonText)
call assert r~status=400 & d['error']['code']=-32020,'unknown version header rejected explicitly'

say 'PASS test_mcp_xai_streamable_http'
exit 0
assert: procedure
 use arg c,l
 if \c then do; say 'FAIL:' l; exit 1; end
 return

::requires 'McpProtocolAdapter.cls'
::requires 'json.cls'
