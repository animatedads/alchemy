/* CastV2.cls - Chromecast CASTV2 message/framing primitives.
 * ooRexx Chromecast v0.1-dev1
 */

::class CastBuild public
::constant VERSION "0.1-dev1"
::constant API "chromecast.castv2/0.1"
::constant DEFAULT_PORT 8009

::class CastNamespace public
::constant CONNECTION "urn:x-cast:com.google.cast.tp.connection"
::constant HEARTBEAT "urn:x-cast:com.google.cast.tp.heartbeat"
::constant RECEIVER "urn:x-cast:com.google.cast.receiver"
::constant MEDIA "urn:x-cast:com.google.cast.media"
::constant DEVICEAUTH "urn:x-cast:com.google.cast.tp.deviceauth"

::class CastPayloadType public
::constant STRING 0
::constant BINARY 1

::class CastProto public
::method encodeVarint class
  use strict arg valueArg
  value=valueArg+0
  if value<0 then raise syntax 88.900 array("varint requires non-negative value")
  out=""
  do forever
    b=value//128
    value=value%128
    if value>0 then b=b+128
    out=out||d2c(b)
    if value=0 then leave
  end
  return out

::method decodeVarint class
  use strict arg bytes, offset=1
  value=0; shift=0; p=offset
  do while p<=length(bytes)
    b=c2d(substr(bytes,p,1))
    value=value + (b//128) * (2**shift)
    p+=1
    if b<128 then return .array~of(value,p)
    shift+=7
    if shift>63 then raise syntax 88.900 array("protobuf varint too long")
  end
  raise syntax 88.900 array("truncated protobuf varint")

::method encodeFieldVarint class
  use strict arg fieldNumber, value
  return self~encodeVarint(fieldNumber*8)||self~encodeVarint(value)

::method encodeFieldBytes class
  use strict arg fieldNumber, bytes
  return self~encodeVarint(fieldNumber*8+2)||self~encodeVarint(length(bytes))||bytes

::method skipField class
  use strict arg bytes, offset, wireType
  select
    when wireType=0 then do
      v=self~decodeVarint(bytes,offset)
      return v[2]
    end
    when wireType=1 then return offset+8
    when wireType=2 then do
      v=self~decodeVarint(bytes,offset)
      return v[2]+v[1]
    end
    when wireType=5 then return offset+4
    otherwise raise syntax 88.900 array("unsupported protobuf wire type" wireType)
  end

::class CastMessage public
::method init
  expose protocolVersion sourceId destinationId namespace payloadType payloadUtf8 payloadBinary
  use strict arg sourceId, destinationId, namespace, payloadType=0, payloadUtf8="", payloadBinary="", protocolVersion=0
  protocolVersion=protocolVersion+0
  sourceId=sourceId~string
  destinationId=destinationId~string
  namespace=namespace~string
  payloadType=payloadType+0
  payloadUtf8=payloadUtf8~string
  payloadBinary=payloadBinary
  if sourceId="" | destinationId="" | namespace="" then raise syntax 88.900 array("CastMessage source, destination and namespace are required")
  if payloadType<>.CastPayloadType~STRING & payloadType<>.CastPayloadType~BINARY then raise syntax 88.900 array("invalid Cast payload type")
::attribute protocolVersion get
::attribute sourceId get
::attribute destinationId get
::attribute namespace get
::attribute payloadType get
::attribute payloadUtf8 get
::attribute payloadBinary get

::method encode
  expose protocolVersion sourceId destinationId namespace payloadType payloadUtf8 payloadBinary
  out=.CastProto~encodeFieldVarint(1,protocolVersion)
  out=out||.CastProto~encodeFieldBytes(2,sourceId)
  out=out||.CastProto~encodeFieldBytes(3,destinationId)
  out=out||.CastProto~encodeFieldBytes(4,namespace)
  out=out||.CastProto~encodeFieldVarint(5,payloadType)
  if payloadType=.CastPayloadType~STRING then out=out||.CastProto~encodeFieldBytes(6,payloadUtf8)
  else out=out||.CastProto~encodeFieldBytes(7,payloadBinary)
  return out

::method decode class
  use strict arg bytes
  protocolVersion=0; sourceId=""; destinationId=""; namespace=""; payloadType=0; payloadUtf8=""; payloadBinary=""
  p=1
  do while p<=length(bytes)
    key=.CastProto~decodeVarint(bytes,p); p=key[2]
    field=key[1]%8; wire=key[1]//8
    select
      when field=1 then do
        v=.CastProto~decodeVarint(bytes,p); protocolVersion=v[1]; p=v[2]
      end
      when field=5 then do
        v=.CastProto~decodeVarint(bytes,p); payloadType=v[1]; p=v[2]
      end
      when field=2 | field=3 | field=4 | field=6 | field=7 then do
        if wire<>2 then raise syntax 88.900 array("invalid CastMessage wire type")
        n=.CastProto~decodeVarint(bytes,p); size=n[1]; p=n[2]
        if p+size-1>length(bytes) then raise syntax 88.900 array("truncated CastMessage field")
        data=substr(bytes,p,size); p+=size
        select
          when field=2 then sourceId=data
          when field=3 then destinationId=data
          when field=4 then namespace=data
          when field=6 then payloadUtf8=data
          when field=7 then payloadBinary=data
        end
      end
      otherwise p=.CastProto~skipField(bytes,p,wire)
    end
  end
  return .CastMessage~new(sourceId,destinationId,namespace,payloadType,payloadUtf8,payloadBinary,protocolVersion)

::method asDirectory
  expose protocolVersion sourceId destinationId namespace payloadType payloadUtf8 payloadBinary
  d=.directory~new
  d["protocolVersion"]=protocolVersion
  d["sourceId"]=sourceId
  d["destinationId"]=destinationId
  d["namespace"]=namespace
  d["payloadType"]=payloadType
  if payloadType=.CastPayloadType~STRING then d["payloadUtf8"]=payloadUtf8
  else d["payloadBinary"]=payloadBinary
  return d

::class CastFrameCodec public
::method encode class
  use strict arg castMessage
  payload=castMessage~encode
  return self~u32be(length(payload))||payload

::method decodeOne class
  use strict arg bytes
  if length(bytes)<4 then return .array~of(.nil,bytes)
  n=self~readU32be(bytes,1)
  if length(bytes)<n+4 then return .array~of(.nil,bytes)
  payload=substr(bytes,5,n)
  rest=substr(bytes,n+5)
  return .array~of(.CastMessage~decode(payload),rest)

::method u32be class
  use strict arg nArg
  n=nArg+0
  if n<0 | n>4294967295 then raise syntax 88.900 array("u32 out of range")
  b1=n%16777216; r=n//16777216
  b2=r%65536; r=r//65536
  b3=r%256; b4=r//256
  return d2c(b1)||d2c(b2)||d2c(b3)||d2c(b4)

::method readU32be class
  use strict arg bytes, p=1
  if p+3>length(bytes) then raise syntax 88.900 array("truncated u32")
  return c2d(substr(bytes,p,1))*16777216 + c2d(substr(bytes,p+1,1))*65536 + c2d(substr(bytes,p+2,1))*256 + c2d(substr(bytes,p+3,1))
