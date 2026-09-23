/* Remote placed-start protocol for Migratable Job v0.2.5.
 *
 * API: migratable.job.remote-start/1
 * Transport: Queue Fabric direct request/reply queues.
 *
 * The protocol is deliberately narrower than migration handoff: it is only
 * for initial NEW execution after Job-to-Node has committed a placement.
 * The destination re-verifies the placement immediately before entering the
 * standard starter. Transport delivery is never execution authority.
 */

::class MigratableJobRemoteStartContract public
::constant API "migratable.job.remote-start/1"
::constant REQUEST_SCHEMA "migratable.job.remote-start.request/1"
::constant RESPONSE_SCHEMA "migratable.job.remote-start.response/1"

::class MigratableJobRemoteStartCodec public
::method encodeStartRequest class
  use strict arg request
  if request==.nil then return .nil
  t=.table~new
  t["startId"]=request~startId
  t["mode"]=request~mode
  t["jobId"]=request~jobId
  t["definitionRef"]=request~definitionRef
  t["partitionId"]=request~partitionId
  t["migrationId"]=request~migrationId
  t["requestedEpochMs"]=request~requestedEpochMs
  t["checkpointOverride"]=request~checkpointOverride
  t["leaseDurationMs"]=request~leaseDurationMs
  t["maxTransferChunks"]=request~maxTransferChunks
  t["metadataRef"]=request~metadataRef
  return t
::method decodeStartRequest class
  use strict arg t
  if t==.nil then return .nil
  return .MigratableJobStartRequest~new(t["startId"],t["mode"],t["jobId"],t["definitionRef"],t["partitionId"],t["migrationId"],t["requestedEpochMs"],.nil,t["checkpointOverride"],t["leaseDurationMs"],t["maxTransferChunks"],t["metadataRef"])
::method encodeStartResult class
  use strict arg startResultArg
  if startResultArg==.nil then return .nil
  t=.table~new
  t["ok"]=startResultArg~ok
  t["code"]=startResultArg~code
  t["state"]=startResultArg~state
  t["startId"]=startResultArg~startId
  t["mode"]=startResultArg~mode
  t["jobId"]=startResultArg~jobId
  t["migrationId"]=startResultArg~migrationId
  t["executionRef"]=startResultArg~executionRef
  t["detail"]=startResultArg~detail
  t["replayed"]=startResultArg~replayed
  return t
::method decodeStartResult class
  use strict arg t
  if t==.nil then return .nil
  return .MigratableJobStartResult~new(t["ok"],t["code"],t["state"],t["startId"],t["mode"],t["jobId"],t["migrationId"],t["executionRef"],t["detail"],t["replayed"])

::class MigratableJobRemoteStartAccessPolicy public
::method init
  expose grants
  grants=.directory~new
::method grant
  expose grants
  use strict arg clientIdArg, ownerNodeIdArg=""
  row=.table~new; row["ownerNodeId"]=ownerNodeIdArg~string
  grants[clientIdArg~string~upper]=row
  return self
::method authorised
  expose grants
  use strict arg clientIdArg, lease
  row=grants[clientIdArg~string~upper]
  if row==.nil then return .false
  if lease==.nil then return .false
  bound=row["ownerNodeId"]
  if bound<>"" & lease~ownerNodeId<>bound then return .false
  return .true

/* Durable RPC replay ledger.  This is separate from the starter receipt:
 * - RPC ledger binds requestId to lease + start request + response;
 * - starter receipt binds startId to the workload runtime side effect.
 */
::class MigratableJobRemoteStartRequestLedger public
::method init
  expose path codec rows
  use strict arg pathArg="", codecArg=.nil
  path=pathArg~string
  if codecArg==.nil then codec=.QueueGraphPayloadCodec~new; else codec=codecArg
  rows=.directory~new
  if path<>"" then self~load
::method lookup
  expose rows
  use strict arg requestIdArg
  return rows[requestIdArg~string]
::method record
  expose path codec rows
  use strict arg requestIdArg, digestArg, response
  id=requestIdArg~string; digest=digestArg~string
  existing=rows[id]
  if existing<>.nil then return existing["digest"]=digest
  row=.table~new; row["digest"]=digest; row["response"]=response; rows[id]=row
  if path<>"" then do
    s=.stream~new(path); opened=s~open("write append")
    if opened<>"READY:" then return .false
    encoded=codec~encode(response)
    s~lineout(id||"09"x||digest||"09"x||c2x(encoded)); s~close
  end
  return .true
