/* Structured SIP observability.  Core SIP objects depend only on the tiny
   recordEvent(Directory) sink contract.  src/sip_logging.cls adapts that
   contract to the shared ooRexx Logging Framework v0.7. */
::class SipLogEmitter public
::method init
  expose sink component objectId sequence
  use strict arg sink = .nil, component = "sip", objectId = ""
  if objectId = "" then objectId = sip_random_token()~left(16)
  sequence = 0
::attribute objectId get
::method emit
  expose sink component objectId sequence
  use strict arg eventType, fields = .nil
  if sink == .nil then return .nil
  sequence += 1
  event = .directory~new
  event["schema"] = "oorexx.sip.event/1"
  event["eventId"] = sip_random_token()
  event["eventSequence"] = sequence
  event["emittedAtMs"] = sip_epoch_millis()
  event["eventType"] = eventType
  event["component"] = component
  event["objectId"] = objectId
  if fields <> .nil then do key over fields
    event[key] = fields[key]
  end
  sink~recordEvent(event)
  return event
::method field
  use strict arg key, value
  d = .directory~new
  d[key] = value
  return d
::method fields
  use strict arg pairs
  d = .directory~new
  do i = 1 to pairs~items by 2
    d[pairs[i]] = pairs[i + 1]
  end
  return d

::class SipSocketFactory public
::method defaultProvider class
  addresses=.RegisteredSocketAddressProvider~new
  selector=.SocketSelector~new(addresses)
  selector~registerBinding(.SocketTransportKind~UDP,.RxSockUdpBinding~new)
  return selector

::class SipUdpTransport public
::method init
  expose endpoint socketProvider bindAddress bindPort log
  use strict arg bindAddress="0.0.0.0", bindPort=0, logSink=.nil, socketProvider=.nil
  log=.SipLogEmitter~new(logSink,"sip.transport.udp")
  if socketProvider=.nil then socketProvider=.SipSocketFactory~defaultProvider
  address=.SocketAddresses~udp(bindAddress,bindPort)
  endpoint=socketProvider~listenerAt(address)
  if endpoint=.nil then raise syntax 98.900 array("SocketProvider could not acquire SIP UDP endpoint")
  if \endpoint~hasMethod("SENDTO") | \endpoint~hasMethod("RECVFROM") then
    raise syntax 98.900 array("SIP UDP transport requires datagram endpoint")
  bindPort=endpoint~localPort
  fields=log~fields(.array~of("bindAddress",bindAddress,"bindPort",bindPort,"transport","UDP","carrierScheme",endpoint~address~scheme))
  event=log~emit("SIP.TRANSPORT.BOUND",fields)
::attribute bindAddress get
::attribute bindPort get
::method carrierEndpoint
  expose endpoint
  return endpoint
::method sendTo
  expose endpoint log bindAddress bindPort
  use strict arg data, address, port
  rc=endpoint~sendTo(data,address,port)
  if rc<0 then do
    fields=log~fields(.array~of("direction","TX","peerAddress",address,"peerPort",port,"result",rc))
    event=log~emit("SIP.WIRE.ERROR",fields)
    raise syntax 98.900 array("SocketProvider UDP send failed")
  end
  fields=log~fields(.array~of("direction","TX","localAddress",bindAddress,"localPort",bindPort,"peerAddress",address,"peerPort",port,"bytes",rc,"wireText",data))
  event=log~emit("SIP.WIRE.TX",fields)
  return rc
::method receive
  expose endpoint log bindAddress bindPort
  use strict arg timeoutSeconds=1
  datagram=endpoint~recvFrom(65535,timeoutSeconds)
  if datagram=.nil then return .nil
  fields=log~fields(.array~of("direction","RX","localAddress",bindAddress,"localPort",bindPort,"peerAddress",datagram[2],"peerPort",datagram[3],"bytes",datagram[4],"wireText",datagram[1]))
  event=log~emit("SIP.WIRE.RX",fields)
  return .array~of(datagram[1],datagram[2],datagram[3])
::method close
  expose endpoint log
  if endpoint<>.nil then do
    rc=endpoint~close
    endpoint=.nil
    event=log~emit("SIP.TRANSPORT.CLOSED")
    return rc
  end
  return 0
::method uninit
  expose endpoint
  if endpoint<>.nil then ignore=endpoint~close

