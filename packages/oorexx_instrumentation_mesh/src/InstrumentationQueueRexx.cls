/* InstrumentationQueueRexx.cls
 * QueueRexx / Queue Fabric service-route binding for instrumentation.mesh/0.1.
 *
 * This is deliberately duck-typed against QueueRexxPeerMeshRuntime, matching
 * the existing StoragePeerQueueRexxBinding pattern.  It creates no sockets and
 * no trust relationship.  Queue/XTP owns transport authentication; the local
 * InstrumentationService owns query/command semantics and authority checks.
 */

::class InstrumentationQueueRexxBinding public
::method bindClient class
  use strict arg peerMesh,peerNodeId,clientId,principal="instrumentation-client",remoteRequestQueue="INSTRUMENTATION.REQUEST",timeoutMs=10000
  localReply="INSTRUMENTATION.REPLY."||clientId~string~translate
  route=peerMesh~bindServiceRoute(peerNodeId,"INSTRUMENTATION.REQUEST."||clientId,localReply,remoteRequestQueue,.InstrumentationContract~SECURITY_DOMAIN,principal)
  if route==.nil | \route~ok then return route
  ignore=peerMesh~queueManager~grant(localReply,principal,"GET",peerMesh~adminPrincipal)
  d=route~value
  transport=.InstrumentationQueueRexxClientTransport~new(peerMesh,d["remote_alias"],d["sender_channel"],localReply,principal,timeoutMs)
  return .InstrumentationQueueRexxBindingResult~success(transport,d)

::method bindServer class
  use strict arg peerMesh,peerNodeId,clientId,service,servicePrincipal="instrumentation-service",remoteReplyQueue="INSTRUMENTATION.REPLY."
  requestQueue="INSTRUMENTATION.REQUEST"
  remoteReply=remoteReplyQueue||clientId~string~translate
  route=peerMesh~bindServiceRoute(peerNodeId,"INSTRUMENTATION.REPLY."||clientId,requestQueue,remoteReply,.InstrumentationContract~SECURITY_DOMAIN,servicePrincipal)
  if route==.nil | \route~ok then return route
  ignore=peerMesh~queueManager~grant(requestQueue,servicePrincipal,"GET",peerMesh~adminPrincipal)
  d=route~value
  server=.InstrumentationQueueRexxServer~new(peerMesh,peerNodeId,service,requestQueue,d["remote_alias"],d["sender_channel"],servicePrincipal)
  return .InstrumentationQueueRexxBindingResult~success(server,d)

::class InstrumentationQueueRexxBindingResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::attribute route get
::method init
  expose ok code detail value route
  use strict arg okArg,codeArg,detailArg,valueArg=.nil,routeArg=.nil
  ok=(okArg==.true); code=codeArg~string; detail=detailArg~string; value=valueArg; route=routeArg
::method success class
  use strict arg valueArg,routeArg=.nil
  return self~new(.true,"OK","",valueArg,routeArg)
::method failure class
  use strict arg codeArg,detailArg=""
  return self~new(.false,codeArg,detailArg)

::class InstrumentationQueueRexxClientTransport public
::method init
  expose peerMesh channels manager requestAlias requestChannel replyQueue listener admin localPrincipal timeoutMs
  use strict arg peerMeshArg,requestAliasArg,requestChannelArg,replyQueueArg,principalArg,timeoutArg=10000
  peerMesh=peerMeshArg; channels=peerMesh~channels; manager=peerMesh~queueManager; listener=peerMesh~listener; admin=peerMesh~adminPrincipal
  requestAlias=requestAliasArg~string; requestChannel=requestChannelArg~string; replyQueue=replyQueueArg~string; localPrincipal=principalArg~string
  timeoutMs=timeoutArg
  if \datatype(timeoutMs,"W") | timeoutMs<1 then raise syntax 88.900 array("Instrumentation QueueRexx timeout must be a positive whole number")

