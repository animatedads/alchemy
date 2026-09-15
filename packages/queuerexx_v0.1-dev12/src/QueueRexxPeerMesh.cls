/* QueueRexxPeerMesh.cls - QueueRexx v0.1-dev12 peer authority mesh.
 *
 * QueueRexx-to-QueueRexx authenticated control plane carried by Queue Fabric.
 * This is deliberately not a placement authority and not a second queue.
 * Each node keeps its own QueueRexx/Job-to-Node/WLU authority; the mesh
 * transports typed approval/check requests and durable evidence between peers.
 *
 * Queue Fabric v0.9-dev5 queue.transport/2 currently authenticates one TCP
 * session per delivery.  QueueRexx therefore keeps a durable logical peer link
 * (permanent queues/channels/trust/routes) and reconnects transparently for
 * physical delivery.  Persistent multiplexed TCP, if later wanted, belongs in
 * Queue Fabric rather than this control plane.
 */

::class QueueRexxPeerMeshContract public
::constant API "queuerexx.peer.mesh/0.1"
::constant REQUEST_SCHEMA "queuerexx.peer.mesh.request/1"
::constant RESPONSE_SCHEMA "queuerexx.peer.mesh.response/1"
::constant LEDGER_SCHEMA "queuerexx.peer.mesh-ledger/1"
::constant SECURITY_DOMAIN "QUEUEREXX-PEER-MESH"

::class QueueRexxPeerOperation public
::constant AUTHORIZE "AUTHORIZE"
::constant JOB_CHECK "JOB_CHECK"
::constant LOAD_CHECK "LOAD_CHECK"
::constant POLICY_CHECK "POLICY_CHECK"
::constant PLACEMENT_CHECK "PLACEMENT_CHECK"
::constant MIGRATION_CHECK "MIGRATION_CHECK"
::constant HEALTH "HEALTH"

::class QueueRexxPeerDecisionCode public
::constant APPROVE "APPROVE"
::constant DENY "DENY"
::constant ABSTAIN "ABSTAIN"
::constant ERROR "ERROR"
::method valid class
  use strict arg value
  v=value~string~upper
  return v=self~APPROVE | v=self~DENY | v=self~ABSTAIN | v=self~ERROR

::class QueueRexxPeerDecisionMode public
::constant ANY "ANY"
::constant QUORUM "QUORUM"
::constant ALL_AVAILABLE "ALL_AVAILABLE"
::constant REQUIRED "REQUIRED"

::class QueueRexxPeerLocalDecision public
::attribute decision get
::attribute code get
::attribute detail get
::attribute evidence get
::method init
  expose decision code detail evidence
  use strict arg decisionArg, codeArg="", detailArg="", evidenceArg=.nil
  decision=decisionArg~string~upper
  if \.QueueRexxPeerDecisionCode~valid(decision) then raise syntax 88.900 array("invalid peer decision")
  code=codeArg~string; detail=detailArg~string
  if evidenceArg==.nil then evidence=.directory~new; else evidence=evidenceArg

::class QueueRexxPeerStaticDecisionHandler public
::method init
  expose localDecision
  use strict arg decisionArg="APPROVE", codeArg="STATIC", detailArg="", evidenceArg=.nil
  localDecision=.QueueRexxPeerLocalDecision~new(decisionArg,codeArg,detailArg,evidenceArg)
::method evaluate
  expose localDecision
  use strict arg request
  return localDecision

::class QueueRexxPeerHealthHandler public
::method init
  expose nodeId provider
  use strict arg nodeArg, providerArg=.nil
  nodeId=nodeArg~string; provider=providerArg
::method evaluate
  expose nodeId provider
  use strict arg request
  e=.directory~new; e["node_id"]=nodeId; e["status"]="AVAILABLE"; e["observed_at"]=.DateTime~new~string
  if provider<>.nil then do
    signal on syntax name healthProviderFailed
    if provider~hasMethod("PEERHEALTH") then do
      extra=provider~peerHealth
      if extra<>.nil then e["provider"]=extra
    end
    signal off syntax
  end
  return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~APPROVE,"HEALTH_OK","peer mesh service available",e)
healthProviderFailed:
  signal off syntax
  return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~ERROR,"HEALTH_PROVIDER_FAILED","local health provider raised a condition",e)

::class QueueRexxPeerMeshCodec public
::method value class
  use strict arg d, key, defaultValue=""
  if d==.nil then return defaultValue
  v=d[key]
  if v==.nil then return defaultValue
  return v
::method number class
  use strict arg d, key, defaultValue=0
  v=self~value(d,key,defaultValue)
  if \datatype(v,"N") then return defaultValue+0
  return v+0

::method newRequest class
  use strict arg requestId, fromNode, toNode, operation, subject=.nil, context=.nil, createdEpochMs=0, expiresEpochMs=0, policyRef=""
  d=.directory~new
  d["schema"]=.QueueRexxPeerMeshContract~REQUEST_SCHEMA
  d["api"]=.QueueRexxPeerMeshContract~API
  d["request_id"]=requestId~string
  d["from_node"]=fromNode~string
  d["to_node"]=toNode~string
  d["operation"]=operation~string~upper
  d["created_epoch_ms"]=createdEpochMs+0
  d["expires_epoch_ms"]=expiresEpochMs+0
  d["policy_ref"]=policyRef~string
  if subject==.nil then d["subject"]=.directory~new; else d["subject"]=subject
  if context==.nil then d["context"]=.directory~new; else d["context"]=context
  return d

::method newResponse class
  use strict arg request, sourceNode, decisionArg, codeArg="", detailArg="", evidenceArg=.nil, replayedArg=.false
  d=.directory~new
  d["schema"]=.QueueRexxPeerMeshContract~RESPONSE_SCHEMA
  d["api"]=.QueueRexxPeerMeshContract~API
  d["request_id"]=self~value(request,"request_id","")
  d["from_node"]=self~value(request,"from_node","")
  d["to_node"]=self~value(request,"to_node","")
  d["source_node"]=sourceNode~string
  d["operation"]=self~value(request,"operation","")
  d["decision"]=decisionArg~string~upper
  d["code"]=codeArg~string
  d["detail"]=detailArg~string
  if evidenceArg==.nil then d["evidence"]=.directory~new; else d["evidence"]=evidenceArg
  if replayedArg then d["replayed"]="1"; else d["replayed"]="0"
  return d

::method requestCanonical class
  use strict arg request
  return "api="||self~value(request,"api","")||";id="||self~scalar(self~value(request,"request_id",""))||";from="||self~scalar(self~value(request,"from_node",""))||";to="||self~scalar(self~value(request,"to_node",""))||";op="||self~scalar(self~value(request,"operation",""))||";created="||self~number(request,"created_epoch_ms",0)||";expires="||self~number(request,"expires_epoch_ms",0)||";policy="||self~scalar(self~value(request,"policy_ref",""))||";subject="||self~canonicalValue(request["subject"])||";context="||self~canonicalValue(request["context"])