::class SipServer public
::method init
  expose transport engine bindAddress realm algorithm calls registrations log logSink socketProvider
  use strict arg bindAddress="0.0.0.0", port=5060, realm="oorexx-sip", algorithm="SHA-256", logSink=.nil, socketProvider=.nil
  log=.SipLogEmitter~new(logSink,"sip.server")
  if socketProvider=.nil then socketProvider=.SipSocketFactory~defaultProvider
  transport=.SipUdpTransport~new(bindAddress,port,logSink,socketProvider)
  engine = sip_engine_open(bindAddress, realm, algorithm)
  calls = .directory~new
  registrations = .directory~new
  fields = log~fields(.array~of("bindAddress", bindAddress, "port", transport~bindPort, "realm", realm, "algorithm", algorithm))
  event = log~emit("SIP.SERVER.STARTED", fields)
::attribute bindAddress get
::attribute realm get
::method port
  expose transport
  return transport~bindPort
::method credential
  expose engine log
  use strict arg username, password
  rc = sip_server_set_credential(engine, username, password)
  fields = log~fields(.array~of("username", username, "result", rc))
  event = log~emit("SIP.AUTH.CREDENTIAL.CONFIGURED", fields)
  return rc
::method setAuthenticationAlgorithm
  expose engine algorithm log
  use strict arg algorithm
  rc = sip_server_set_auth_algorithm(engine, algorithm)
  fields = log~fields(.array~of("algorithm", algorithm, "result", rc))
  event = log~emit("SIP.AUTH.ALGORITHM", fields)
  return rc
::method poll
  expose transport engine calls registrations log logSink realm bindAddress socketProvider
  use strict arg timeoutSeconds = 1
  expired = self~expireRegistrations
  datagram = transport~receive(timeoutSeconds)
  if datagram == .nil then do
    expired = self~expireRegistrations
    return .array~of("timeout")
  end
  authHeader = sip_message_header(datagram[1], "Authorization")
  callIdHeader = sip_message_header(datagram[1], "Call-ID")
  cseqHeader = sip_message_header(datagram[1], "CSeq")
  method = datagram[1]~word(1)
  processed = sip_engine_process(engine, datagram[1], datagram[2], datagram[3])
  fields = log~fields(.array~of("nativeEvent", processed[1], "method", method, "callId", callIdHeader, "cseq", cseqHeader, "peerAddress", datagram[2], "peerPort", datagram[3], "authorizationPresent", authHeader <> ""))
  eventLogged = log~emit("SIP.ENGINE.EVENT", fields)
  if processed[2] <> "" then sent = transport~sendTo(processed[2], datagram[2], datagram[3])
  if processed[3] <> "" then sent = transport~sendTo(processed[3], datagram[2], datagram[3])
  event = .array~new
  event~append(processed[1])
  count = processed~items
  do i = 4 to count
    event~append(processed[i])
  end
  if processed[1] = "invite-offer" then do
    callId = processed[4]
    remoteAddress = processed[5]
    remoteSipPort = processed[6]
    remoteRtpPort = processed[7]
    payloadType = processed[8]
    rtpEndpoint=.RtpEndpoint~new(socketProvider,bindAddress,0,logSink)
    rtpReceiver = .RtpReceiver~new(rtpEndpoint, payloadType, callId, logSink)
    rtpSender = .RtpSender~new(rtpEndpoint, remoteAddress, remoteRtpPort, payloadType, callId, logSink)
    accepted = sip_engine_accept_invite(engine, callId, rtpEndpoint~localPort)
    if accepted[1] <> "invite" then raise syntax 98.900 array("native SIP engine did not accept INVITE")
    sent = transport~sendTo(accepted[2], datagram[2], datagram[3])
    call = .SipCall~new(engine, callId, remoteAddress, remoteSipPort, remoteRtpPort, rtpEndpoint~localPort, payloadType, rtpEndpoint, rtpReceiver, rtpSender, logSink)
    calls[callId] = call
    fields = log~fields(.array~of("callId", callId, "remoteAddress", remoteAddress, "remoteSipPort", remoteSipPort, "remoteRtpPort", remoteRtpPort, "localRtpPort", rtpEndpoint~localPort, "payloadType", payloadType, "rtpEndpointObjectId", rtpEndpoint~objectId, "rtpReceiverObjectId", rtpReceiver~objectId, "rtpSenderObjectId", rtpSender~objectId))
    callEvent = log~emit("SIP.CALL.CREATED", fields)
    event = .array~of("invite", callId, remoteAddress, remoteSipPort, remoteRtpPort, rtpEndpoint~localPort, payloadType, call)
    return event
  end
  if processed[1] = "register-challenge" then do
    registrationId = processed[4] || "@" || realm
    fields = log~fields(.array~of("registrationId", registrationId, "username", processed[4], "peerAddress", processed[5], "peerPort", processed[6], "authorizationPresent", authHeader <> "", "reason", processed[7]))
    if authHeader = "" then authEvent = log~emit("SIP.AUTH.CHALLENGE", fields)
    else authEvent = log~emit("SIP.AUTH.REJECTED", fields)
  end
  else if processed[1] = "registered" then do
    registrationId = processed[4] || "@" || realm
    if authHeader <> "" then do
      fields = log~fields(.array~of("registrationId", registrationId, "username", processed[4], "peerAddress", processed[7], "peerPort", processed[8], "authorizationPresent", 1))
      authEvent = log~emit("SIP.AUTH.ACCEPTED", fields)
    end
    refreshed = registrations~hasIndex(registrationId)
    if refreshed then do
      binding = registrations[registrationId]
      binding~refresh(processed[5], processed[6], processed[7], processed[8], processed[9], processed[10])
    end
    else do
      binding = .SipRegistrationBinding~new(registrationId, processed[4], processed[5], processed[6], processed[7], processed[8], processed[9], processed[10])
      registrations[registrationId] = binding
    end
    fields = log~fields(.array~of("registrationId", registrationId, "bindingObjectId", binding~objectId, "username", processed[4], "aor", processed[5], "contact", processed[6], "peerAddress", processed[7], "peerPort", processed[8], "expires", processed[9], "expiresAt", processed[10]))
    if refreshed then authEvent = log~emit("SIP.REGISTRATION.REFRESHED", fields)
    else authEvent = log~emit("SIP.REGISTRATION.BOUND", fields)
  end
  else if processed[1] = "unregistered" then do
    registrationId = processed[4] || "@" || realm
    bindingObjectId = ""
    if registrations~hasIndex(registrationId) then do
      bindingObjectId = registrations[registrationId]~objectId
      registrations~remove(registrationId)
    end
    fields = log~fields(.array~of("registrationId", registrationId, "bindingObjectId", bindingObjectId, "username", processed[4], "aor", processed[5], "contact", processed[6], "peerAddress", processed[7], "peerPort", processed[8]))
    authEvent = log~emit("SIP.REGISTRATION.REMOVED", fields)
  end
  if processed[1] = "bye" then do
    callId = processed[4]
    if calls~hasIndex(callId) then do
      call = calls[callId]
      call~control~remoteEnded
      calls~remove(callId)
      fields = log~field("callId", callId)
      callEvent = log~emit("SIP.CALL.REMOVED", fields)
    end
  end
  return event