::method load private
  expose path codec rows
  if stream(path,"c","query exists")="" then return
  s=.stream~new(path); opened=s~open("read")
  if opened<>"READY:" then raise syntax 88.900 array("could not read remote start request ledger",path)
  do while s~lines>0
    line=s~linein
    parse var line id "09"x digest "09"x responseHex
    if id="" | digest="" | responseHex="" then do; s~close; raise syntax 88.900 array("invalid remote start request ledger row"); end
    signal on syntax name badRow
    response=codec~decode(x2c(responseHex))
    signal off syntax
    row=.table~new; row["digest"]=digest; row["response"]=response; rows[id]=row
  end
  s~close
  return
badRow:
  signal off syntax
  s~close
  raise syntax 88.900 array("invalid remote start request ledger row")

/* Destination-side authority seam.  A deployment can verify locally against a
 * resident JobNodeAllocator or remotely against job.node.allocator.network/0.1. */
::class MigratableJobPlacedStartLeaseVerifier public
::method verify abstract

::class MigratableJobLocalPlacedStartLeaseVerifier subclass MigratableJobPlacedStartLeaseVerifier public
::method init
  expose application allocator
  use strict arg applicationArg, allocatorArg
  application=applicationArg; allocator=allocatorArg
  if application==.nil | allocator==.nil then raise syntax 88.900 array("application and allocator required")
::method verify
  expose application allocator
  use strict arg lease, startRequest, nowEpochMs
  if lease==.nil | startRequest==.nil then return .false
  definition=application~definition(startRequest)
  if definition==.nil then return .false
  if definition~jobId<>startRequest~jobId | definition~definitionRef<>startRequest~definitionRef then return .false
  if startRequest~partitionId<>"" & definition~partitionId<>startRequest~partitionId then return .false
  p=definition~placementRequest
  if p==.nil then return .false
  return allocator~verifyLease(lease,p,nowEpochMs)

/* Destination verifier using the networkable Job-to-Node allocator.  It uses
 * CHECK only; no placement mutation is performed here. Each independent lease
 * check gets a fresh requestId so an earlier LEASE_VALID result can never be
 * replayed after the lease has been fenced/released. Retries within that single
 * CHECK invocation retain the same requestId. */
::class MigratableJobJobNodeNetworkLeaseVerifier subclass MigratableJobPlacedStartLeaseVerifier public
::method init
  expose application client maxPolls sleepSeconds progressor inbox sequence
  use strict arg applicationArg, clientArg, maxPollsArg=400, sleepSecondsArg=.025, progressorArg=.nil
  application=applicationArg; client=clientArg; maxPolls=maxPollsArg+0; sleepSeconds=sleepSecondsArg+0; progressor=progressorArg; inbox=.directory~new; sequence=0
  if application==.nil | client==.nil then raise syntax 88.900 array("application and Job-to-Node network client required")
  if maxPolls<0 | sleepSeconds<0 then raise syntax 88.900 array("invalid Job-to-Node network verifier wait configuration")
::method verify guarded
  expose application client maxPolls sleepSeconds progressor inbox sequence
  use strict arg lease, startRequest, nowEpochMs
  if lease==.nil | startRequest==.nil then return .false
  definition=application~definition(startRequest)
  if definition==.nil then return .false
  if definition~jobId<>startRequest~jobId | definition~definitionRef<>startRequest~definitionRef then return .false
  if startRequest~partitionId<>"" & definition~partitionId<>startRequest~partitionId then return .false
  p=definition~placementRequest
  if p==.nil then return .false
  sequence+=1; stamp=time('F')
  requestId="mj-check:"||startRequest~startId||":"||lease~placementId||":"||lease~ownershipEpoch||":"||lease~renewalSequence||":"||stamp||":"||sequence
  cached=inbox[requestId]
  if cached<>.nil then do; inbox~remove(requestId); return cached["code"]="LEASE_VALID"; end
  submitted=client~submit(requestId,"CHECK",p,lease,nowEpochMs,startRequest~leaseDurationMs)
  if submitted==.nil | \submitted~ok then return .false
  do i=0 to maxPolls
    if progressor<>.nil then ignore=progressor~progress
    rr=client~receive
    if rr<>.nil & rr~ok then do
      response=rr~value; id=response["requestId"]
      if id=requestId then return response["code"]="LEASE_VALID"
      if id<>.nil then inbox[id~string]=response
    end
    else if rr<>.nil then if rr~code<>"QUEUE_EMPTY" then return .false
    if i<maxPolls & sleepSeconds>0 then call SysSleep sleepSeconds
  end
  return .false