::method canonicalValue class
  use strict arg value
  if value==.nil then return "N"
  if value~isA(.Directory) | value~isA(.Table) then do
    keys=.array~new
    s=value~supplier
    do while s~available
      keys~append(s~index~string)
      s~next
    end
    keys~sort
    out="M["
    do key over keys
      out||=self~scalar(key)||"="||self~canonicalValue(value[key])||";"
    end
    return out||"]"
  end
  if value~isA(.Array) then do
    out="A["
    do item over value; out||=self~canonicalValue(item)||";"; end
    return out||"]"
  end
  return "S"||self~scalar(value~string)

::method scalar class private
  use strict arg text
  s=text~string
  return s~length||":"||c2x(s)

/* ------------------------------------------------------------------ */
/* Durable idempotency ledger.  A request claim is committed before   */
/* invoking the local evaluator.  A replay returns the exact response. */
/* ------------------------------------------------------------------ */
::class QueueRexxPeerLedgerStatus public
::constant NEW "NEW"
::constant REPLAY "REPLAY"
::constant INCOMPLETE "INCOMPLETE"
::constant CONFLICT "CONFLICT"
::constant UNAVAILABLE "UNAVAILABLE"

::class QueueRexxPeerMeshRequestLedger public
::attribute path get
::attribute ready get
::attribute code get
::method init
  expose path ready code entries digestProvider codec
  use strict arg pathArg, digestArg=.nil, codecArg=.nil
  path=pathArg~string; entries=.directory~new
  if digestArg==.nil then digestProvider=.QueueDigestProvider~new; else digestProvider=digestArg
  if codecArg==.nil then codec=.QueueGraphPayloadCodec~new; else codec=codecArg
  ready=.false; code="UNINITIALIZED"
  ignore=self~load

::method load private
  expose path ready code entries digestProvider codec
  entries=.directory~new
  if stream(path,"C","QUERY EXISTS")="" then do; ready=.true; code="READY"; return .true; end
  s=.stream~new(path); opened=s~open("READ")
  if opened<>"READY:" then do; ready=.false; code="LEDGER_OPEN_FAILED"; return .false; end
  lineNo=0
  do while s~lines>0
    line=s~lineIn; lineNo+=1
    if line="" then iterate
    parts=self~split(line)
    if parts~items<6 | parts[1]<>"QRXPEER1" then do; s~close; ready=.false; code="LEDGER_FORMAT_INVALID:"||lineNo; return .false; end
    material=""
    do i=1 to parts~items-1
      if i>1 then material||="|"
      material||=parts[i]
    end
    expected=x2c(parts[parts~items])
    if digestProvider~digest(material)<>expected then do; s~close; ready=.false; code="LEDGER_DIGEST_INVALID:"||lineNo; return .false; end
    kind=parts[2]; requestId=x2c(parts[3]); requestDigest=x2c(parts[4])
    e=entries[requestId]
    if kind="CLAIM" then do
      if parts~items<>8 then do; s~close; ready=.false; code="LEDGER_CLAIM_FORMAT_INVALID:"||lineNo; return .false; end
      if e<>.nil then do
        if e["request_digest"]<>requestDigest then do; s~close; ready=.false; code="LEDGER_REQUEST_ID_CONFLICT:"||lineNo; return .false; end
      end
      else do
        e=.directory~new; e["state"]="CLAIMED"; e["request_digest"]=requestDigest; e["operation"]=x2c(parts[5]); e["request_encoded"]=x2c(parts[6]); e["claimed_at"]=x2c(parts[7]); entries[requestId]=e
      end
    end
    else if kind="COMPLETE" then do
      if parts~items<>7 then do; s~close; ready=.false; code="LEDGER_COMPLETE_FORMAT_INVALID:"||lineNo; return .false; end
      if e==.nil | e["request_digest"]<>requestDigest then do; s~close; ready=.false; code="LEDGER_COMPLETE_WITHOUT_CLAIM:"||lineNo; return .false; end
      e["state"]="COMPLETE"; e["response_encoded"]=x2c(parts[5]); e["completed_at"]=x2c(parts[6])
    end
    else do; s~close; ready=.false; code="LEDGER_RECORD_UNKNOWN:"||lineNo; return .false; end
  end
  s~close; ready=.true; code="READY"; return .true

::method claim guarded
  expose ready entries codec digestProvider
  use strict arg request
  out=.directory~new
  if \ready then do; out["status"]=.QueueRexxPeerLedgerStatus~UNAVAILABLE; return out; end
  requestId=.QueueRexxPeerMeshCodec~value(request,"request_id","")
  requestDigest=digestProvider~digest(.QueueRexxPeerMeshCodec~requestCanonical(request))
  out["request_digest"]=requestDigest
  e=entries[requestId]
  if e<>.nil then do
    if e["request_digest"]<>requestDigest then do; out["status"]=.QueueRexxPeerLedgerStatus~CONFLICT; return out; end
    if e["state"]="COMPLETE" then do; out["status"]=.QueueRexxPeerLedgerStatus~REPLAY; out["response"]=codec~decode(e["response_encoded"]); return out; end
    out["status"]=.QueueRexxPeerLedgerStatus~INCOMPLETE; out["stored_request"]=codec~decode(e["request_encoded"]); return out
  end
  encoded=codec~encode(request); op=.QueueRexxPeerMeshCodec~value(request,"operation",""); stamp=.DateTime~new~string
  if \self~appendClaim(requestId,requestDigest,op,encoded,stamp) then do; out["status"]=.QueueRexxPeerLedgerStatus~UNAVAILABLE; return out; end
  e=.directory~new; e["state"]="CLAIMED"; e["request_digest"]=requestDigest; e["operation"]=op; e["request_encoded"]=encoded; e["claimed_at"]=stamp; entries[requestId]=e
  out["status"]=.QueueRexxPeerLedgerStatus~NEW
  return out

::method complete guarded
  expose ready entries codec
  use strict arg request, response
  if \ready then return .false
  requestId=.QueueRexxPeerMeshCodec~value(request,"request_id",""); e=entries[requestId]
  if e==.nil then return .false
  encoded=codec~encode(response); stamp=.DateTime~new~string
  if \self~appendComplete(requestId,e["request_digest"],encoded,stamp) then return .false
  e["state"]="COMPLETE"; e["response_encoded"]=encoded; e["completed_at"]=stamp
  return .true

