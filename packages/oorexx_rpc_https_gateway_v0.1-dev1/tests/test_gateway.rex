/* Contract integration test, requires ooRexx 5.3+ and four source dependencies.
 * Set REXX_PATH to HttpsServer/rexx, RPC core/src, JSON RPC/src and src.
 */
call assert .true, .true, 'test harness'
svc = .TestService~new
coreRegistry = .RpcServiceRegistry~new
coreRegistry~registerMethod('catalog','lookup',svc,'lookup')
coreRegistry~freeze
coreDispatcher = .RpcServiceDispatcher~new(coreRegistry)
policy = .TestAuthority~new
handler = .RpcHttpsJsonGateway~new(coreRegistry,coreDispatcher,policy,4096)
handler~registry~registerOperation('catalog.lookup','catalog','lookup')
handler~registry~freeze
request = newRequest('POST','{"jsonrpc":"2.0","method":"catalog.lookup","params":[],"id":"r1"}')
response = handler~handle(request)
call assert response~status,200,'success status'
call checkContains response~body,'"result"','registered object call'
call checkContains response~body,'"ok"','service return value'
call assert svc~calls,1,'called once'
policy~permit=.false
response=handler~handle(newRequest('POST','{"jsonrpc":"2.0","method":"catalog.lookup","params":[],"id":2}'))
call checkContains response~body,'-32001','per-operation deny'
call assert svc~calls,1,'no invocation on denied operation'
policy~permit=.true
policy~authenticated=.false
response=handler~handle(newRequest('POST','{"jsonrpc":"2.0","method":"catalog.lookup","params":[],"id":2}'))
call assert response~status,401,'authentication fail closed'
call assert svc~calls,1,'no invocation unauthenticated'
policy~authenticated=.true
policy~misbound=.true
response=handler~handle(newRequest('POST','{"jsonrpc":"2.0","method":"catalog.lookup","id":2}'))
call assert response~status,401,'stale session binding rejected'
policy~misbound=.false
response=handler~handle(newRequest('POST','{"jsonrpc":"2.0","method":"secret.erase","id":2}'))
call checkContains response~body,'-32601','unpublished method rejected'
call assert svc~calls,1,'no reflection into arbitrary method'
response=handler~handle(newRequest('POST','{"jsonrpc":"2.0","method":"catalog.lookup","params":[]}'))
call assert response~status,204,'notification response'
call assert svc~calls,2,'notification invoked once'
response=handler~handle(newRequest('GET','{}'))
call assert response~status,405,'GET rejected'
request = newRequest('POST','{}')
h = request~headers
h['content-type']='text/plain'
response=handler~handle(request)
call assert response~status,415,'unsupported content type'
request = newRequest('POST','{}')
h = request~headers
h['content-encoding']='gzip'
response=handler~handle(request)
call assert response~status,415,'unsupported encoding'
request = newRequest('POST',copies('x',5000))
response=handler~handle(request)
call assert response~status,413,'size limit'
request = newRequest('POST','{}','')
response=handler~handle(request)
call assert response~status,403,'TLS required'
request = newRequest('POST','{}','TLSv1.3',.false)
response=handler~handle(request)
call assert response~status,403,'context required'
call assert policy~authorizedCount,3,'authorize executed for every published call'
say 'PASS RPC HTTPS gateway registered object and policy smoke tests'
exit 0

newRequest:
  use strict arg method, body, tls='TLSv1.3', withContext=.true
  headers=.Directory~new
  headers['content-type']='application/json'
  r=.HttpRequest~new(method,'/rpc','/rpc','','HTTP/1.1',headers,body,.false,'127.0.0.1',tls,'cipher',1)
  if withContext then r~attachContext(.HttpExchangeContext~new('test-request-id',r))
  return r
assert:
  use arg observed,expected,label
  if observed \== expected then do
    say 'FAIL' label 'expected' expected 'got' observed
    exit 1
  end
  return
checkContains:
  use arg haystack,needle,label
  if pos(needle,haystack)==0 then do
    say 'FAIL' label
    exit 1
  end
  return
::class TestService
::attribute calls get
::method init
  expose calls
  calls=0
::method lookup
  expose calls
  use strict arg params,context
  calls += 1
  return .JsonString~new('ok')
::class TestAuthority
::attribute authenticated
::attribute permit
::attribute authorizedCount get
::attribute misbound
::method init
  expose authenticated permit authorizedCount misbound
  authenticated=.true
  permit=.true
  authorizedCount=0
  misbound=.false
::method authenticate
  expose authenticated misbound
  use strict arg request,exchange
  if \authenticated then return .nil
  if misbound then return .TestStaleIdentity~new
  return .RpcHttpsIdentityAttestation~new('test-fixture:verified-subject',request)
::method authorizeOperation
  expose permit authorizedCount
  use strict arg principal,service,operation,exchange
  authorizedCount += 1
  return permit
::class TestStaleIdentity subclass RpcHttpsIdentityAttestation
::method init
  expose identityId requestId peerAddress tlsGeneration
  identityId='bad'
  requestId='not-current-request'
  peerAddress='127.0.0.1'
  tlsGeneration=1
::requires 'https_server.cls'
::requires 'RpcServiceCore.cls'
::requires 'JsonRpcFabric.cls'
::requires 'RpcHttpsJsonGateway.cls'
