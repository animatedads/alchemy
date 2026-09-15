failures=0
call check .HttpUtil~tokenValid('Content-Type'), .true, 'header token valid'
call check .HttpUtil~tokenValid('bad header'), .false, 'header token rejects space'
call check .HttpUtil~lowerContainsToken('keep-alive, Upgrade','upgrade'), .true, 'comma token lookup'
call check .HttpUtil~reason(431), 'Request Header Fields Too Large', 'status reason'
r=.HttpResponse~json('{"ok":true}',201)
call check r~status, 201, 'response status'
call check r~headers['Content-Type'], 'application/json; charset=utf-8', 'json content type'
headers=.directory~new
req=.HttpRequest~new('GET','/x','/x','','HTTP/1.1',headers,'',.true,'127.0.0.1:1','TLSv1.3','TEST-CIPHER',7)
ctx=.HttpExchangeContext~new(42,req)
req~attachContext(ctx)
call check req~context~requestId, 42, 'request context attach'
call check ctx~tlsGeneration, 7, 'context TLS generation projection'
ctx~put('x','y')
call check ctx~has('x'), .true, 'context has'
call check ctx~get('x'), 'y', 'context get'
ctx~remove('x')
call check ctx~has('x'), .false, 'context remove'
call check ctx~get('x','fallback'), 'fallback', 'context default'
if failures>0 then do
  say 'FAIL test_http_util failures='failures
  exit 1
end
say 'PASS test_http_util'
exit 0

check: procedure expose failures
  use arg actual, expected, label
  if actual<>expected then do
    failures=failures+1
    say 'FAIL' label 'expected='expected 'actual='actual
  end
  return

::requires 'https_server.cls'