::method appendClaim private
  expose digestProvider
  use strict arg requestId, requestDigest, operation, encoded, stamp
  material="QRXPEER1|CLAIM|"||c2x(requestId)||"|"||c2x(requestDigest)||"|"||c2x(operation)||"|"||c2x(encoded)||"|"||c2x(stamp)
  return self~writeLine(material||"|"||c2x(digestProvider~digest(material)))
::method appendComplete private
  expose digestProvider
  use strict arg requestId, requestDigest, encoded, stamp
  material="QRXPEER1|COMPLETE|"||c2x(requestId)||"|"||c2x(requestDigest)||"|"||c2x(encoded)||"|"||c2x(stamp)
  return self~writeLine(material||"|"||c2x(digestProvider~digest(material)))
::method writeLine private
  expose path
  use strict arg line
  s=.stream~new(path); opened=s~open("WRITE APPEND")
  if opened<>"READY:" then return .false
  s~lineOut(line); s~close; return .true
::method split private
  use strict arg text
  out=.array~new; rest=text
  do forever
    p=pos("|",rest)
    if p=0 then do; out~append(rest); leave; end
    out~append(left(rest,p-1)); rest=substr(rest,p+1)
  end
  return out

/* ------------------------------------------------------------------ */
/* Peer ACL / route binding.  Reply destinations are administrator     */
/* supplied; never accepted from the request payload.                   */
/* ------------------------------------------------------------------ */
::class QueueRexxPeerBinding public
::attribute peerNodeId get
::attribute peerManager get
::attribute transportPrincipal get
::attribute requestQueue get
::attribute replyAlias get
::method init
  expose peerNodeId peerManager transportPrincipal requestQueue replyAlias allowed
  use strict arg peerArg, managerArg, principalArg, requestQueueArg, replyAliasArg, operationsArg
  peerNodeId=peerArg~string; peerManager=managerArg~string; transportPrincipal=principalArg~string; requestQueue=requestQueueArg~string; replyAlias=replyAliasArg~string
  allowed=.table~new; do op over operationsArg; allowed[op~string~upper]=.true; end
::method allows
  expose allowed
  use strict arg operation
  return allowed~hasIndex(operation~string~upper)

::class QueueRexxPeerTrustPolicy public
::method init
  expose bindings
  bindings=.directory~new
::method bindPeer
  expose bindings
  use strict arg peerNodeId, peerManager, transportPrincipal, requestQueue, replyAlias, operations
  b=.QueueRexxPeerBinding~new(peerNodeId,peerManager,transportPrincipal,requestQueue,replyAlias,operations); bindings[peerNodeId~string]=b; return b
::method binding
  expose bindings
  use strict arg peerNodeId
  return bindings[peerNodeId~string]
::method peers
  expose bindings
  out=.array~new; do k over bindings; out~append(bindings[k]); end; return out

/* ------------------------------------------------------------------ */
/* Local peer request service.                                         */
/* ------------------------------------------------------------------ */
::class QueueRexxPeerMeshService public
::attribute localNodeId get
::attribute trustPolicy get
::attribute ledger get
::method init
  expose localNodeId trustPolicy ledger channels manager adminPrincipal handlers nowProvider
  use strict arg localNodeArg, trustArg, ledgerArg, channelFabricArg, adminArg="queue-admin", nowProviderArg=.nil
  localNodeId=localNodeArg~string; trustPolicy=trustArg; ledger=ledgerArg; channels=channelFabricArg; manager=channels~queueManager; adminPrincipal=adminArg~string; nowProvider=nowProviderArg
  handlers=.directory~new
  if localNodeId="" | trustPolicy==.nil | ledger==.nil | channels==.nil then raise syntax 88.900 array("peer mesh service collaborators required")
  handlers[.QueueRexxPeerOperation~HEALTH]=.QueueRexxPeerHealthHandler~new(localNodeId)

::method registerHandler
  expose handlers
  use strict arg operation, handler
  if operation~string~strip="" | handler==.nil | \handler~hasMethod("EVALUATE") then return .false
  handlers[operation~string~upper]=handler; return .true
::method handler
  expose handlers
  use strict arg operation
  return handlers[operation~string~upper]

::method servePeer
  expose trustPolicy ledger manager adminPrincipal
  use strict arg peerNodeId, maxMessages=1
  b=trustPolicy~binding(peerNodeId)
  if b==.nil then return .QueueOperationResult~failure("PEER_NOT_BOUND",peerNodeId)
  if \ledger~ready then return .QueueOperationResult~failure("PEER_LEDGER_UNAVAILABLE",ledger~code)
  served=0
  do while maxMessages=0 | served<maxMessages
    claim=manager~claim(b~requestQueue,adminPrincipal)
    if \claim~ok then do
      if claim~code="QUEUE_EMPTY" then leave
      return .QueueOperationResult~failure("PEER_REQUEST_CLAIM_FAILED",claim~code||":"||claim~detail)
    end
    package=claim~value; request=package~payload; response=self~handleBoundRequest(b,request)
    send=self~queueResponse(b,response)
    if \send~ok then do
      ignore=manager~release(b~requestQueue,package~packageId,package~claimToken,adminPrincipal,"peer reply enqueue failed:"||send~code)
      return send
    end
    ack=manager~ack(b~requestQueue,package~packageId,package~claimToken,adminPrincipal)
    if \ack~ok then return .QueueOperationResult~failure("PEER_REQUEST_ACK_FAILED",ack~code)
    served+=1
  end
  return .QueueOperationResult~success(.nil,"served="||served)

::method handleBoundRequest private
  expose ledger localNodeId
  use strict arg binding, request
  invalid=self~validateRequest(binding,request)
  if invalid<>.nil then return invalid
  claimed=ledger~claim(request); status=claimed["status"]
  if status=.QueueRexxPeerLedgerStatus~CONFLICT then do
    response=.QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"REQUEST_ID_CONFLICT","same request id reused with different peer request")
    response["request_digest"]=claimed["request_digest"]
    return response
  end
  if status=.QueueRexxPeerLedgerStatus~UNAVAILABLE then return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"PEER_LEDGER_UNAVAILABLE",ledger~code)
  if status=.QueueRexxPeerLedgerStatus~REPLAY then do; r=claimed["response"]; r["replayed"]="1"; return r; end
  if status=.QueueRexxPeerLedgerStatus~INCOMPLETE then response=.QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"REQUEST_INCOMPLETE_AFTER_RESTART","peer evaluator outcome was not durably completed; requester must retry under governing policy")
  else response=self~dispatch(request)
  response["request_digest"]=claimed["request_digest"]
  if \ledger~complete(request,response) then do
    failed=.QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"PEER_LEDGER_COMPLETE_FAILED","local decision may have occurred but exact replay completion failed")
    failed["request_digest"]=claimed["request_digest"]
    return failed
  end
  return response

