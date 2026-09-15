/* Regression for the v0.4.4 serialized native TLS lane. Memory BIO transport
 * keeps network I/O outside OpenSSL, so one native lane is sufficient. */

call requireSerializedConfig

gate=.TlsNativeGate~new(1)
fake=.FakeLibrary~new
messages=.array~new

do i=1 to 32
  messages~append(gate~start('invoke',fake,'fake',.array~of(i)))
end

do message over messages
  ignored=message~result
end

if fake~maxActive<>1 then do
  say 'FAIL TLS native lane overlapped maxActive='fake~maxActive
  exit 1
end
if gate~maxConcurrent<>1 then do
  say 'FAIL TLS gate telemetry expected maxConcurrent=1 got='gate~maxConcurrent
  exit 1
end
if gate~invocationCount<>32 then do
  say 'FAIL TLS gate invocation count='gate~invocationCount
  exit 1
end

say 'PASS serialized TLS native lane count='gate~laneCount 'maxConcurrent='gate~maxConcurrent 'calls='gate~invocationCount
exit 0

requireSerializedConfig:
  signal on syntax name rejected
  c=.HttpsServerConfig~new
  c~certificateFile='dummy-cert'
  c~privateKeyFile='dummy-key'
  c~bridgeDirectory='dummy-bridge'
  c~nativeTlsConcurrency=2
  ignored=c~validate
  say 'FAIL HTTPS config allowed nativeTlsConcurrency=2'
  exit 1
rejected:
  say 'PASS memory-BIO config requires one native TLS lane'
  return

::class FakeLibrary
::attribute maxActive get

::method init
  expose active maxActive
  active=0
  maxActive=0

::method enter
  expose active maxActive
  active=active+1
  if active>maxActive then maxActive=active

::method leave
  expose active
  active=active-1

::method invokeArray unguarded
  use strict arg name, args
  self~enter
  call SysSleep .02
  self~leave
  return args[1]

::requires 'https_server.cls'
