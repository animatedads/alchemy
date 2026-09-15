parse source . . here
pkg=filespec('location',here)
catalog=.McpProjectComponentCatalog~fromJsonFile(pkg||'../catalog/components.json')
service=.McpProjectWireService~new(catalog,.McpProjectMemoryJournal~new)
protocol=.McpProtocolAdapter~new(service,'compat')
headers=.directory~new

/* Grok-style initialize-era discovery against the compatibility presentation. */
params=.directory~new
params['protocolVersion']='2025-03-26'
params['capabilities']=.directory~new
client=.directory~new; client['name']='grok-compat-probe'; client['version']='1.0'; params['clientInfo']=client
req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=1; req['method']='initialize'; req['params']=params
r=protocol~handle(headers,.json~toJSON(req),'')
call assert r~status=200,'compat initialize status'
d=.json~fromJSON(r~jsonText)
call assert d['result']['protocolVersion']~string='2025-03-26','compat initialize selects requested protocol'

req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=2; req['method']='tools/list'; req['params']=.directory~new
r=protocol~handle(headers,.json~toJSON(req),'')
call assert r~status=200,'compat tools/list status'
d=.json~fromJSON(r~jsonText)
tools=d['result']['tools']
call assert tools~items=8,'compat surface advertises exactly eight tools'
call assert tools[1]['name']~string='sphere_check','compat surface uses underscore name'
call assert tools[2]['name']~string='project_components_list','component list underscore name'
call assert tools[5]['name']~string='project_ownership_release','ownership release underscore name'
call assert tools[2]['inputSchema']['properties']~hasIndex('componentKind'),'component list schema advertises componentKind filter'
call assert \tools[1]['inputSchema']~hasIndex('$schema'),'compat schema omits $schema declaration'
call assert tools[1]['inputSchema']['additionalProperties']~isA(.JsonBoolean),'compat schema additionalProperties is JSON boolean'
call assert \tools[1]['inputSchema']['additionalProperties']~value,'compat schema additionalProperties is false'

do tool over tools
  call assert tool['name']~pos('.')=0,'compat tool name contains no dot: '||tool['name']~string
end

/* The alias dispatches to the same semantic operation. */
args=.directory~new; args['componentId']='wire_ui_server'
params=.directory~new; params['name']='project_components_list'; params['arguments']=args
req=.directory~new; req['jsonrpc']=.JsonString~new('2.0'); req['id']=3; req['method']='tools/call'; req['params']=params
r=protocol~handle(headers,.json~toJSON(req),'architect')
d=.json~fromJSON(r~jsonText)
call assert r~status=200 & d['result']['isError']=.false,'compat alias tools/call succeeds'
call assert d['result']['structuredContent']['code']~string='COMPONENTS_LISTED','compat alias reaches component list semantic operation'

/* Canonical adapters accept an underscore alias even though they do not advertise it. */
canonical=.McpProtocolAdapter~new(service)
params['name']='project_components_list'; req['id']=4; req['params']=params
r=canonical~handle(headers,.json~toJSON(req),'architect')
d=.json~fromJSON(r~jsonText)
call assert r~status=200 & d['result']['structuredContent']['code']~string='COMPONENTS_LISTED','canonical adapter accepts compatibility alias call'

say 'PASS test_mcp_compat_names'
exit 0
assert: procedure
  use arg c,l
  if \c then do; say 'FAIL:' l; exit 1; end
  return

::requires 'McpProtocolAdapter.cls'
::requires 'json.cls'