::method validateRequest private
  expose localNodeId handlers
  use strict arg binding, request
  empty=.directory~new
  if request==.nil | \request~isA(.Directory) then return .QueueRexxPeerMeshCodec~newResponse(empty,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"REQUEST_INVALID","Directory request required")
  if .QueueRexxPeerMeshCodec~value(request,"schema","")<>.QueueRexxPeerMeshContract~REQUEST_SCHEMA then return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"REQUEST_SCHEMA_INVALID")
  if .QueueRexxPeerMeshCodec~value(request,"api","")<>.QueueRexxPeerMeshContract~API then return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"API_MISMATCH")
  if .QueueRexxPeerMeshCodec~value(request,"request_id","")="" then return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"REQUEST_ID_REQUIRED")
  if .QueueRexxPeerMeshCodec~value(request,"from_node","")<>binding~peerNodeId then return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"PEER_ID_MISMATCH")
  if .QueueRexxPeerMeshCodec~value(request,"to_node","")<>localNodeId then return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"DESTINATION_NODE_MISMATCH")
  op=.QueueRexxPeerMeshCodec~value(request,"operation","")~upper
  if op="" then return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"OPERATION_REQUIRED")
  if \binding~allows(op) then return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~DENY,"PEER_OPERATION_DENIED",op)
  if handlers[op]==.nil then return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"OPERATION_HANDLER_UNAVAILABLE",op)
  expires=.QueueRexxPeerMeshCodec~number(request,"expires_epoch_ms",0)
  if expires>0 then do
    now=self~nowEpochMs
    if now>expires then return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~DENY,"REQUEST_EXPIRED","peer request expired before evaluation")
  end
  return .nil

::method dispatch private
  expose localNodeId handlers
  use strict arg request
  op=.QueueRexxPeerMeshCodec~value(request,"operation","")~upper; h=handlers[op]
  signal on syntax name handlerFailed
  decision=h~evaluate(request)
  signal off syntax
  if decision==.nil | \decision~isA(.QueueRexxPeerLocalDecision) then return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"HANDLER_RESULT_INVALID")
  return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,decision~decision,decision~code,decision~detail,decision~evidence)
handlerFailed:
  signal off syntax
  return .QueueRexxPeerMeshCodec~newResponse(request,localNodeId,.QueueRexxPeerDecisionCode~ERROR,"HANDLER_FAILED","local peer evaluator raised a condition")

::method nowEpochMs private
  expose nowProvider
  if nowProvider<>.nil then do
    if nowProvider~hasMethod("NOWEPOCHMS") then return nowProvider~nowEpochMs
  end
  return (.DateTime~new~timeT*1000)

::method queueResponse private
  expose channels adminPrincipal
  use strict arg binding, response
  options=.table~new; options["persistent"]=.true; options["securityDomain"]=.QueueRexxPeerMeshContract~SECURITY_DOMAIN; options["correlationId"]=.QueueRexxPeerMeshCodec~value(response,"request_id","")
  put=channels~put(binding~replyAlias,response,options,adminPrincipal)
  if \put~ok then return .QueueOperationResult~failure("PEER_REPLY_QUEUE_FAILED",put~code||":"||put~detail)
  d=channels~remoteQueue(binding~replyAlias)
  if d<>.nil then ignore=channels~pump(d~channelName,0,adminPrincipal)
  return .QueueOperationResult~success(response)

/* ------------------------------------------------------------------ */
/* Peer client and multi-peer decision policy.                         */
/* ------------------------------------------------------------------ */
::class QueueRexxPeerRequestIdGenerator public
::method init
  expose prefix
  use strict arg prefixArg="qrx-peer"
  prefix=prefixArg~string
::method next
  expose prefix
  d=.DateTime~new
  stamp=d~standardDate||"_"||d~longTime~changestr(":","")~changestr(".","")
  return prefix||"-"||stamp||"-"||random(0,999999)~right(6,"0")

::class QueueRexxPeerQueueFabricRequestExecutor public
::method init
  expose channels manager requestAlias requestChannel replyQueue listener adminPrincipal localPrincipal timeoutMs
  use strict arg channelFabricArg, requestAliasArg, requestChannelArg, replyQueueArg, listenerArg=.nil, adminArg="queue-admin", localPrincipalArg="queue-peer", timeoutArg=10000
  channels=channelFabricArg; manager=channels~queueManager; requestAlias=requestAliasArg~string; requestChannel=requestChannelArg~string; replyQueue=replyQueueArg~string; listener=listenerArg; adminPrincipal=adminArg~string; localPrincipal=localPrincipalArg~string; timeoutMs=timeoutArg+0
::method call
  expose channels manager requestAlias requestChannel replyQueue listener adminPrincipal localPrincipal timeoutMs
  use strict arg request
  if listener<>.nil then do
    if \listener~start then return .QueueOperationResult~failure("PEER_LISTENER_START_FAILED",listener~lastError)
    a=.QueueRexxPeerServeOneActivity~new(listener); ignore=a~run
  end
  options=.table~new; options["persistent"]=.true; options["securityDomain"]=.QueueRexxPeerMeshContract~SECURITY_DOMAIN; options["correlationId"]=.QueueRexxPeerMeshCodec~value(request,"request_id","")
  put=channels~put(requestAlias,request,options,localPrincipal)
  if \put~ok then return .QueueOperationResult~failure("PEER_REQUEST_ENQUEUE_FAILED",put~code||":"||put~detail)
  pump=channels~pump(requestChannel,0,adminPrincipal)
  if \pump~ok then return .QueueOperationResult~failure("PEER_REQUEST_DELIVERY_FAILED",pump~code||":"||pump~detail)
  loops=timeoutMs%25; if loops<1 then loops=1; expected=.QueueRexxPeerMeshCodec~value(request,"request_id","")
  do i=1 to loops
    got=manager~get(replyQueue,localPrincipal)
    if got~ok then do
      response=got~value~payload
      if .QueueRexxPeerMeshCodec~value(response,"request_id","")<>expected then return .QueueOperationResult~failure("PEER_REPLY_REQUEST_ID_MISMATCH")
      return .QueueOperationResult~success(response)
    end
    if got~code<>"QUEUE_EMPTY" then return .QueueOperationResult~failure("PEER_REPLY_READ_FAILED",got~code||":"||got~detail)
    call SysSleep 0.025
  end
  return .QueueOperationResult~failure("PEER_REPLY_TIMEOUT",expected)

::class QueueRexxPeerServeOneActivity public
::method init
  expose listener
  use strict arg listenerArg
  listener=listenerArg
::method run
  expose listener
  reply .true
  ignore=listener~serveOne
  return

