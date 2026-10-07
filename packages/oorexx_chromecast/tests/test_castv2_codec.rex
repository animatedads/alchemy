call main
exit 0
main:
  m=.CastMessage~new('sender-0','receiver-0',.CastNamespace~HEARTBEAT,.CastPayloadType~STRING,'{"type":"PING"}')
  bytes=m~encode
  m2=.CastMessage~decode(bytes)
  call assert m2~sourceId='sender-0','source id round trip'
  call assert m2~destinationId='receiver-0','destination id round trip'
  call assert m2~namespace=.CastNamespace~HEARTBEAT,'namespace round trip'
  call assert m2~payloadUtf8='{"type":"PING"}','payload round trip'
  frame=.CastFrameCodec~encode(m)
  d=.CastFrameCodec~decodeOne(frame||'tail')
  call assert d[1]~payloadUtf8='{"type":"PING"}','frame decode'
  call assert d[2]='tail','frame remainder'
  say 'PASS CASTV2 codec'
  return
assert:
  use strict arg ok,why
  if \ok then do; say 'FAIL' why; exit 1; end
  return
::requires '../src/CastV2.cls'