/* Queue request/reply client implementing the managed-placement start seam.
 * A successful enqueue with no response inside the configured wait window is
 * PENDING, not FAILED: placement remains held and the same startId/requestId can
 * safely be retried/collected later. */
::class MigratableJobQueuePlacedStartExecutor subclass MigratableJobPlacedStartExecutor public
::method init
  expose fabric queues replyManager replyQueue clientId principal digestProvider maxPolls sleepSeconds inbox progressor
  use strict arg fabricArg, replyManagerArg, replyQueueArg, clientIdArg, principalArg="mj-start-client", digestArg=.nil, maxPollsArg=0, sleepSecondsArg=.025, progressorArg=.nil
  fabric=fabricArg; replyManager=replyManagerArg; replyQueue=replyQueueArg~string; clientId=clientIdArg~string; principal=principalArg~string
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
  maxPolls=maxPollsArg+0; sleepSeconds=sleepSecondsArg+0; progressor=progressorArg
  if fabric==.nil | replyManager==.nil | replyQueue="" | clientId="" then raise syntax 88.900 array("remote placed-start client requires fabric, reply queue and client id")
  if maxPolls<0 | sleepSeconds<0 then raise syntax 88.900 array("invalid remote start wait configuration")
  queues=.directory~new; inbox=.directory~new
::method bindNodeQueue
  expose queues
  use strict arg nodeIdArg, queueAliasArg
  queues[nodeIdArg~string~upper]=queueAliasArg~string
  return self
::method start
  expose fabric queues clientId principal digestProvider maxPolls
  use strict arg lease, startRequest, nowEpochMs
  if startRequest==.nil then return .nil
  if lease==.nil then return .MigratableJobStartResult~failure(startRequest,"PLACEMENT_LEASE_REQUIRED")
  alias=queues[lease~nodeId~upper]
  if alias==.nil then return .MigratableJobStartResult~failure(startRequest,"REMOTE_START_QUEUE_UNBOUND","node="||lease~nodeId)
  requestId=startRequest~startId
  wire=.table~new
  wire["schema"]=.MigratableJobRemoteStartContract~REQUEST_SCHEMA
  wire["api"]=.MigratableJobRemoteStartContract~API
  wire["requestId"]=requestId
  wire["clientId"]=clientId
  wire["destinationNodeId"]=lease~nodeId
  wire["lease"]=.JobNodeNetworkCodec~encodeLease(lease)
  wire["startRequest"]=.MigratableJobRemoteStartCodec~encodeStartRequest(startRequest)
  wire["sentEpochMs"]=.MigratableJobTime~number(nowEpochMs)
  options=.table~new; options["persistent"]=.true; options["securityDomain"]="MIGRATABLE_JOB"; options["correlationId"]=requestId
  qr=fabric~put(alias,wire,options,principal)
  if qr==.nil then return .MigratableJobStartResult~failure(startRequest,"REMOTE_START_DISPATCH_MISSING")
  if \qr~ok then return .MigratableJobStartResult~failure(startRequest,"REMOTE_START_DISPATCH_FAILED",qr~code||":"||qr~detail)
  response=self~await(requestId,maxPolls)
  if response==.nil then return .MigratableJobStartResult~pending(startRequest,"REMOTE_START_PENDING","","requestId="||requestId||" destination="||lease~nodeId)
  if response["schema"]<>.MigratableJobRemoteStartContract~RESPONSE_SCHEMA then return .MigratableJobStartResult~failure(startRequest,"REMOTE_START_RESPONSE_SCHEMA")
  startResult=.MigratableJobRemoteStartCodec~decodeStartResult(response["result"])
  if startResult==.nil then do
    if response["code"]<>.nil & response["code"]~string<>"" then return .MigratableJobStartResult~failure(startRequest,response["code"]~string,"remote status="||response["status"])
    return .MigratableJobStartResult~failure(startRequest,"REMOTE_START_RESULT_MISSING")
  end
  if response["replayed"]==.true then return .MigratableJobStartResult~new(startResult~ok,startResult~code,startResult~state,startResult~startId,startResult~mode,startResult~jobId,startResult~migrationId,startResult~executionRef,startResult~detail,.true)
  return startResult