::class QueueRexxPeerRoute public
::attribute peerNodeId get
::attribute executor get
::method init
  expose peerNodeId executor
  use strict arg peerArg, executorArg
  peerNodeId=peerArg~string; executor=executorArg

::class QueueRexxPeerMeshClient public
::attribute localNodeId get
::method init
  expose localNodeId routes idGenerator
  use strict arg localNodeArg
  localNodeId=localNodeArg~string; routes=.directory~new; idGenerator=.QueueRexxPeerRequestIdGenerator~new("qrx-peer-"||localNodeId)
::method addRoute
  expose routes
  use strict arg peerNodeId, executor
  routes[peerNodeId~string]=.QueueRexxPeerRoute~new(peerNodeId,executor); return routes[peerNodeId~string]
::method route
  expose routes
  use strict arg peerNodeId
  return routes[peerNodeId~string]
::method peers
  expose routes
  out=.array~new; do k over routes; out~append(k); end; out~sort; return out
::method request
  expose routes localNodeId idGenerator
  use strict arg peerNodeId, operation, subject=.nil, context=.nil, createdEpochMs=0, expiresEpochMs=0, policyRef="", requestId=""
  r=routes[peerNodeId~string]
  if r==.nil then return .QueueOperationResult~failure("PEER_ROUTE_NOT_FOUND",peerNodeId)
  if requestId="" then requestId=idGenerator~next
  request=.QueueRexxPeerMeshCodec~newRequest(requestId,localNodeId,peerNodeId,operation,subject,context,createdEpochMs,expiresEpochMs,policyRef)
  rr=r~executor~call(request)
  if rr==.nil | \rr~ok then return rr
  response=rr~value
  if response==.nil | \response~isA(.Directory) then return .QueueOperationResult~failure("PEER_RESPONSE_INVALID")
  if .QueueRexxPeerMeshCodec~value(response,"schema","")<>.QueueRexxPeerMeshContract~RESPONSE_SCHEMA | .QueueRexxPeerMeshCodec~value(response,"api","")<>.QueueRexxPeerMeshContract~API then return .QueueOperationResult~failure("PEER_RESPONSE_CONTRACT_MISMATCH")
  if .QueueRexxPeerMeshCodec~value(response,"request_id","")<>requestId then return .QueueOperationResult~failure("PEER_RESPONSE_REQUEST_ID_MISMATCH")
  if .QueueRexxPeerMeshCodec~value(response,"source_node","")<>peerNodeId~string then return .QueueOperationResult~failure("PEER_RESPONSE_SOURCE_MISMATCH")
  if .QueueRexxPeerMeshCodec~value(response,"from_node","")<>localNodeId then return .QueueOperationResult~failure("PEER_RESPONSE_CALLER_MISMATCH")
  if .QueueRexxPeerMeshCodec~value(response,"to_node","")<>peerNodeId~string then return .QueueOperationResult~failure("PEER_RESPONSE_DESTINATION_MISMATCH")
  if .QueueRexxPeerMeshCodec~value(response,"operation","")<>operation~string~upper then return .QueueOperationResult~failure("PEER_RESPONSE_OPERATION_MISMATCH")
  return rr

::class QueueRexxPeerDecisionPolicy public
::attribute mode get
::attribute minimumApprovals get
::attribute minimumResponses get
::attribute requiredPeers get
::attribute denyVeto get
::method init
  expose mode minimumApprovals minimumResponses requiredPeers denyVeto
  use strict arg modeArg="QUORUM", approvalsArg=1, responsesArg=1, requiredArg=.nil, denyVetoArg=.false
  mode=modeArg~string~upper; minimumApprovals=approvalsArg+0; minimumResponses=responsesArg+0; denyVeto=(denyVetoArg==.true)
  if requiredArg==.nil then requiredPeers=.array~new; else do; requiredPeers=.array~new; do p over requiredArg; requiredPeers~append(p~string); end; end
  if mode<>.QueueRexxPeerDecisionMode~ANY & mode<>.QueueRexxPeerDecisionMode~QUORUM & mode<>.QueueRexxPeerDecisionMode~ALL_AVAILABLE & mode<>.QueueRexxPeerDecisionMode~REQUIRED then raise syntax 88.900 array("invalid peer decision mode")
  if minimumApprovals<0 | minimumResponses<0 then raise syntax 88.900 array("peer decision minima must be non-negative")

::class QueueRexxPeerMeshDecision public
::attribute approved get
::attribute code get
::attribute detail get
::attribute approvals get
::attribute denials get
::attribute abstentions get
::attribute errors get
::attribute unavailable get
::attribute responses get
::method init
  expose approved code detail approvals denials abstentions errors unavailable responses
  use strict arg approvedArg, codeArg, detailArg, approvalsArg, denialsArg, abstentionsArg, errorsArg, unavailableArg, responsesArg
  approved=(approvedArg==.true); code=codeArg~string; detail=detailArg~string; approvals=approvalsArg; denials=denialsArg; abstentions=abstentionsArg; errors=errorsArg; unavailable=unavailableArg; responses=responsesArg
::method evidence
  expose approved code detail approvals denials abstentions errors unavailable responses
  d=.directory~new; if approved then d["approved"]="1"; else d["approved"]="0"; d["code"]=code; d["detail"]=detail; d["approvals"]=approvals; d["denials"]=denials; d["abstentions"]=abstentions; d["errors"]=errors; d["unavailable"]=unavailable; d["responses"]=responses; return d

::class QueueRexxPeerMeshCoordinator public
::method init
  expose client
  use strict arg clientArg
  client=clientArg
