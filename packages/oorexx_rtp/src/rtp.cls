/* Shared RTP layer. RTP owns RTP framing/media semantics, never carrier sockets. */
::class RtpBuild public
::constant VERSION "0.1-dev2"
::constant API "rtp/0.1"
::constant CARRIER_API "socket.provider/0.1"

::class RtpLogEmitter public
::method init
  expose sink component objectId sequence
  use strict arg sink=.nil, component="rtp", objectId=""
  if objectId="" then objectId=self~token
  sequence=0
::attribute objectId get
::method token
  return rtp_token()~left(16)
::method emit
  expose sink component objectId sequence
  use strict arg eventType, fields=.nil
  if sink==.nil then return .nil
  sequence+=1
  event=.directory~new
  event["schema"]="oorexx.rtp.event/1"
  event["eventId"]=rtp_token()
  event["eventSequence"]=sequence
  event["eventType"]=eventType
  event["component"]=component
  event["objectId"]=objectId
  if fields<>.nil then do key over fields
    event[key]=fields[key]
  end
  sink~recordEvent(event)
  return event
::method fields
  use strict arg pairs
  d=.directory~new
  do i=1 to pairs~items by 2
    d[pairs[i]]=pairs[i+1]
  end
  return d

/* A shared RTP endpoint owns no OS socket itself. SocketProvider acquires and
 * owns the datagram endpoint; RTP retains only the provider endpoint object. */
::class RtpEndpoint public
::method init
  expose socketProvider datagramEndpoint bindAddress requestedPort localPort state log objectId
  use strict arg socketProvider, bindAddress="0.0.0.0", requestedPort=0, logSink=.nil
  if socketProvider=.nil then raise syntax 88.900 array("RtpEndpoint requires SocketProvider")
  log=.RtpLogEmitter~new(logSink,"rtp.endpoint")
  objectId=log~objectId
  address=.SocketAddresses~udp(bindAddress,requestedPort)
  datagramEndpoint=socketProvider~listenerAt(address)
  if datagramEndpoint=.nil then raise syntax 88.900 array("SocketProvider could not acquire RTP UDP endpoint")
  if \datagramEndpoint~hasMethod("SENDTO") | \datagramEndpoint~hasMethod("RECVFROM") then
    raise syntax 88.900 array("RTP carrier must be a datagram endpoint")
  localPort=datagramEndpoint~localPort
  state="OPEN"
  fields=log~fields(.array~of("bindAddress",bindAddress,"requestedPort",requestedPort,"localPort",localPort,"carrierTransport",datagramEndpoint~address~transport,"carrierScheme",datagramEndpoint~address~scheme))
  event=log~emit("RTP.ENDPOINT.OPENED",fields)
::attribute objectId get
::attribute bindAddress get
::attribute requestedPort get
::attribute localPort get
::attribute state get
::method carrierEndpoint
  expose datagramEndpoint
  return datagramEndpoint
::method carrierAddress
  expose datagramEndpoint
  return datagramEndpoint~address
::method sendTo
  expose datagramEndpoint state
  use strict arg bytes, address, port
  if state<>"OPEN" then return -1
  return datagramEndpoint~sendTo(bytes,address,port)
::method receiveDatagram
  expose datagramEndpoint state
  use strict arg maximumBytes=65535, timeoutSeconds=1
  if state<>"OPEN" then return .nil
  return datagramEndpoint~recvFrom(maximumBytes,timeoutSeconds)
::method close
  expose datagramEndpoint state log localPort
  if state="CLOSED" then return 0
  resultCode=datagramEndpoint~close
  state="CLOSED"
  fields=log~fields(.array~of("localPort",localPort,"result",resultCode))
  event=log~emit("RTP.ENDPOINT.CLOSED",fields)
  return resultCode
::method uninit
  expose datagramEndpoint state
  if state<>"CLOSED" then ignore=datagramEndpoint~close

::class RtpAudioFrame public
::method init
  expose data sampleRate channels sampleFormat payloadType sampleCount sequence timestamp ssrc marker sourceAddress sourcePort
  use strict arg data, sampleRate=8000, channels=1, sampleFormat="S16LE", payloadType=0, sampleCount=0, sequence=0, timestamp=0, ssrc=0, marker=0, sourceAddress="", sourcePort=0
::attribute data get
::attribute sampleRate get
::attribute channels get
::attribute sampleFormat get
::attribute payloadType get
::attribute sampleCount get
::attribute sequence get
::attribute timestamp get
::attribute ssrc get
::attribute marker get
::attribute sourceAddress get
::attribute sourcePort get
::method bytes
  expose data
  return data~length

::class RtpSendResult public
::method init
  expose sampleCount sequence timestamp ssrc payloadType packetBytes remoteAddress remotePort
  use strict arg sampleCount, sequence, timestamp, ssrc, payloadType, packetBytes, remoteAddress, remotePort
::attribute sampleCount get
::attribute sequence get
::attribute timestamp get
::attribute ssrc get
::attribute payloadType get
::attribute packetBytes get
::attribute remoteAddress get
::attribute remotePort get

::class RtpReceiver public
::method init
  expose endpoint payloadType state callId log objectId
  use strict arg endpoint, payloadType=0, callId="", logSink=.nil
  log=.RtpLogEmitter~new(logSink,"rtp.receiver")
  objectId=log~objectId
  self~validatePayloadType(payloadType)
  state="CREATED"
  fields=log~fields(.array~of("callId",callId,"endpointObjectId",endpoint~objectId,"localPort",endpoint~localPort,"payloadType",payloadType))
  event=log~emit("RTP.RECEIVER.CREATED",fields)
