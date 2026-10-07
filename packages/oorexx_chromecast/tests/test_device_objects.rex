call main
exit 0
main:
  a=.array~of('192.168.1.50')
  t=.directory~new; t['fn']='Office TV'; t['md']='Chromecast Ultra'; t['id']='id-42'
  s=.CastDiscoveredService~new('Office TV._googlecast._tcp.local','cast.local',8009,a,t)
  d=.CastDevice~new(s)
  call assert d~name='Office TV','device name preserved'
  call assert d~model='Chromecast Ultra','device model preserved'
  ep=.FakeStream~new
  c=.CastConnection~new(ep)
  d~attachConnection(c)
  call assert d~connection==c,'connection object identity preserved'
  ok=d~connectionController~connect
  call assert ok,'virtual connect sent'
  r=d~receiver~getStatus
  call assert r[1],'receiver request sent'
  call assert ep~writes~items=2,'two frames written'
  m=.CastFrameCodec~decodeOne(ep~writes[1])[1]
  call assert m~namespace=.CastNamespace~CONNECTION,'connection namespace'
  say 'PASS Chromecast object/controller contract'
  return
assert:
  use strict arg ok,why
  if \ok then do; say 'FAIL' why; exit 1; end
  return
::class FakeStream
::method init
  expose writes
  writes=.array~new
::attribute writes get
::method write
  expose writes
  use strict arg b
  writes~append(b)
  return .true
::method read
  return .nil
::method close
  return .true
::requires '../src/Chromecast.cls'