::method evaluate
  expose client
  use strict arg peers, operation, subject=.nil, context=.nil, policy=.nil, createdEpochMs=0, expiresEpochMs=0, policyRef="", decisionId=""
  if policy==.nil then policy=.QueueRexxPeerDecisionPolicy~new
  approvals=.array~new; denials=.array~new; abstentions=.array~new; errors=.array~new; unavailable=.array~new; responses=.directory~new
  do peer over peers
    requestId=""
    if decisionId<>"" then requestId=decisionId~string||":"||peer~string
    rr=client~request(peer,operation,subject,context,createdEpochMs,expiresEpochMs,policyRef,requestId)
    if rr==.nil | \rr~ok then do; unavailable~append(peer~string); iterate; end
    response=rr~value; responses[peer~string]=response
    decision=.QueueRexxPeerMeshCodec~value(response,"decision",.QueueRexxPeerDecisionCode~ERROR)~upper
    select
      when decision=.QueueRexxPeerDecisionCode~APPROVE then approvals~append(peer~string)
      when decision=.QueueRexxPeerDecisionCode~DENY then denials~append(peer~string)
      when decision=.QueueRexxPeerDecisionCode~ABSTAIN then abstentions~append(peer~string)
      otherwise errors~append(peer~string)
    end
  end
  responded=approvals~items+denials~items+abstentions~items+errors~items
  ok=.false; code="PEER_POLICY_NOT_SATISFIED"
  requiredOk=.true
  if policy~mode=.QueueRexxPeerDecisionMode~REQUIRED then do
    do required over policy~requiredPeers
      if \self~arrayContains(approvals,required) then requiredOk=.false
    end
    ok=requiredOk & approvals~items>=policy~minimumApprovals & responded>=policy~minimumResponses
  end
  else if policy~mode=.QueueRexxPeerDecisionMode~ANY then ok=approvals~items>=max(1,policy~minimumApprovals) & responded>=policy~minimumResponses
  else if policy~mode=.QueueRexxPeerDecisionMode~QUORUM then ok=approvals~items>=policy~minimumApprovals & responded>=policy~minimumResponses
  else if policy~mode=.QueueRexxPeerDecisionMode~ALL_AVAILABLE then ok=responded>=max(1,policy~minimumResponses) & approvals~items=responded
  if policy~denyVeto & denials~items>0 then ok=.false
  if ok then code="PEER_POLICY_APPROVED"
  detail="mode="||policy~mode||";approvals="||approvals~items||";responses="||responded||";unavailable="||unavailable~items
  return .QueueRexxPeerMeshDecision~new(ok,code,detail,approvals,denials,abstentions,errors,unavailable,responses)
::method arrayContains private
  use strict arg items, wanted
  do item over items; if item~string=wanted~string then return .true; end
  return .false

/* ------------------------------------------------------------------ */
/* Durable/replay-safe inter-node authorization frontage.              */
/*                                                                     */
/* An authorizationId is a transaction identity, not merely a label.  */
/* The complete aggregation policy is embedded in the request context  */
/* and every peer request id is derived from authorizationId+peer.      */
/* A retry therefore receives exact peer replay; changing the subject, */
/* context, or quorum policy under the same authorizationId conflicts. */
/* ------------------------------------------------------------------ */
::class QueueRexxPeerAuthorizationContract public
::constant RECEIPT_SCHEMA "queuerexx.peer.authorization.receipt/1"

::class QueueRexxPeerAuthorizationReceipt public
::attribute authorizationId get
::attribute decision get
::attribute directory get
::method init
  expose authorizationId decision directory
  use strict arg authorizationIdArg, decisionArg, subjectDigestArg, policyDirectoryArg, createdEpochMsArg=0, expiresEpochMsArg=0, policyRefArg=""
  authorizationId=authorizationIdArg~string; decision=decisionArg
  directory=.directory~new
  directory["schema"]=.QueueRexxPeerAuthorizationContract~RECEIPT_SCHEMA
  directory["api"]=.QueueRexxPeerMeshContract~API
  directory["authorization_id"]=authorizationId
  if decision~approved then directory["approved"]="1"; else directory["approved"]="0"
  directory["code"]=decision~code; directory["detail"]=decision~detail
  directory["subject_digest"]=subjectDigestArg~string
  directory["policy"]=policyDirectoryArg
  directory["created_epoch_ms"]=createdEpochMsArg+0
  directory["expires_epoch_ms"]=expiresEpochMsArg+0
  directory["policy_ref"]=policyRefArg~string
  directory["approvals"]=decision~approvals
  directory["denials"]=decision~denials
  directory["abstentions"]=decision~abstentions
  directory["errors"]=decision~errors
  directory["unavailable"]=decision~unavailable
  directory["responses"]=decision~responses
::method approved
  expose decision
  return decision~approved
::method asDirectory
  expose directory
  return directory

::class QueueRexxPeerAuthorizationGate public
::method init
  expose coordinator digestProvider
  use strict arg coordinatorArg, digestArg=.nil
  coordinator=coordinatorArg
  if digestArg==.nil then digestProvider=.QueueDigestProvider~new; else digestProvider=digestArg

::method authorize
  expose coordinator digestProvider
  use strict arg peers, subject, context=.nil, policy=.nil, authorizationId, createdEpochMs=0, expiresEpochMs=0, policyRef=""
  if authorizationId~string~strip="" then raise syntax 88.900 array("peer authorization id is required")
  if policy==.nil then policy=.QueueRexxPeerDecisionPolicy~new
  policyDir=self~policyDirectory(policy)
  boundContext=self~copyDirectory(context)
  boundContext["mesh_authorization_id"]=authorizationId~string
  boundContext["mesh_decision_policy"]=policyDir
  subjectDigest=digestProvider~digest(.QueueRexxPeerMeshCodec~canonicalValue(subject))
  d=coordinator~evaluate(peers,.QueueRexxPeerOperation~AUTHORIZE,subject,boundContext,policy,createdEpochMs,expiresEpochMs,policyRef,authorizationId)
  return .QueueRexxPeerAuthorizationReceipt~new(authorizationId,d,subjectDigest,policyDir,createdEpochMs,expiresEpochMs,policyRef)

::method policyDirectory private
  use strict arg policy
  d=.directory~new
  d["mode"]=policy~mode; d["minimum_approvals"]=policy~minimumApprovals; d["minimum_responses"]=policy~minimumResponses
  d["deny_veto"]=policy~denyVeto
  required=.array~new; do p over policy~requiredPeers; required~append(p~string); end
  d["required_peers"]=required
  return d

::method copyDirectory private
  use strict arg source
  out=.directory~new
  if source==.nil then return out
  if \source~isA(.Directory) & \source~isA(.Table) then raise syntax 88.900 array("peer authorization context must be a Directory or Table")
  sup=source~supplier
  do while sup~available
    out[sup~index]=sup~item
    sup~next
  end
  return out

