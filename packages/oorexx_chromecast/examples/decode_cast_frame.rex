/* Feed a hex CASTV2 frame as argv[1] and display decoded fields. */
parse arg h
if h='' then do; say 'usage: rexx decode_cast_frame.rex HEX'; exit 2; end
x=.CastFrameCodec~decodeOne(x2c(h))
if x[1]=.nil then do; say 'incomplete frame'; exit 1; end
m=x[1]
say 'source='m~sourceId
say 'destination='m~destinationId
say 'namespace='m~namespace
say 'payloadType='m~payloadType
if m~payloadType=.CastPayloadType~STRING then say 'payload='m~payloadUtf8
else say 'payloadHex='c2x(m~payloadBinary)
::requires '../src/CastV2.cls'