::method registration
  expose registrations
  use strict arg registrationId
  expired = self~expireRegistrations
  if registrations~hasIndex(registrationId) then return registrations[registrationId]
  return .nil
::method registrationForUser
  expose registrations realm
  use strict arg username
  return self~registration(username || "@" || realm)
::method activeRegistrations
  expose registrations
  expired = self~expireRegistrations
  snapshot = .array~new
  ids = registrations~allIndexes
  do registrationId over ids
    snapshot~append(registrations[registrationId])
  end
  return snapshot
::method expireRegistrations
  expose registrations log
  numeric digits 20
  now = sip_epoch_seconds()
  expiredCount = 0
  ids = registrations~allIndexes
  do registrationId over ids
    binding = registrations[registrationId]
    if binding~expiresAt > 0 then do
      if binding~expiresAt <= now then do
        fields = log~fields(.array~of("registrationId", registrationId, "bindingObjectId", binding~objectId, "username", binding~username, "aor", binding~aor, "contact", binding~contact, "expiredAt", now))
        event = log~emit("SIP.REGISTRATION.EXPIRED", fields)
        registrations~remove(registrationId)
        expiredCount += 1
      end
    end
  end
  return expiredCount
::method call
  expose calls
  use strict arg callId
  if calls~hasIndex(callId) then return calls[callId]
  return .nil
::method activeCalls
  expose calls
  return calls~allIndexes
