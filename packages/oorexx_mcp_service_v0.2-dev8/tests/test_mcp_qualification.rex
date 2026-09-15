.QebTestSetup~installCrypto
projectCatalog=.McpProjectComponentCatalog~new(.array~new,'test','')
project=.McpProjectWireService~new(projectCatalog,.McpProjectMemoryJournal~new)
qcat=.QebTestSetup~catalog
qeb=.QualificationExecutionBroker~new(qcat,.QebMemoryJournal~new,.QebTestSetup~approvers)
p=.McpProtocolAdapter~new(project,'canonical',qeb)
headers=.directory~new
/* Legacy/xAI path is enough to validate advertised and callable surface. */
init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","clientInfo":{"name":"qeb-test","version":"1"},"capabilities":{}}}'
r=p~handle(headers,init,'llm:mcp-qeb'); call assert r~status=200,'initialize status'
list='{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
r=p~handle(headers,list,'llm:mcp-qeb'); d=.json~fromJSON(r~jsonText); tools=d['result']['tools']; call assert tools~items=15,'15 tools with broker'
serialized=.json~toJSON(tools); call assert serialized~pos('qualification.authorization.submit')>0,'submit tool advertised'; call assert serialized~pos('qualification.execute')=0,'execute tool must not exist'; call assert serialized~lower~pos('privatekey')=0,'no private key field in tool schemas'
args=.directory~new; args['artifactId']='demo-artifact'; args['dataId']='demo-data'; args['runtimeId']='oorexx-5.3.0-r13196'; args['sandboxId']='strict-oorexx'; args['testPlanId']='demo-tests'; args['targetId']='ed209-test'; args['purpose']='MCP qualification integration'
r=callTool(p,3,'qualification.plan',args,'llm:mcp-qeb'); call assert r['result']['structuredContent']['code']='PREFLIGHT_VALIDATED','plan preflight code'
r=callTool(p,4,'qualification.request',args,'llm:mcp-qeb'); sc=r['result']['structuredContent']; call assert sc['code']='QUALIFICATION_AWAITING_AUTHORIZATION','request code'; runId=sc['value']['runId']
ra=.directory~new; ra['runId']=runId
r=callTool(p,5,'qualification.authorization.challenge',ra,'llm:mcp-qeb'); sc=r['result']['structuredContent']; call assert sc['code']='AUTHORIZATION_CHALLENGE_READY','challenge code'; msg=sc['value']['messageToSign']
sig=.Ed25519~sign(msg,'9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60')
sub=.directory~new; sub['runId']=runId; sub['approverKeyId']='architect-ed25519'; sub['signature']=sig
r=callTool(p,6,'qualification.authorization.submit',sub,'llm:mcp-qeb'); call assert r['result']['structuredContent']['code']='QUALIFICATION_AUTHORIZED','authorization submit'
/* Compatibility presentation contains aliases only, still 15 total. */
pc=.McpProtocolAdapter~new(project,'compat',qeb); r=pc~handle(headers,list,'llm:mcp-qeb'); d=.json~fromJSON(r~jsonText); tools=d['result']['tools']; call assert tools~items=15,'compat 15 tools'; foundCompat=.false; foundDotted=.false; do t over tools; if t['name']='qualification_status' then foundCompat=.true; if t['name']='qualification.status' then foundDotted=.true; end; call assert foundCompat,'compat qualification status'; call assert \foundDotted,'compat should not advertise dotted qualification name'
/* No broker preserves historic eight-tool surface. */
p8=.McpProtocolAdapter~new(project); r=p8~handle(headers,list,'llm:mcp-qeb'); d=.json~fromJSON(r~jsonText); call assert d['result']['tools']~items=8,'no-broker surface remains eight tools'
say 'PASS test_mcp_qualification'
exit 0

callTool: procedure
  use arg p,id,name,args,actor
  q=.directory~new; q['jsonrpc']=.JsonString~new('2.0'); q['id']=id; q['method']='tools/call'; params=.directory~new; params['name']=name; params['arguments']=args; q['params']=params
  h=.directory~new; rr=p~handle(h,.json~toJSON(q),actor)
  return .json~fromJSON(rr~jsonText)
assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL test_mcp_qualification:' msg; exit 1; end
  return

::class QebTestSetup public
::method installCrypto class
  cryptoHome=value('CRYPTO_HOME',,'ENVIRONMENT'); if cryptoHome='' then return
  .CryptoForeignRuntimeInstaller~install(cryptoHome||'/native/openssl_direct.bridge.json',.nil,1000,'foreign.openssl.crypto',cryptoHome||'/native/openssl_compat.bridge.json')
::method catalog class
  c=.QebAuthorityCatalog~new
  d=.directory~new; d['sha256']='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; d['signed']=.true; d['checked']=.true; d['deployed']=.true; c~add('artifact','demo-artifact',d)
  d=.directory~new; d['manifestSha256']='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; d['authorized']=.true; d['available']=.true; c~add('data','demo-data',d)
  d=.directory~new; d['manifestSha256']='cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'; d['available']=.true; c~add('runtime','oorexx-5.3.0-r13196',d)
  d=.directory~new; d['profileSha256']='dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'; d['available']=.true; d['constructible']=.true; d['maxRuntimeSeconds']=1800; d['maxWlu']=2400; d['networkPolicy']='DENY'; d['writableScopes']=.array~of('/sandbox/work','/sandbox/results'); c~add('sandbox','strict-oorexx',d)
  d=.directory~new; d['manifestSha256']='eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'; d['valid']=.true; d['commands']=.array~of('rexx tests/test_core.rex'); c~add('testplan','demo-tests',d)
  d=.directory~new; d['profileSha256']='ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'; d['eligible']=.true; d['available']=.true; c~add('target','ed209-test',d)
  return c
::method approvers class
  r=.QebApproverRegistry~new; r~add('architect-ed25519','d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'); return r

::requires 'McpProtocolAdapter.cls'
::requires 'QualificationExecutionBroker.cls'
::requires 'CryptoForeignRuntimeProvider.cls'
::requires 'crypto.cls'
::requires 'json.cls'
