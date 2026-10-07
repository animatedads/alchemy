/* Optional QueueRexx / Queue Fabric publisher for durable SMTP spool refs.
 * Mirrors Storage Fabric's thin QueueRexx adapter style: SMTP does not own the
 * queue, channel, transport, ACL, or peer authority implementation.
 */
::class SmtpQueueContract public
::constant SECURITY_DOMAIN "SMTP.RELAY/1"
::constant REQUEST_QUEUE "SMTP.RELAY.REQUEST"

::class SmtpQueueRexxPublisher public
::method init
  expose channels requestAlias requestChannel principal
  use strict arg channelsArg,requestAliasArg,requestChannelArg,principalArg="smtp-service"
  channels=channelsArg; requestAlias=requestAliasArg~string; requestChannel=requestChannelArg~string; principal=principalArg~string
::method publish
  expose channels requestAlias requestChannel principal
  use strict arg spoolId,objectId,principalId
  req=.directory~new; req["schema"]="smtp.relay.request/1"; req["spool_id"]=spoolId; req["object_id"]=objectId; req["principal_id"]=principalId
  options=.table~new; options["persistent"]=.true; options["securityDomain"]=.SmtpQueueContract~SECURITY_DOMAIN; options["correlationId"]=spoolId
  r=channels~put(requestAlias,req,options,principal)
  if r==.nil | \r~ok then return .SmtpResult~failure("QUEUE_PUT_FAILED")
  r=channels~pump(requestChannel,0,principal)
  if r==.nil | \r~ok then return .SmtpResult~failure("QUEUE_PUMP_FAILED")
  return .SmtpResult~success(spoolId,"QUEUE_PUBLISHED")

::class SmtpQueueRexxBinding public
::method bindPublisher class
  use strict arg peerMesh,peerNodeId,clientId,principal="smtp-service",remoteRequestQueue=""
  if remoteRequestQueue="" then remoteRequestQueue=.SmtpQueueContract~REQUEST_QUEUE
  local="SMTP.RELAY.LOCAL."||clientId~string~translate
  route=peerMesh~bindServiceRoute(peerNodeId,"SMTP.RELAY."||clientId,local,remoteRequestQueue,.SmtpQueueContract~SECURITY_DOMAIN,principal)
  if route==.nil | \route~ok then return route
  d=route~value
  pub=.SmtpQueueRexxPublisher~new(peerMesh~channels,d["remote_alias"],d["sender_channel"],principal)
  return .SmtpResult~success(pub,"QUEUE_BOUND")

::requires "SmtpCore.cls"