/* ------------------------------------------------------------------ */
/* QueueRexx node-side mesh composition over an existing Queue Fabric. */
/* One peer link = one permanent xmit queue + sender + receiver and    */
/* two remote aliases (request/reply).  The topology is N-peer mesh.   */
/* ------------------------------------------------------------------ */
::class QueueRexxPeerMeshRuntime public
::attribute localNodeId get
::attribute managerName get
::attribute service get
::attribute client get
::attribute coordinator get
::attribute authorizationGate get
::attribute trustPolicy get
::attribute ledger get
::attribute queueManager get
::attribute channels get
::attribute transport get
::attribute listener get
::attribute adminPrincipal get
::method init
  expose localNodeId managerName queueManager channels transport listener adminPrincipal root trustPolicy ledger service client coordinator authorizationGate
  use strict arg localNodeArg, rootArg, managerNameArg, queueManagerArg, channelFabricArg, transportArg, listenerArg=.nil, adminArg="queue-admin", digestArg=.nil
  localNodeId=localNodeArg~string; root=rootArg~string; managerName=managerNameArg~string; queueManager=queueManagerArg; channels=channelFabricArg; transport=transportArg; listener=listenerArg; adminPrincipal=adminArg~string
  if localNodeId="" | root="" | managerName="" | queueManager==.nil | channels==.nil | transport==.nil then raise syntax 88.900 array("peer mesh runtime collaborators required")
  address system "mkdir -p " || root || "/logs/queuerexx-peer-mesh"
  trustPolicy=.QueueRexxPeerTrustPolicy~new
  ledger=.QueueRexxPeerMeshRequestLedger~new(root||"/logs/queuerexx-peer-mesh/requests.journal",digestArg,queueManager~payloadCodec)
  if \ledger~ready then raise syntax 88.900 array("peer mesh ledger failed integrity check")
  service=.QueueRexxPeerMeshService~new(localNodeId,trustPolicy,ledger,channels,adminPrincipal)
  client=.QueueRexxPeerMeshClient~new(localNodeId); coordinator=.QueueRexxPeerMeshCoordinator~new(client); authorizationGate=.QueueRexxPeerAuthorizationGate~new(coordinator,digestArg)

::method bindFabricPeer
  expose localNodeId managerName queueManager channels listener adminPrincipal trustPolicy client
  use strict arg peerNodeId, peerManager, transportPrincipal, operations, timeoutMs=10000
  safe=peerNodeId~string~translate
  requestQueue="QRX.PEER.REQUEST."||safe; replyQueue="QRX.PEER.REPLY."||safe; xmitQueue="QRX.PEER.XMIT."||safe
  recvChannel="QRX.PEER.RECV."||safe; sendChannel="QRX.PEER.SEND."||safe
  requestAlias="QRX.PEER.REMOTE.REQUEST."||safe; replyAlias="QRX.PEER.REMOTE.REPLY."||safe
  remoteRequestQueue="QRX.PEER.REQUEST."||localNodeId~translate; remoteReplyQueue="QRX.PEER.REPLY."||localNodeId~translate; remoteRecvChannel="QRX.PEER.RECV."||localNodeId~translate
  qr=self~ensureQueue(requestQueue,transportPrincipal); if \qr~ok then return qr
  qr=self~ensureQueue(replyQueue,transportPrincipal); if \qr~ok then return qr
  qr=self~ensureQueue(xmitQueue,adminPrincipal); if \qr~ok then return qr
  if channels~receiverChannel(recvChannel)==.nil then do
    r=channels~defineReceiverChannel(recvChannel,peerManager,transportPrincipal,.QueueLifecycle~PERMANENT,adminPrincipal); if \r~ok then return r
  end
  ignore=channels~startReceiverChannel(recvChannel,adminPrincipal)
  if channels~senderChannel(sendChannel)==.nil then do
    r=channels~defineSenderChannel(sendChannel,xmitQueue,peerManager,remoteRecvChannel,adminPrincipal,transportPrincipal,5,.QueueLifecycle~PERMANENT,adminPrincipal); if \r~ok then return r
  end
  ignore=channels~startSenderChannel(sendChannel,adminPrincipal)
  if channels~remoteQueue(requestAlias)==.nil then do
    r=channels~defineRemoteQueue(requestAlias,remoteRequestQueue,peerManager,xmitQueue,sendChannel,.QueueRexxPeerMeshContract~SECURITY_DOMAIN,.QueueLifecycle~PERMANENT,adminPrincipal,adminPrincipal); if \r~ok then return r
  end
  ignore=channels~grantRemotePut(requestAlias,adminPrincipal,adminPrincipal)
  if channels~remoteQueue(replyAlias)==.nil then do
    r=channels~defineRemoteQueue(replyAlias,remoteReplyQueue,peerManager,xmitQueue,sendChannel,.QueueRexxPeerMeshContract~SECURITY_DOMAIN,.QueueLifecycle~PERMANENT,adminPrincipal,adminPrincipal); if \r~ok then return r
  end
  ignore=channels~grantRemotePut(replyAlias,adminPrincipal,adminPrincipal)
  binding=trustPolicy~bindPeer(peerNodeId,peerManager,transportPrincipal,requestQueue,replyAlias,operations)
  executor=.QueueRexxPeerQueueFabricRequestExecutor~new(channels,requestAlias,sendChannel,replyQueue,listener,adminPrincipal,adminPrincipal,timeoutMs)
  client~addRoute(peerNodeId,executor)
  d=.directory~new; d["binding"]=binding; d["request_queue"]=requestQueue; d["reply_queue"]=replyQueue; d["sender_channel"]=sendChannel; d["receiver_channel"]=recvChannel; d["request_alias"]=requestAlias; d["reply_alias"]=replyAlias
  return .QueueOperationResult~success(d,"peer fabric route bound")

::method bindSocketPeer
  expose transport listener
  use strict arg peerNodeId, peerManager, remoteHost, remotePort, transportPrincipal, keyId, keyHex, allowedSourceIps, operations, timeoutMs=10000
  ignore=transport~registerEndpoint(peerManager,remoteHost,remotePort,transportPrincipal,keyId,keyHex)
  if listener<>.nil then ignore=listener~trustPeer(peerManager,transportPrincipal,keyId,keyHex,allowedSourceIps)
  return self~bindFabricPeer(peerNodeId,peerManager,transportPrincipal,operations,timeoutMs)

/* Bind an application/service queue pair over an already-established peer.
 * This is deliberately service-neutral: the peer mesh owns transport/trust;
 * the caller owns the service protocol and semantic authority. */
