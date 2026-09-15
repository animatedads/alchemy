parse source . . here
root=filespec('D',here)||filespec('P',here)'..'
parse arg cert1 key1 cert2 key2 badKey port
if cert1='' | key1='' | cert2='' | key2='' | badKey='' | port='' then do
  say 'usage: rexx lifecycle_server.rex CERT1 KEY1 CERT2 KEY2 BADKEY PORT'
  exit 2
end

config=.HttpsServerConfig~new
config~certificateFile=cert1
config~privateKeyFile=key1
config~port=port
config~bridgeDirectory=root'/bridge'
config~accessLog=.false
config~readTimeout=5
config~writeTimeout=5

server=.HttpsServer~new(config)
app=.LifecycleApp~new(server,cert2,key2,badKey)
server~route('GET','/generation',app,'generation')
server~route('GET','/reload',app,'reload')
server~route('GET','/reload-bad',app,'reloadBad')
server~route('GET','/slow',app,'slow')
server~route('GET','/drain',app,'drain')
server~serve
ok=server~drain(5)
say 'OOREXX_HTTPS_DRAIN_COMPLETE ok='ok' active='server~activeConnectionCount' state='server~lifecycleState' generation='server~tlsGeneration
server~close
exit 0

::class LifecycleApp
::method init
  expose server cert2 key2 badKey
  use strict arg server, cert2, key2, badKey

::method generation
  expose server
  use strict arg request
  return .HttpResponse~text('tls='request~tlsGeneration' current='server~tlsGeneration||'0A'x)

::method reload
  expose server cert2 key2
  use strict arg request
  generation=server~reloadTls(cert2,key2)
  return .HttpResponse~text('reload current='generation' requestTls='request~tlsGeneration||'0A'x)

::method reloadBad
  expose server cert2 badKey
  use strict arg request
  signal on syntax name rejected
  ignored=server~reloadTls(cert2,badKey)
  return .HttpResponse~text('unexpected reload success'||'0A'x,500)
rejected:
  return .HttpResponse~text('rejected current='server~tlsGeneration' requestTls='request~tlsGeneration||'0A'x,409)

::method slow
  use strict arg request
  say 'TEST_SLOW_ENTER tls='request~tlsGeneration
  call SysSleep 1
  return .HttpResponse~text('slow-ok tls='request~tlsGeneration||'0A'x)

::method drain
  expose server
  use strict arg request
  server~stop
  return .HttpResponse~text('draining tls='request~tlsGeneration||'0A'x)~header('Connection','close')

::requires 'https_server.cls'