/* Compatibility shim. New code should use server~call(callId)~audioIn~receive(). */
::method receiveAudio
  expose calls
  use strict arg callId, timeoutMilliseconds = 1000, maxSamples = 1600
  if \calls~hasIndex(callId) then raise syntax 98.900 array("call not found:" callId)
  return calls[callId]~audioIn~receive(timeoutMilliseconds, maxSamples)
::method close
  expose transport engine log
  if transport <> .nil then do
    closed = transport~close
    transport = .nil
  end
  if engine <> .nil then do
    call sip_engine_close engine
    engine = .nil
  end
  event = log~emit("SIP.SERVER.STOPPED")
::method uninit
  expose transport engine
  if transport <> .nil then closed = transport~close
  if engine <> .nil then call sip_engine_close engine

::class SipRegistrationBinding public
::method init
  expose registrationId username aor contact peerAddress peerPort expires expiresAt objectId revision
  use strict arg registrationId, username, aor, contact, peerAddress, peerPort, expires, expiresAt
  objectId = sip_random_token()~left(16)
  revision = 1
::attribute registrationId get
::attribute username get
::attribute aor get
::attribute contact get
::attribute peerAddress get
::attribute peerPort get
::attribute expires get
::attribute expiresAt get
::attribute objectId get
::attribute revision get
::method refresh
  expose aor contact peerAddress peerPort expires expiresAt revision
  use strict arg newAor, newContact, newPeerAddress, newPeerPort, newExpires, newExpiresAt
  aor = newAor
  contact = newContact
  peerAddress = newPeerAddress
  peerPort = newPeerPort
  expires = newExpires
  expiresAt = newExpiresAt
  revision += 1
  return revision
::method remainingSeconds
  expose expiresAt
  numeric digits 20
  remaining = expiresAt - sip_epoch_seconds()
  if remaining < 0 then remaining = 0
  return remaining
::method expired
  expose expiresAt
  numeric digits 20
  return expiresAt > 0 & expiresAt <= sip_epoch_seconds()

::class SipCall public
::method init
  expose engine callId control audioIn audioOut rtpEndpoint rtpReceiver rtpSender remoteAddress remoteSipPort remoteRtpPort localRtpPort payloadType log
  use strict arg engine, callId, remoteAddress, remoteSipPort, remoteRtpPort, localRtpPort, payloadType, rtpEndpoint = .nil, rtpReceiver = .nil, rtpSender = .nil, logSink = .nil
  log = .SipLogEmitter~new(logSink, "sip.call")
  if rtpEndpoint==.nil then rtpEndpoint=.RtpEndpoint~new(.SipSocketFactory~defaultProvider,"127.0.0.1",localRtpPort,logSink)
  localRtpPort = rtpEndpoint~localPort
  if rtpReceiver == .nil then rtpReceiver = .RtpReceiver~new(rtpEndpoint, payloadType, callId, logSink)
  if rtpSender == .nil then rtpSender = .RtpSender~new(rtpEndpoint, remoteAddress, remoteRtpPort, payloadType, callId, logSink)
  control = .SipCallControl~new(callId, logSink)
  audioIn = .SipInboundAudio~new(callId, rtpReceiver, logSink)
  audioOut = .SipOutboundAudio~new(callId, rtpSender, logSink)
  fields = log~fields(.array~of("callId", callId, "controlObjectId", control~objectId, "audioInObjectId", audioIn~objectId, "audioOutObjectId", audioOut~objectId, "rtpEndpointObjectId", rtpEndpoint~objectId, "rtpReceiverObjectId", rtpReceiver~objectId, "rtpSenderObjectId", rtpSender~objectId))
  event = log~emit("SIP.CALL.GRAPH", fields)
::attribute callId get
::attribute control get
::attribute audioIn get
::attribute audioOut get
::attribute rtpEndpoint get
::attribute rtpReceiver get
::attribute rtpSender get
::attribute remoteAddress get
::attribute remoteSipPort get
::attribute remoteRtpPort get
::attribute localRtpPort get
::attribute payloadType get

::class SipControlEvent public
::method init
  expose callId type source detail
  use strict arg callId, type, source = "CONTROL", detail = ""
::attribute callId get
::attribute type get
::attribute source get
::attribute detail get

::class SipCallControl public
::method init
  expose callId state handlers handlerErrors log objectId
  use strict arg callId, logSink = .nil
  log = .SipLogEmitter~new(logSink, "sip.call.control")
  objectId = log~objectId
  state = "CREATED"
  handlers = .directory~new
  handlerErrors = .directory~new
