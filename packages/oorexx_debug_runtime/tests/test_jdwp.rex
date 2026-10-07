parse source . . here
call directory filespec('L',here)

p=.JdwpPacket~new(16909060,0,1,7,0,'ABC')
b=p~encode
if b~length<>14 then call fail 'command packet length'
q=.JdwpPacketCodec~decode(b)
if q~id<>16909060 | q~commandSet<>1 | q~command<>7 | q~payload<>'ABC' then call fail 'command roundtrip'

p=.JdwpPacket~new(99,.JdwpProtocol~REPLY_FLAG,0,0,13,'XYZ')
q=.JdwpPacketCodec~decode(p~encode)
if \q~isReply | q~errorCode<>13 | q~payload<>'XYZ' then call fail 'reply roundtrip'
if .JdwpProtocol~HANDSHAKE<>'JDWP-Handshake' then call fail 'handshake constant'

say 'DEBUG JDWP WIRE: OK'
exit 0
fail: procedure
  parse arg m; say 'FAIL:' m; exit 1
::requires "JdwpWire.cls"