::method bindServiceRoute
  expose localNodeId queueManager channels adminPrincipal trustPolicy
  use strict arg peerNodeId, serviceId, localQueueName, remoteQueueName, securityDomain, localPrincipal="queue-admin"
  b=trustPolicy~binding(peerNodeId)
  if b==.nil then return .QueueOperationResult~failure("PEER_NOT_BOUND",peerNodeId)
  if serviceId~string~strip="" | localQueueName~string~strip="" | remoteQueueName~string~strip="" then return .QueueOperationResult~failure("SERVICE_ROUTE_INVALID","service/local/remote queue required")
  if securityDomain~string~strip="" then return .QueueOperationResult~failure("SERVICE_ROUTE_INVALID","security domain required")
  safePeer=peerNodeId~string~translate
  safeService=serviceId~string~translate
  q=self~ensureQueueDomain(localQueueName,b~transportPrincipal,securityDomain)
  if \q~ok then return q
  /* A service gets its own xmit queue/security domain but reuses the peer's
   * endpoint, inbound trust and receiver channel.  Thus service isolation is
   * preserved without inventing another node connection. */
  xmitQueue="QRX.SERVICE."||safeService||".XMIT."||safePeer
  sendChannel="QRX.SERVICE."||safeService||".SEND."||safePeer
  remoteRecvChannel="QRX.PEER.RECV."||localNodeId~string~translate
  x=self~ensureQueueDomain(xmitQueue,adminPrincipal,securityDomain)
  if \x~ok then return x
  if channels~senderChannel(sendChannel)==.nil then do
    r=channels~defineSenderChannel(sendChannel,xmitQueue,b~peerManager,remoteRecvChannel,adminPrincipal,b~transportPrincipal,5,.QueueLifecycle~PERMANENT,adminPrincipal)
    if \r~ok then return r
  end
  ignore=channels~startSenderChannel(sendChannel,adminPrincipal)
  alias="QRX.SERVICE."||safeService||".REMOTE."||safePeer
  if channels~remoteQueue(alias)==.nil then do
    r=channels~defineRemoteQueue(alias,remoteQueueName,b~peerManager,xmitQueue,sendChannel,securityDomain,.QueueLifecycle~PERMANENT,adminPrincipal,adminPrincipal)
    if \r~ok then return r
  end
  ignore=channels~grantRemotePut(alias,localPrincipal,adminPrincipal)
  d=.directory~new
  d["peer_node_id"]=peerNodeId~string; d["service_id"]=serviceId~string
  d["local_queue"]=localQueueName~string; d["remote_queue"]=remoteQueueName~string
  d["remote_alias"]=alias; d["sender_channel"]=sendChannel; d["xmit_queue"]=xmitQueue
  return .QueueOperationResult~success(d,"service route bound over existing peer")

::method ensureQueueDomain private
  expose queueManager adminPrincipal
  use strict arg queueName, grantee, securityDomain
  q=queueManager~queue(queueName)
  if q==.nil then do
    r=queueManager~createQueue(queueName,.QueueLifecycle~PERMANENT,securityDomain,5000,adminPrincipal)
    if \r~ok then return r
    q=r~value
  end
  if q~securityDomain<>securityDomain then return .QueueOperationResult~failure("SECURITY_DOMAIN_MISMATCH",securityDomain||" != "||q~securityDomain)
  ignore=queueManager~grant(queueName,grantee,.QueueAccess~PUT,adminPrincipal)
  ignore=queueManager~grant(queueName,adminPrincipal,.QueueAccess~GET,adminPrincipal)
  return .QueueOperationResult~success(q)

::method ensureQueue private
  expose queueManager adminPrincipal
  use strict arg queueName, grantee
  if queueManager~queue(queueName)==.nil then do
    r=queueManager~createQueue(queueName,.QueueLifecycle~PERMANENT,.QueueRexxPeerMeshContract~SECURITY_DOMAIN,5000,adminPrincipal)
    if \r~ok then return r
  end
  ignore=queueManager~grant(queueName,grantee,.QueueAccess~PUT,adminPrincipal)
  ignore=queueManager~grant(queueName,adminPrincipal,.QueueAccess~GET,adminPrincipal)
  return .QueueOperationResult~success(queueManager~queue(queueName))

::method servePeer
  expose service
  use strict arg peerNodeId, maxMessages=1
  return service~servePeer(peerNodeId,maxMessages)
::method startListener
  expose listener
  if listener==.nil then return .false
  return listener~start
::method serveTransportOne
  expose listener
  if listener==.nil then return .QueueOperationResult~failure("PEER_LISTENER_UNAVAILABLE")
  return listener~serveOne
::method pumpPeer
  expose channels adminPrincipal
  use strict arg peerNodeId
  return channels~pump("QRX.PEER.SEND."||peerNodeId~string~translate,0,adminPrincipal)

/* Durable operator configuration for a QueueRexx peer mesh.
 * The document contains connectivity/trust configuration only; it is not
 * semantic authority for services carried by the mesh. */
::class QueueRexxPeerMeshConfig public
::constant SCHEMA "queuerexx.peer.mesh.config/1"
::attribute path get
::method init
  expose path
  use strict arg pathArg
  path=pathArg~string

::method apply
  expose path
  use strict arg runtime
  if stream(path,"c","query exists")="" then return .QueueOperationResult~failure("PEER_MESH_CONFIG_MISSING",path)
  signal on syntax name configFailed
  doc=.QueueSerialization~fromJsonFile(path)
  signal off syntax
  if doc==.nil | \doc~isA(.Directory) then return .QueueOperationResult~failure("PEER_MESH_CONFIG_INVALID","JSON object required")
  if doc["schema"]==.nil | doc["schema"]~string<>self~SCHEMA then return .QueueOperationResult~failure("PEER_MESH_CONFIG_SCHEMA",doc["schema"])
  peers=doc["peers"]
  if peers==.nil | \peers~isA(.Array) then return .QueueOperationResult~failure("PEER_MESH_CONFIG_INVALID","peers array required")
  count=0
  do row over peers
    if row==.nil | \row~isA(.Directory) then return .QueueOperationResult~failure("PEER_MESH_CONFIG_INVALID","peer entry must be object")
    node=self~req(row,"node_id"); manager=self~req(row,"manager"); host=self~req(row,"host")
    principal=self~req(row,"transport_principal"); keyId=self~req(row,"key_id"); keyHex=self~req(row,"key_hex")
    if node==.nil | manager==.nil | host==.nil | principal==.nil | keyId==.nil | keyHex==.nil then return .QueueOperationResult~failure("PEER_MESH_CONFIG_INVALID","required peer field missing")
    port=row["port"]; if port==.nil | \datatype(port,"W") | port<1 | port>65535 then return .QueueOperationResult~failure("PEER_MESH_CONFIG_INVALID",node||":port")
    ops=row["operations"]; if ops==.nil then ops=.array~new
    ips=row["allowed_source_ips"]; if ips==.nil then ips=.array~new
    timeout=row["timeout_ms"]; if timeout==.nil then timeout=10000
    r=runtime~bindSocketPeer(node,manager,host,port,principal,keyId,keyHex,ips,ops,timeout)
    if \r~ok then return .QueueOperationResult~failure("PEER_MESH_BIND_FAILED",node||":"||r~code||":"||r~detail)
    count+=1
  end
  return .QueueOperationResult~success(count,"peers="||count)
configFailed:
  signal off syntax
  return .QueueOperationResult~failure("PEER_MESH_CONFIG_READ_FAILED",condition("D"))

::method req private
  use strict arg row,key
  v=row[key]
  if v==.nil then return .nil
  v=v~string~strip
  if v="" then return .nil
  return v

::requires "QueueRexxSerialization.cls"
::requires "QueueRexxCore.cls"
::requires "QueueRexxCrypto.cls"
::requires "ObjectQueueSocketTransport.cls"