::attribute callId get
::attribute state get
::attribute objectId get
::method attachHandler
  expose handlers handlerErrors log callId
  use strict arg name, handler
  previous = .nil
  if handlers~hasIndex(name) then previous = handlers[name]
  handlers[name] = handler
  if handlerErrors~hasIndex(name) then handlerErrors~remove(name)
  fields = log~fields(.array~of("callId", callId, "handler", name))
  event = log~emit("SIP.CONTROL.HANDLER.ATTACHED", fields)
  return previous
::method detachHandler
  expose handlers handlerErrors log callId
  use strict arg name
  if \handlers~hasIndex(name) then return .nil
  previous = handlers[name]
  handlers~remove(name)
  if handlerErrors~hasIndex(name) then handlerErrors~remove(name)
  fields = log~fields(.array~of("callId", callId, "handler", name))
  event = log~emit("SIP.CONTROL.HANDLER.DETACHED", fields)
  return previous
::method handlerNames
  expose handlers
  return handlers~allIndexes
::method handlerError
  expose handlerErrors
  use strict arg name
  if handlerErrors~hasIndex(name) then return handlerErrors[name]
  return ""
::method emit
  expose handlers handlerErrors log callId
  use strict arg event
  names = handlers~allIndexes
  do name over names
    error = self~dispatchHandler(handlers[name], event)
    if error = "" then do
      if handlerErrors~hasIndex(name) then handlerErrors~remove(name)
    end
    else do
      handlerErrors[name] = error
      fields = log~fields(.array~of("callId", callId, "handler", name, "error", error))
      failureEvent = log~emit("SIP.CONTROL.HANDLER.FAILED", fields)
    end
  end
  return event
::method dispatchHandler
  use strict arg handler, event
  signal on syntax name handlerFailure
  handler~controlEvent(event)
  signal off syntax
  return ""
handlerFailure:
  say "SIP control handler failure rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  description = condition("D")
  if description = "" then description = condition("C")
  if description = "" then description = "SYNTAX"
  signal off syntax
  return description
::method start
  expose state callId log
  if state = "CREATED" | state = "STOPPED" then state = "RUNNING"
  event = self~emit(.SipControlEvent~new(callId, "STARTED"))
  fields = log~fields(.array~of("callId", callId, "state", state))
  logEvent = log~emit("SIP.CONTROL.STARTED", fields)
  return state
::method pause
  expose state callId log
  if state = "RUNNING" then do
    state = "PAUSED"
    event = self~emit(.SipControlEvent~new(callId, "PAUSED"))
  fields = log~fields(.array~of("callId", callId, "state", state))
  logEvent = log~emit("SIP.CONTROL.PAUSED", fields)
  end
  return state
::method resume
  expose state callId log
  if state = "PAUSED" then do
    state = "RUNNING"
    event = self~emit(.SipControlEvent~new(callId, "RESUMED"))
  fields = log~fields(.array~of("callId", callId, "state", state))
  logEvent = log~emit("SIP.CONTROL.RESUMED", fields)
  end
  return state
::method stop
  expose state callId log
  state = "STOPPED"
  event = self~emit(.SipControlEvent~new(callId, "STOPPED"))
  fields = log~fields(.array~of("callId", callId, "state", state))
  logEvent = log~emit("SIP.CONTROL.STOPPED", fields)
  return state
::method remoteEnded
  expose state callId log
  state = "STOPPED"
  event = self~emit(.SipControlEvent~new(callId, "REMOTE_ENDED", "REMOTE"))
  fields = log~fields(.array~of("callId", callId, "state", state))
  logEvent = log~emit("SIP.CONTROL.REMOTE_ENDED", fields)
  return state

/* RTP transport has moved to the shared rtp/0.1 package.  SIP negotiates
   media parameters and binds shared RtpEndpoint/RtpReceiver/RtpSender objects. */

/* Application-facing inbound stream.  Multiple consumers can observe the same
   frame independently.  Consumer failure is isolated and recorded per binding. */
::class SipInboundAudio public
::method init
  expose callId receiver state consumers consumerErrors log objectId
  use strict arg callId, receiver, logSink = .nil
  log = .SipLogEmitter~new(logSink, "sip.audio.in")
  objectId = log~objectId
  state = "CREATED"
  consumers = .directory~new
  consumerErrors = .directory~new