::attribute objectId get
::attribute endpoint get
::attribute payloadType get
::attribute callId get
::attribute state get
::method validatePayloadType
  use strict arg value
  if value<>0 then do
    if value<>8 then raise syntax 88.900 array("RTP supports payload types 0 PCMU and 8 PCMA")
  end
::method localPort
  expose endpoint
  return endpoint~localPort
::method start
  expose state log callId
  state="RUNNING"
  event=log~emit("RTP.RECEIVER.STARTED",log~fields(.array~of("callId",callId,"state",state)))
  return state
::method stop
  expose state log callId
  state="STOPPED"
  event=log~emit("RTP.RECEIVER.STOPPED",log~fields(.array~of("callId",callId,"state",state)))
  return state
::method receiveFrame
  expose endpoint state payloadType log callId
  use strict arg timeoutMilliseconds=1000, maxSamples=1600
  if state<>"RUNNING" then return .nil
  timeoutSeconds=timeoutMilliseconds/1000
  datagram=endpoint~receiveDatagram(65535,timeoutSeconds)
  if datagram=.nil then return .nil
  raw=rtp_packet_decode(datagram[1],payloadType,maxSamples)
  if raw=.nil then do
    fields=log~fields(.array~of("callId",callId,"sourceAddress",datagram[2],"sourcePort",datagram[3],"bytes",datagram[4]))
    event=log~emit("RTP.RECEIVER.DROPPED",fields)
    return .nil
  end
  frame=.RtpAudioFrame~new(raw[1],raw[8],1,raw[9],raw[5],raw[7],raw[2],raw[3],raw[4],raw[6],datagram[2],datagram[3])
  fields=log~fields(.array~of("callId",callId,"sequence",frame~sequence,"timestamp",frame~timestamp,"ssrc",frame~ssrc,"payloadType",frame~payloadType,"samples",frame~sampleCount,"sourceAddress",frame~sourceAddress,"sourcePort",frame~sourcePort))
  event=log~emit("RTP.RECEIVER.FRAME",fields)
  return frame
::method close
  expose state log callId
  state="CLOSED"
  event=log~emit("RTP.RECEIVER.CLOSED",log~fields(.array~of("callId",callId)))
  return 1

::class RtpSender public
::method init
  expose endpoint payloadType remoteAddress remotePort state callId log objectId sequence timestamp ssrc
  use strict arg endpoint, remoteAddress, remotePort, payloadType=0, callId="", logSink=.nil
  if remotePort<1 | remotePort>65535 then raise syntax 88.900 array("invalid RTP remote port")
  if payloadType<>0 then do
    if payloadType<>8 then raise syntax 88.900 array("RTP supports payload types 0 PCMU and 8 PCMA")
  end
  log=.RtpLogEmitter~new(logSink,"rtp.sender")
  objectId=log~objectId
  state="CREATED"
  sequence=1
  timestamp=0
  ssrc=random(1,999999999)
  fields=log~fields(.array~of("callId",callId,"endpointObjectId",endpoint~objectId,"localPort",endpoint~localPort,"remoteAddress",remoteAddress,"remotePort",remotePort,"payloadType",payloadType))
  event=log~emit("RTP.SENDER.CREATED",fields)
::attribute objectId get
::attribute endpoint get
::attribute payloadType get
::attribute remoteAddress get
::attribute remotePort get
::attribute callId get
::attribute state get
::method start
  expose state log callId
  state="RUNNING"
  event=log~emit("RTP.SENDER.STARTED",log~fields(.array~of("callId",callId,"state",state)))
  return state
::method stop
  expose state log callId
  state="STOPPED"
  event=log~emit("RTP.SENDER.STOPPED",log~fields(.array~of("callId",callId,"state",state)))
  return state
::method sendFrame
  expose endpoint state remoteAddress remotePort payloadType log callId sequence timestamp ssrc
  use strict arg frame
  if state<>"RUNNING" then return .nil
  samples=frame~data~length%2
  if samples<1 then return .nil
  packet=rtp_packet_encode(frame~data,payloadType,sequence,timestamp,ssrc,0)
  if packet=.nil then return .nil
  sent=endpoint~sendTo(packet,remoteAddress,remotePort)
  if sent<>packet~length then raise syntax 88.900 array("RTP carrier send failed")
  sendResult=.RtpSendResult~new(samples,sequence,timestamp,ssrc,payloadType,sent,remoteAddress,remotePort)
  fields=log~fields(.array~of("callId",callId,"sequence",sequence,"timestamp",timestamp,"ssrc",ssrc,"payloadType",payloadType,"samples",samples,"bytes",sent,"remoteAddress",remoteAddress,"remotePort",remotePort))
  event=log~emit("RTP.SENDER.FRAME",fields)
  sequence=(sequence+1)//65536
  timestamp=timestamp+samples
  return sendResult
::method close
  expose state log callId
  state="CLOSED"
  event=log~emit("RTP.SENDER.CLOSED",log~fields(.array~of("callId",callId)))
  return 1

::routine rtp_token
  return d2x(random(0,999999999),8)||d2x(random(0,999999999),8)

::requires "SocketProvider.cls"
::requires "oorexx_rtp" LIBRARY