::method request
  expose channels manager requestAlias requestChannel replyQueue listener admin localPrincipal timeoutMs
  use strict arg peerNodeId,payload
  if listener<>.nil then do
    if \listener~start then return .nil
    activity=.InstrumentationServeOneActivity~new(listener); ignore=activity~run
  end
  correlation=self~correlationId(payload)
  options=.table~new; options["persistent"]=.true; options["securityDomain"]=.InstrumentationContract~SECURITY_DOMAIN; options["correlationId"]=correlation
  r=channels~put(requestAlias,payload,options,localPrincipal); if \r~ok then return .nil
  r=channels~pump(requestChannel,0,admin); if \r~ok then return .nil
  loops=timeoutMs%25; if loops<1 then loops=1
  do i=1 to loops
    got=self~dequeueReply(i)
    if got~ok then return got~value~payload
    if got~code<>"QUEUE_EMPTY" then return .nil
    call SysSleep 0.025
  end
  return .nil

::method dequeueReply
  expose manager replyQueue localPrincipal
  use strict arg pollSequence
  if pollSequence<1 then return .nil
  return manager~get(replyQueue,localPrincipal)

::method correlationId
  use strict arg payload
  schema=.InstrumentationCodec~value(payload,"schema","")
  if schema=.InstrumentationContract~QUERY_SCHEMA then return .InstrumentationCodec~value(payload,"request_id","")
  if schema=.InstrumentationContract~COMMAND_SCHEMA then return .InstrumentationCodec~value(payload,"command_id","")
  if schema=.InstrumentationContract~PUBLICATION_SCHEMA then return .InstrumentationCodec~value(payload,"publication_id","")
  return ""

::class InstrumentationServeOneActivity public
::method init
  expose listener
  use strict arg listenerArg
  listener=listenerArg
::method run
  expose listener
  reply .true
  ignore=listener~serveOne
  return

::class InstrumentationQueueRexxServer public
::method init
  expose peerMesh service expectedPeerNodeId requestQueue replyAlias replyChannel servicePrincipal manager channels admin
  use strict arg peerMeshArg,expectedPeerArg,serviceArg,requestQueueArg,replyAliasArg,replyChannelArg,principalArg
  peerMesh=peerMeshArg; expectedPeerNodeId=expectedPeerArg~string~strip; service=serviceArg; requestQueue=requestQueueArg~string; replyAlias=replyAliasArg~string; replyChannel=replyChannelArg~string; servicePrincipal=principalArg~string
  if expectedPeerNodeId="" then raise syntax 88.900 array("Instrumentation QueueRexx server requires authenticated peer identity")
  manager=peerMesh~queueManager; channels=peerMesh~channels; admin=peerMesh~adminPrincipal

::method processOne
  expose service expectedPeerNodeId requestQueue replyAlias replyChannel servicePrincipal manager channels admin
  got=manager~get(requestQueue,servicePrincipal)
  if \got~ok then return .InstrumentationQueueRexxBindingResult~failure(got~code,got~detail)
  response=service~handleFrom(expectedPeerNodeId,got~value~payload)
  options=.table~new; options["persistent"]=.true; options["securityDomain"]=.InstrumentationContract~SECURITY_DOMAIN; options["correlationId"]=self~correlationId(response)
  r=channels~put(replyAlias,response,options,servicePrincipal); if \r~ok then return .InstrumentationQueueRexxBindingResult~failure(r~code,r~detail)
  r=channels~pump(replyChannel,0,admin); if \r~ok then return .InstrumentationQueueRexxBindingResult~failure(r~code,r~detail)
  return .InstrumentationQueueRexxBindingResult~success(response)

::method correlationId
  use strict arg payload
  requestId=.InstrumentationCodec~value(payload,"request_id","")
  if requestId<>"" then return requestId
  commandId=.InstrumentationCodec~value(payload,"command_id","")
  if commandId<>"" then return commandId
  return .InstrumentationCodec~value(payload,"publication_id","")

::requires "InstrumentationMesh.cls"
