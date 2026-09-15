parse source . . here
pkg=filespec('location',here)
catalog=.McpProjectComponentCatalog~fromJsonFile(pkg||'../catalog/components.json')
service=.McpProjectWireService~new(catalog,.McpProjectMemoryJournal~new)
protocol=.McpProtocolAdapter~new(service)

headers=.directory~new
headers['mcp-protocol-version']='2026-07-28'
headers['mcp-method']='server/discover'; headers['mcp-name']=''
params=.directory~new; meta=.directory~new; meta['io.modelcontextprotocol/protocolVersion']='2026-07-28'; params['_meta']=meta
req=.directory~new; req['jsonrpc']='2.0'; req['id']=1; req['method']='server/discover'; req['params']=params
r=protocol~handle(headers,.json~toJSON(req),'')
call assert r~status=200,'discover HTTP status'
d=.json~fromJSON(r~jsonText)
call assert d['result']['resultType']~string='complete','discover complete result'
call assert d['result']['supportedVersions'][1]~string='2026-07-28','discover version'
call assert d['result']['_meta']['io.modelcontextprotocol/serverInfo']['name']~string='oorexx-mcp-project-service','serverInfo meta'

headers['mcp-method']='tools/list'
req['id']=2; req['method']='tools/list'
r=protocol~handle(headers,.json~toJSON(req),'')
d=.json~fromJSON(r~jsonText)
call assert d['result']['tools']~items=7,'seven tools listed'
call assert d['result']['ttlMs']=30000,'tools cache ttl'

/* Create request through MCP. */
headers['mcp-method']='tools/call'; headers['mcp-name']='project.request.create'
args=.directory~new; args['componentId']='wire_ui_server'; args['recipientId']='llm:bob'; args['body']='Please review.'
params['name']='project.request.create'; params['arguments']=args
req['id']=3; req['method']='tools/call'; req['params']=params
r=protocol~handle(headers,.json~toJSON(req),'architect')
d=.json~fromJSON(r~jsonText)
call assert d['result']['isError']=.false,'tool create request succeeds'
rid=d['result']['structuredContent']['value']['requestId']~string
call assert rid<>'' ,'request id returned'

/* Client identity never becomes project authority. */
client=.directory~new; client['name']='pretend-admin'; client['version']='99'; meta['io.modelcontextprotocol/clientInfo']=client
headers['mcp-name']='project.ownership.claim'; params['name']='project.ownership.claim'; args=.directory~new; args['componentId']='wire_ui_server'; params['arguments']=args
req['id']=4
r=protocol~handle(headers,.json~toJSON(req),'')
d=.json~fromJSON(r~jsonText)
call assert d['result']['isError']=.true,'clientInfo is not authority'
call assert d['result']['structuredContent']['code']~string='AUTHENTICATED_PRINCIPAL_REQUIRED','auth principal required'

/* Header/body mismatch is transport/protocol failure. */
headers['mcp-name']='sphere.check'
r=protocol~handle(headers,.json~toJSON(req),'architect')
d=.json~fromJSON(r~jsonText)
call assert r~status=400 & d['error']['code']=-32020,'header mismatch rejected'

say 'PASS test_mcp_protocol'
exit 0
assert: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return
::requires 'McpProtocolAdapter.cls'
::requires 'json.cls'