::attribute callId get
::attribute state get
::attribute receiver get
::attribute objectId get
::method payloadType
  expose receiver
  return receiver~payloadType
::method localRtpPort
  expose receiver
  return receiver~localPort
::method attachConsumer
  expose consumers consumerErrors log callId
  use strict arg name, newConsumer
  previous = .nil
  if consumers~hasIndex(name) then previous = consumers[name]
  consumers[name] = newConsumer
  if consumerErrors~hasIndex(name) then consumerErrors~remove(name)
  fields = log~fields(.array~of("callId", callId, "consumer", name))
  event = log~emit("SIP.AUDIO.IN.CONSUMER.ATTACHED", fields)
  return previous
::method detachConsumer
  expose consumers consumerErrors log callId
  use strict arg name
  if \consumers~hasIndex(name) then return .nil
  previous = consumers[name]
  consumers~remove(name)
  if consumerErrors~hasIndex(name) then consumerErrors~remove(name)
  fields = log~fields(.array~of("callId", callId, "consumer", name))
  event = log~emit("SIP.AUDIO.IN.CONSUMER.DETACHED", fields)
  return previous
::method consumerNames
  expose consumers
  return consumers~allIndexes
::method consumerError
  expose consumerErrors
  use strict arg name
  if consumerErrors~hasIndex(name) then return consumerErrors[name]
  return ""
/* Compatibility attachment is the named DEFAULT consumer only. */
::method attach
  use strict arg newConsumer
  return self~attachConsumer("DEFAULT", newConsumer)
::method detach
  return self~detachConsumer("DEFAULT")
::method consumer
  expose consumers
  if consumers~hasIndex("DEFAULT") then return consumers["DEFAULT"]
  return .nil
::method start
  expose state log callId
  state = "RUNNING"
  fields = log~fields(.array~of("callId", callId, "state", state))
  event = log~emit("SIP.AUDIO.IN.STARTED", fields)
  return state
::method pause
  expose state log callId
  if state = "RUNNING" then state = "PAUSED"
  fields = log~fields(.array~of("callId", callId, "state", state))
  event = log~emit("SIP.AUDIO.IN.PAUSED", fields)
  return state
::method resume
  expose state log callId
  if state = "PAUSED" then state = "RUNNING"
  fields = log~fields(.array~of("callId", callId, "state", state))
  event = log~emit("SIP.AUDIO.IN.RESUMED", fields)
  return state
::method stop
  expose state log callId
  state = "STOPPED"
  fields = log~fields(.array~of("callId", callId, "state", state))
  event = log~emit("SIP.AUDIO.IN.STOPPED", fields)
  return state
::method receiveFrame
  expose state receiver consumers consumerErrors log callId
  use strict arg timeoutMilliseconds = 1000, maxSamples = 1600
  if state <> "RUNNING" then return .nil
  frame = receiver~receiveFrame(timeoutMilliseconds, maxSamples)
  if frame == .nil then return .nil
  names = consumers~allIndexes
  do name over names
    error = self~dispatchConsumer(consumers[name], frame)
    if error = "" then do
      if consumerErrors~hasIndex(name) then consumerErrors~remove(name)
    end
    else do
      consumerErrors[name] = error
      fields = log~fields(.array~of("callId", callId, "consumer", name, "error", error))
      event = log~emit("SIP.AUDIO.IN.CONSUMER.FAILED", fields)
    end
  end
  return frame
::method dispatchConsumer
  use strict arg consumer, frame
  signal on syntax name consumerFailure
  consumer~audioFrame(frame)
  signal off syntax
  return ""
consumerFailure:
  say "SIP inbound consumer failure rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  description = condition("D")
  if description = "" then description = condition("C")
  if description = "" then description = "SYNTAX"
  signal off syntax
  return description
::method receive
  use strict arg timeoutMilliseconds = 1000, maxSamples = 1600
  frame = self~receiveFrame(timeoutMilliseconds, maxSamples)
  if frame == .nil then return ""
  return frame~data

/* Application-facing outbound stream.  Producers are independent bindings.
   Exactly one producer is selected; this class never invents implicit mixing. */
::class SipOutboundAudio public
::method init
  expose callId sender state producers producerErrors activeProducer log objectId
  use strict arg callId, sender, logSink = .nil
  log = .SipLogEmitter~new(logSink, "sip.audio.out")
  objectId = log~objectId
  state = "CREATED"
  producers = .directory~new
  producerErrors = .directory~new
  activeProducer = ""
