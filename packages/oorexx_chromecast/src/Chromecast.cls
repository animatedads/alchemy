/* Chromecast.cls - object-preserving Chromecast client model/controllers. */

::class CastRequestIds public
::method init
  expose nextId
  use strict arg startAt=1
  nextId=startAt+0
::method next
  expose nextId
  id=nextId; nextId+=1
  return id

::class CastConnection public
::method init
  expose endpoint sourceId destinationId buffer open
  use strict arg endpoint, sourceId="sender-0", destinationId="receiver-0"
  if endpoint=.nil then raise syntax 88.900 array("CastConnection requires a stream endpoint")
  endpoint=endpoint; sourceId=sourceId; destinationId=destinationId; buffer=""; open=.true
::attribute endpoint get
::attribute sourceId get
::attribute destinationId
::method sendMessage
  expose endpoint open
  use strict arg message
  if \open then return .false
  frame=.CastFrameCodec~encode(message)
  if endpoint~hasMethod("WRITE") then return endpoint~write(frame)
  if endpoint~hasMethod("SENDALL") then return endpoint~sendAll(frame)=length(frame)
  if endpoint~hasMethod("SEND") then return endpoint~send(frame)=length(frame)
  raise syntax 88.900 array("Cast endpoint has no write/send method")
::method sendText
  expose sourceId destinationId
  use strict arg namespace, payload, destination=.nil
  if destination=.nil then destination=destinationId
  return self~sendMessage(.CastMessage~new(sourceId,destination,namespace,.CastPayloadType~STRING,payload))
::method receive
  expose endpoint buffer open
  use strict arg maximumBytes=65536
  if \open then return .nil
  do forever
    decoded=.CastFrameCodec~decodeOne(buffer)
    if decoded[1]<>.nil then do; buffer=decoded[2]; return decoded[1]; end
    if endpoint~hasMethod("READ") then chunk=endpoint~read(maximumBytes)
    else if endpoint~hasMethod("RECV") then chunk=endpoint~recv(maximumBytes)
    else raise syntax 88.900 array("Cast endpoint has no read/recv method")
    if chunk=.nil | chunk="" then return .nil
    buffer=buffer||chunk
  end
::method close
  expose endpoint open
  if \open then return .true
  if endpoint~hasMethod("CLOSE") then endpoint~close
  open=.false
  return .true
::method isOpen
  expose open
  return open

::class CastJsonController public
::method init
  expose connection requestIds namespace destination
  use strict arg connection, namespace, destination="receiver-0", requestIds=.nil
  connection=connection; namespace=namespace; destination=destination
  if requestIds=.nil then requestIds=.CastRequestIds~new
  else requestIds=requestIds
::attribute connection get
::attribute namespace get
::attribute destination
::attribute requestIds get
::method sendDirectory
  expose connection namespace destination
  use strict arg payload
  return connection~sendText(namespace,.json~toJson(payload),destination)
::method request
  expose requestIds
  use strict arg type, extra=.nil
  d=.directory~new
  d["type"]=type
  d["requestId"]=requestIds~next
  if extra<>.nil then do k over extra~allIndexes; d[k]=extra[k]; end
  ok=self~sendDirectory(d)
  return .array~of(ok,d["requestId"])

::class CastConnectionController public subclass CastJsonController
::method init
  use strict arg connection, destination="receiver-0"
  self~init:super(connection,.CastNamespace~CONNECTION,destination)
::method connect
  d=.directory~new; d["type"]="CONNECT"
  return self~sendDirectory(d)
::method closeVirtual
  d=.directory~new; d["type"]="CLOSE"
  return self~sendDirectory(d)

::class CastHeartbeatController public subclass CastJsonController
::method init
  use strict arg connection, destination="receiver-0"
  self~init:super(connection,.CastNamespace~HEARTBEAT,destination)
::method ping
  d=.directory~new; d["type"]="PING"
  return self~sendDirectory(d)
::method pong
  d=.directory~new; d["type"]="PONG"
  return self~sendDirectory(d)

::class CastReceiverController public subclass CastJsonController
::method init
  use strict arg connection, requestIds=.nil
  self~init:super(connection,.CastNamespace~RECEIVER,"receiver-0",requestIds)
::method getStatus
  return self~request("GET_STATUS")
::method launch
  use strict arg appId
  x=.directory~new; x["appId"]=appId
  return self~request("LAUNCH",x)
::method stop
  use strict arg sessionId
  x=.directory~new; x["sessionId"]=sessionId
  return self~request("STOP",x)
::method getAppAvailability
  use strict arg appId
  apps=.array~of(appId)
  x=.directory~new; x["appId"]=apps
  return self~request("GET_APP_AVAILABILITY",x)

::class CastMediaController public subclass CastJsonController
::method init
  use strict arg connection, destination, requestIds=.nil
  self~init:super(connection,.CastNamespace~MEDIA,destination,requestIds)
::method getStatus
  return self~request("GET_STATUS")
::method play
  use strict arg mediaSessionId
  x=.directory~new; x["mediaSessionId"]=mediaSessionId
  return self~request("PLAY",x)
::method pause
  use strict arg mediaSessionId
  x=.directory~new; x["mediaSessionId"]=mediaSessionId
  return self~request("PAUSE",x)
::method stop
  use strict arg mediaSessionId
  x=.directory~new; x["mediaSessionId"]=mediaSessionId
  return self~request("STOP",x)
::method seek
  use strict arg mediaSessionId, currentTime
  x=.directory~new; x["mediaSessionId"]=mediaSessionId; x["currentTime"]=currentTime
  return self~request("SEEK",x)
::method load
  use strict arg contentId, contentType, streamType="BUFFERED", autoplay=.true, currentTime=0
  media=.directory~new; media["contentId"]=contentId; media["contentType"]=contentType; media["streamType"]=streamType
  x=.directory~new; x["media"]=media; x["autoplay"]=autoplay; x["currentTime"]=currentTime
  return self~request("LOAD",x)

::class CastDevice public
::method init
  expose service connection requestIds
  use strict arg service
  service=service; connection=.nil; requestIds=.CastRequestIds~new
::attribute service get
::attribute connection get
::method name
  expose service
  return service~friendlyName
::method model
  expose service
  return service~model
::method deviceId
  expose service
  return service~deviceId
::method host
  expose service
  return service~host
::method port
  expose service
  return service~port
::method addresses
  expose service
  return service~addresses
::method attachConnection
  expose connection
  use strict arg connectionArg
  connection=connectionArg
  return self
::method connectionController
  expose connection
  if connection=.nil then return .nil
  return .CastConnectionController~new(connection)
::method heartbeat
  expose connection
  if connection=.nil then return .nil
  return .CastHeartbeatController~new(connection)
::method receiver
  expose connection requestIds
  if connection=.nil then return .nil
  return .CastReceiverController~new(connection,requestIds)
::method media
  expose connection requestIds
  use strict arg transportId
  if connection=.nil then return .nil
  return .CastMediaController~new(connection,transportId,requestIds)

::requires "json.cls"
::requires "CastV2.cls"
::requires "CastDiscovery.cls"