::method collect
  expose maxPolls
  use strict arg requestIdArg, pollsArg=""
  if pollsArg~string="" then polls=maxPolls; else polls=pollsArg+0
  response=self~await(requestIdArg~string,polls)
  if response==.nil then return .nil
  startResult=.MigratableJobRemoteStartCodec~decodeStartResult(response["result"])
  if startResult<>.nil then if response["replayed"]==.true then return .MigratableJobStartResult~new(startResult~ok,startResult~code,startResult~state,startResult~startId,startResult~mode,startResult~jobId,startResult~migrationId,startResult~executionRef,startResult~detail,.true)
  return startResult
::method await private
  expose replyManager replyQueue principal inbox progressor sleepSeconds
  use strict arg requestId, polls
  cached=inbox[requestId]
  if cached<>.nil then do; inbox~remove(requestId); return cached; end
  do i=0 to polls
    if progressor<>.nil then ignore=progressor~progress
    r=replyManager~get(replyQueue,principal)
    if r<>.nil & r~ok then do
      payload=r~value~payload
      id=payload["requestId"]
      if id=requestId then return payload
      if id<>.nil then inbox[id~string]=payload
    end
    else if r<>.nil then if r~code<>"QUEUE_EMPTY" then return .nil
    if i<polls & sleepSeconds>0 then call SysSleep sleepSeconds
  end
  return .nil

::class MigratableJobRemoteStartService public
::method init
  expose localNodeId starter leaseVerifier requestManager requestQueue responseFabric servicePrincipal accessPolicy ledger digestProvider serverId replyAliases
  use strict arg localNodeArg, starterArg, leaseVerifierArg, requestManagerArg, requestQueueArg, responseFabricArg, servicePrincipalArg="mj-start-service", accessPolicyArg=.nil, ledgerArg=.nil, digestArg=.nil, serverIdArg="MIGRATABLE-JOB-START"
  localNodeId=localNodeArg~string; starter=starterArg; leaseVerifier=leaseVerifierArg; requestManager=requestManagerArg; requestQueue=requestQueueArg~string; responseFabric=responseFabricArg; servicePrincipal=servicePrincipalArg~string; serverId=serverIdArg~string
  if accessPolicyArg==.nil then accessPolicy=.MigratableJobRemoteStartAccessPolicy~new; else accessPolicy=accessPolicyArg
  if ledgerArg==.nil then ledger=.MigratableJobRemoteStartRequestLedger~new; else ledger=ledgerArg
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
  replyAliases=.directory~new
  if localNodeId="" | starter==.nil | leaseVerifier==.nil | requestManager==.nil | requestQueue="" | responseFabric==.nil then raise syntax 88.900 array("remote start service configuration incomplete")
::method bindClientReply
  expose replyAliases
  use strict arg clientIdArg, aliasArg
  replyAliases[clientIdArg~string~upper]=aliasArg~string
  return self
::method processOne
  expose requestManager requestQueue servicePrincipal
  claim=requestManager~claim(requestQueue,servicePrincipal)
  if claim==.nil | \claim~ok then return claim
  package=claim~value; wire=package~payload
  response=self~handle(wire)
  staged=self~stageResponse(wire["clientId"],response)
  if staged==.nil | \staged~ok then do
    ignore=requestManager~release(requestQueue,package~packageId,package~claimToken,servicePrincipal,"remote start response staging failed")
    return staged
  end
  acked=requestManager~ack(requestQueue,package~packageId,package~claimToken,servicePrincipal)
  if acked==.nil | \acked~ok then return acked
  return .QueueOperationResult~success(response)