::attribute callId get
::attribute state get
::attribute sender get
::attribute objectId get
::method payloadType
  expose sender
  return sender~payloadType
::method remoteAddress
  expose sender
  return sender~remoteAddress
::method remoteRtpPort
  expose sender
  return sender~remotePort
::method attachProducer
  expose producers producerErrors activeProducer log callId
  use strict arg name, newProducer
  previous = .nil
  if producers~hasIndex(name) then previous = producers[name]
  producers[name] = newProducer
  if producerErrors~hasIndex(name) then producerErrors~remove(name)
  if activeProducer = "" then activeProducer = name
  fields = log~fields(.array~of("callId", callId, "producer", name, "activeProducer", activeProducer))
  event = log~emit("SIP.AUDIO.OUT.PRODUCER.ATTACHED", fields)
  return previous
::method detachProducer
  expose producers producerErrors activeProducer log callId
  use strict arg name
  if \producers~hasIndex(name) then return .nil
  previous = producers[name]
  producers~remove(name)
  if producerErrors~hasIndex(name) then producerErrors~remove(name)
  if activeProducer = name then activeProducer = ""
  fields = log~fields(.array~of("callId", callId, "producer", name, "activeProducer", activeProducer))
  event = log~emit("SIP.AUDIO.OUT.PRODUCER.DETACHED", fields)
  return previous
::method selectProducer
  expose producers activeProducer log callId
  use strict arg name
  if \producers~hasIndex(name) then raise syntax 98.900 array("producer not attached:" name)
  activeProducer = name
  fields = log~fields(.array~of("callId", callId, "producer", name))
  event = log~emit("SIP.AUDIO.OUT.PRODUCER.SELECTED", fields)
  return activeProducer
::method activeProducer
  expose activeProducer
  return activeProducer
::method producerNames
  expose producers
  return producers~allIndexes
::method producerError
  expose producerErrors
  use strict arg name
  if producerErrors~hasIndex(name) then return producerErrors[name]
  return ""
/* Compatibility attachment is the named DEFAULT producer only. */
::method attach
  use strict arg newProducer
  return self~attachProducer("DEFAULT", newProducer)
::method detach
  return self~detachProducer("DEFAULT")
::method producer
  expose producers activeProducer
  if activeProducer <> "", producers~hasIndex(activeProducer) then return producers[activeProducer]
  return .nil
::method start
  expose state log callId
  state = "RUNNING"
  fields = log~fields(.array~of("callId", callId, "state", state))
  event = log~emit("SIP.AUDIO.OUT.STARTED", fields)
  return state
::method pause
  expose state log callId
  if state = "RUNNING" then state = "PAUSED"
  fields = log~fields(.array~of("callId", callId, "state", state))
  event = log~emit("SIP.AUDIO.OUT.PAUSED", fields)
  return state
::method resume
  expose state log callId
  if state = "PAUSED" then state = "RUNNING"
  fields = log~fields(.array~of("callId", callId, "state", state))
  event = log~emit("SIP.AUDIO.OUT.RESUMED", fields)
  return state
::method stop
  expose state log callId
  state = "STOPPED"
  fields = log~fields(.array~of("callId", callId, "state", state))
  event = log~emit("SIP.AUDIO.OUT.STOPPED", fields)
  return state
::method sendFrame
  expose state sender
  use strict arg frame
  if state <> "RUNNING" then return .nil
  return sender~sendFrame(frame)
::method sendPcm
  expose sender
  use strict arg pcm
  frame = .RtpAudioFrame~new(pcm, 8000, 1, "S16LE", sender~payloadType, pcm~length % 2)
  sendResult = self~sendFrame(frame)
  if sendResult == .nil then return 0
  return sendResult~sampleCount
::method pumpProducer
  expose state producers producerErrors activeProducer log callId
  if state <> "RUNNING" then return .nil
  if activeProducer = "" then return .nil
  if \producers~hasIndex(activeProducer) then return .nil
  producer = producers[activeProducer]
  signal on syntax name producerFailure
  frame = producer~nextAudioFrame
  signal off syntax
  if frame == .nil then return .nil
  if producerErrors~hasIndex(activeProducer) then producerErrors~remove(activeProducer)
  return self~sendFrame(frame)
producerFailure:
  say "SIP outbound producer failure rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  description = condition("D")
  if description = "" then description = condition("C")
  if description = "" then description = "SYNTAX"
  producerErrors[activeProducer] = description
  fields = log~fields(.array~of("callId", callId, "producer", activeProducer, "error", description))
  event = log~emit("SIP.AUDIO.OUT.PRODUCER.FAILED", fields)
  signal off syntax
  return .nil

::class SipClient public
::method init
  expose transport bindAddress cseq log socketProvider
  use strict arg bindAddress="127.0.0.1", port=0, logSink=.nil, socketProvider=.nil
  log=.SipLogEmitter~new(logSink,"sip.client")
  if socketProvider=.nil then socketProvider=.SipSocketFactory~defaultProvider
  transport=.SipUdpTransport~new(bindAddress,port,logSink,socketProvider)
  cseq = 1
  fields = log~fields(.array~of("bindAddress", bindAddress, "port", transport~bindPort))
  event = log~emit("SIP.CLIENT.STARTED", fields)
::method port
  expose transport
  return transport~bindPort
::method register
  expose transport bindAddress cseq log
  use strict arg registrarUri, addressOfRecord, contactUri, username = "", password = "", expires = 3600, timeoutSeconds = 3
  target = sip_uri_target(registrarUri)
  host = target[1]
  port = target[2]
  callId = sip_random_token() || "@" || bindAddress
  branch = "z9hG4bK" || sip_random_token()~left(16)
  fromTag = sip_random_token()~left(16)
  request = self~registerRequest(registrarUri, addressOfRecord, contactUri, expires, callId, branch, fromTag, "")
  sent = transport~sendTo(request, host, port)
  response = transport~receive(timeoutSeconds)
  if response == .nil then return 0
  status = sip_message_status(response[1])
  fields = log~fields(.array~of("registrarUri", registrarUri, "addressOfRecord", addressOfRecord, "status", status, "cseq", cseq))
  event = log~emit("SIP.CLIENT.REGISTER.RESPONSE", fields)
  if status = 401 then do
    if username <> "" then do
    challenge = sip_message_header(response[1], "WWW-Authenticate")
    auth = sip_digest_authorization(challenge, username, password, "REGISTER", registrarUri)
    cseq += 1
    branch = "z9hG4bK" || sip_random_token()~left(16)
    request = self~registerRequest(registrarUri, addressOfRecord, contactUri, expires, callId, branch, fromTag, auth)
    sent = transport~sendTo(request, host, port)
    response = transport~receive(timeoutSeconds)
    if response == .nil then return 0
    status = sip_message_status(response[1])
    fields = log~fields(.array~of("registrarUri", registrarUri, "addressOfRecord", addressOfRecord, "status", status, "cseq", cseq, "authenticated", 1))
    event = log~emit("SIP.CLIENT.REGISTER.RESPONSE", fields)
    end
  end
  cseq += 1
  return status
::method registerRequest
  expose transport bindAddress cseq
  use strict arg registrarUri, addressOfRecord, contactUri, expires, callId, branch, fromTag, auth
  crlf = "0d0a"x
  request = "REGISTER" registrarUri "SIP/2.0" || crlf
  request ||= "Via: SIP/2.0/UDP" bindAddress || ":" || transport~bindPort || ";branch=" || branch || ";rport" || crlf
  request ||= "Max-Forwards: 70" || crlf
  request ||= "To: <" || addressOfRecord || ">" || crlf
  request ||= "From: <" || addressOfRecord || ">;tag=" || fromTag || crlf
  request ||= "Call-ID:" callId || crlf
  request ||= "CSeq:" cseq "REGISTER" || crlf
  request ||= "Contact: <" || contactUri || ">" || crlf
  request ||= "Expires:" expires || crlf
  request ||= "User-Agent: ooRexx-SIP/0.1-dev10" || crlf
  if auth <> "" then request ||= "Authorization:" auth || crlf
  request ||= "Content-Length: 0" || crlf || crlf
  return request
::method close
  expose transport log
  if transport <> .nil then do
    closed = transport~close
    transport = .nil
  end
  event = log~emit("SIP.CLIENT.STOPPED")
::method uninit
  expose transport
  if transport <> .nil then closed = transport~close

::requires "SocketProvider.cls"
::requires "RxSockUdpBinding.cls"
::requires "rtp.cls"
::requires "oorexx_sip" LIBRARY