::method handle
  expose localNodeId starter leaseVerifier accessPolicy ledger digestProvider serverId
  use strict arg wire
  if wire==.nil then return self~response("","","INVALID_REQUEST","REQUEST_REQUIRED",.nil,"",.false)
  requestId=wire["requestId"]~string; clientId=wire["clientId"]~string
  if wire["schema"]<>.MigratableJobRemoteStartContract~REQUEST_SCHEMA then return self~response(requestId,clientId,"INVALID_REQUEST","SCHEMA_UNSUPPORTED",.nil,"",.false)
  if requestId="" then return self~response("",clientId,"INVALID_REQUEST","REQUEST_ID_REQUIRED",.nil,"",.false)
  lease=.JobNodeNetworkCodec~decodeLease(wire["lease"])
  request=.MigratableJobRemoteStartCodec~decodeStartRequest(wire["startRequest"])
  canonical="client="||clientId||";destination="||wire["destinationNodeId"]
  if lease<>.nil then canonical=canonical||";lease={"||lease~canonical||"}"
  if request<>.nil then canonical=canonical||";start={"||request~canonical||"}"
  digest=digestProvider~digest(canonical)
  prior=ledger~lookup(requestId)
  if prior<>.nil then do
    if prior["digest"]<>digest then return self~response(requestId,clientId,"DENIED","REQUEST_ID_CONFLICT",.nil,digest,.false)
    replay=prior["response"]~copy; replay["replayed"]=.true; return replay
  end
  if request==.nil | lease==.nil then response=self~response(requestId,clientId,"INVALID_REQUEST","START_REQUEST_AND_LEASE_REQUIRED",.nil,digest,.false)
  else if request~mode<>.MigratableJobStartMode~NEW then response=self~response(requestId,clientId,"DENIED","REMOTE_INITIAL_START_REQUIRES_NEW",.nil,digest,.false)
  else if \accessPolicy~authorised(clientId,lease) then response=self~response(requestId,clientId,"DENIED","CLIENT_NOT_AUTHORISED",.nil,digest,.false)
  else if wire["destinationNodeId"]<>localNodeId | lease~nodeId<>localNodeId then response=self~response(requestId,clientId,"DENIED","DESTINATION_NODE_MISMATCH",.nil,digest,.false)
  else if lease~jobId<>request~jobId then response=self~response(requestId,clientId,"DENIED","PLACEMENT_JOB_MISMATCH",.nil,digest,.false)
  else do
    now=.MigratableJobTime~nowEpochMs
    if \leaseVerifier~verify(lease,request,now) then response=self~response(requestId,clientId,"DENIED","PLACEMENT_INVALID_AT_DESTINATION",.nil,digest,.false)
    else do
      startResult=starter~start(request)
      if startResult==.nil then response=self~response(requestId,clientId,"FAILED","START_RESULT_MISSING",.nil,digest,.false)
      else if startResult~ok then response=self~response(requestId,clientId,"OK",startResult~code,startResult,digest,.false)
      else response=self~response(requestId,clientId,"FAILED",startResult~code,startResult,digest,.false)
    end
  end
  if \ledger~record(requestId,digest,response) then return self~response(requestId,clientId,"FAILED","LEDGER_CONFLICT",.nil,digest,.false)
  return response
::method response private
  expose serverId
  use strict arg requestId, clientId, status, code, startResultArg=.nil, digest="", replayed=.false
  t=.table~new
  t["schema"]=.MigratableJobRemoteStartContract~RESPONSE_SCHEMA; t["api"]=.MigratableJobRemoteStartContract~API
  t["requestId"]=requestId~string; t["clientId"]=clientId~string; t["status"]=status~string; t["code"]=code~string; t["serverId"]=serverId; t["requestDigest"]=digest~string; t["replayed"]=(replayed==.true)
  t["result"]=.MigratableJobRemoteStartCodec~encodeStartResult(startResultArg)
  return t
::method stageResponse private
  expose responseFabric replyAliases servicePrincipal
  use strict arg clientIdArg, response
  alias=replyAliases[clientIdArg~string~upper]
  if alias==.nil then return .QueueOperationResult~failure("CLIENT_REPLY_ROUTE_UNBOUND",clientIdArg)
  options=.table~new; options["persistent"]=.true; options["securityDomain"]="MIGRATABLE_JOB"; options["correlationId"]=response["requestId"]
  return responseFabric~put(alias,response,options,servicePrincipal)

::requires "MigratableJobManagedPlacement.cls"
::requires "JobNodeNetworkService.cls"
::requires "ObjectQueueChannels.cls"
