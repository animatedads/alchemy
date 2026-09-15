/* Network service facade for Job-to-Node Allocator v0.6.
 *
 * API: job.node.allocator.network/0.1
 * Transport: Queue Fabric direct queues / authenticated socket channels.
 *
 * Authority rule: this class never decides placement independently.  Mutating
 * operations delegate to the supplied JobNodeAllocator instance.  PLAN is
 * explicitly advisory and uses the same supplied registry/policies without
 * creating admission or ownership state.
 */

::class JobNodeNetworkBuild public
::constant VERSION "0.1"
::constant API "job.node.allocator.network/0.1"
::constant REQUEST_SCHEMA "job.node.allocator.network.request/1"
::constant RESPONSE_SCHEMA "job.node.allocator.network.response/1"

::class JobNodeNetworkApiRouteRequirement public
::attribute country get
::attribute vpn get
::attribute network get
::attribute egressClass get
::attribute requiredTags get
::method init
  expose country vpn network egressClass requiredTags
  use arg countryArg="", vpnArg="", networkArg="", egressArg="", tagsArg=.nil
  country=countryArg~string~upper; vpn=vpnArg~string~upper; network=networkArg~string~upper; egressClass=egressArg~string~upper
  if tagsArg==.nil then requiredTags=.array~new; else requiredTags=tagsArg

::class JobNodeNetworkCodec public
::method encodePlacementRequest class
  use strict arg request
  if request==.nil then return .nil
  t=.table~new
  t["jobId"]=request~jobId
  t["ownerNodeId"]=request~ownerNodeId
  t["expectedMicroWlu"]=request~expectedMicroWlu
  t["requestedRateMicroWluPerSecond"]=request~requestedRateMicroWluPerSecond
  t["deadlineEpochMs"]=request~deadlineEpochMs
  t["policyTags"]=self~setKeys(request~policyTags)
  r=request~requirement
  rt=.table~new
  rt["jurisdictions"]=self~setKeys(r~jurisdictions)
  rt["legalDomains"]=self~setKeys(r~legalDomains)
  rt["trustDomains"]=self~setKeys(r~trustDomains)
  rt["authorities"]=self~setKeys(r~authorities)
  rt["abilities"]=self~setKeys(r~abilities)
  rt["runtimes"]=self~setKeys(r~runtimes)
  rt["tags"]=self~setKeys(r~tags)
  rt["architecture"]=r~architecture
  rt["minimumMemoryMiB"]=r~minimumMemoryMiB
  rt["minimumDiskMiB"]=r~minimumDiskMiB
  rt["minimumCpuUnits"]=r~minimumCpuUnits
  rt["minimumFreeMemoryMiB"]=r~minimumFreeMemoryMiB
  rt["minimumFreeDiskMiB"]=r~minimumFreeDiskMiB
  rt["minimumAvailableCpuUnits"]=r~minimumAvailableCpuUnits
  rt["minimumAvailableMicroWluPerSecond"]=r~minimumAvailableMicroWluPerSecond
  rt["exactRuntimeGeneration"]=r~exactRuntimeGeneration
  route=r~apiRouteRequirement
  if route<>.nil then do
    q=.table~new
    q["country"]=route~country; q["vpn"]=route~vpn; q["network"]=route~network; q["egressClass"]=route~egressClass
    q["requiredTags"]=self~valuesArray(route~requiredTags)
    rt["apiRouteRequirement"]=q
  end
  t["requirement"]=rt
  return t

::method decodePlacementRequest class
  use strict arg t
  if t==.nil then return .nil
  r=t["requirement"]
  if r==.nil then return .nil
  route=.nil
  q=r["apiRouteRequirement"]
  if q<>.nil then route=.JobNodeNetworkApiRouteRequirement~new(q["country"],q["vpn"],q["network"],q["egressClass"],q["requiredTags"])
  req=.JobNodeRequirement~new(r["jurisdictions"],r["legalDomains"],r["trustDomains"],r["authorities"],r["abilities"],r["runtimes"],r["tags"],r["architecture"],r["minimumMemoryMiB"],r["minimumDiskMiB"],r["minimumCpuUnits"],r["minimumFreeMemoryMiB"],r["minimumFreeDiskMiB"],r["minimumAvailableCpuUnits"],r["minimumAvailableMicroWluPerSecond"],route,r["exactRuntimeGeneration"])
  return .JobPlacementRequest~new(t["jobId"],req,t["ownerNodeId"],t["expectedMicroWlu"],t["requestedRateMicroWluPerSecond"],t["deadlineEpochMs"],t["policyTags"])

::method encodeLease class
  use strict arg lease
  if lease==.nil then return .nil
  t=.table~new
  t["placementId"]=lease~placementId; t["jobId"]=lease~jobId; t["nodeId"]=lease~nodeId; t["ownerNodeId"]=lease~ownerNodeId
  t["capabilityGeneration"]=lease~capabilityGeneration; t["capacityObservationGeneration"]=lease~capacityObservationGeneration
  t["issuedEpochMs"]=lease~issuedEpochMs; t["expiresEpochMs"]=lease~expiresEpochMs
  t["requirementDigest"]=lease~requirementDigest; t["capabilityDigest"]=lease~capabilityDigest; t["capacityDigest"]=lease~capacityDigest
  t["allocationPolicyGeneration"]=lease~allocationPolicyGeneration; t["proofRef"]=lease~proofRef; t["reservationRef"]=lease~reservationRef
  t["signature"]=lease~signature; t["ownershipEpoch"]=lease~ownershipEpoch; t["renewalSequence"]=lease~renewalSequence
  t["supersedesPlacementId"]=lease~supersedesPlacementId
  return t

::method decodeLease class
  use strict arg t
  if t==.nil then return .nil
  return .JobNodePlacementLease~new(t["placementId"],t["jobId"],t["nodeId"],t["ownerNodeId"],t["capabilityGeneration"],t["capacityObservationGeneration"],t["issuedEpochMs"],t["expiresEpochMs"],t["requirementDigest"],t["capabilityDigest"],t["capacityDigest"],t["allocationPolicyGeneration"],t["proofRef"],t["reservationRef"],t["signature"],t["ownershipEpoch"],t["renewalSequence"],t["supersedesPlacementId"])

::method encodeAssessment class
  use strict arg a
  t=.table~new; t["nodeId"]=a~nodeId; t["eligible"]=a~eligible; t["reasons"]=self~copyArray(a~reasons)
  return t

::method encodeDecision class
  use strict arg d
  t=.table~new; t["placed"]=d~placed; t["code"]=d~code; t["selectedScore"]=d~selectedScore; t["lease"]=self~encodeLease(d~lease)
  rows=.array~new
  do a over d~assessments; rows~append(self~encodeAssessment(a)); end
  t["assessments"]=rows
  return t

::method setKeys class private
  use strict arg d
  a=.array~new
  if d==.nil then return a
  do k over d; a~append(k~string); end
  a~sort
  return a
::method valuesArray class private
  use strict arg x
  a=.array~new
  if x==.nil then return a
  do v over x; a~append(v~string); end
  return a
::method copyArray class private
  use strict arg x
  a=.array~new
  if x==.nil then return a
  do v over x; a~append(v~string); end
  return a

::class JobNodeNetworkAccessPolicy public
::method init
  expose grants
  grants=.directory~new
::method grant
  expose grants
  use strict arg clientId, operations, ownerNodeId=""
  row=.table~new; ops=.directory~new
  do op over operations; ops[op~string~upper]=.true; end
  row["ops"]=ops; row["ownerNodeId"]=ownerNodeId~string
  grants[clientId~string~upper]=row
  return self
::method authorised
  expose grants
  use strict arg clientId, operation, placementRequest=.nil
  row=grants[clientId~string~upper]
  if row==.nil then return .false
  if row["ops"]~at(operation~string~upper)==.nil then return .false
  boundOwner=row["ownerNodeId"]
  if boundOwner<>"" & placementRequest<>.nil then if placementRequest~ownerNodeId<>boundOwner then return .false
  return .true

/* Append-only request idempotency ledger.  Response is encoded with Queue
 * graph codec so nested primitive tables/arrays remain exact across restart. */
::class JobNodeNetworkRequestLedger public
::method init
  expose path codec rows
  use arg pathArg="", codecArg=.nil
  path=pathArg~string
  if codecArg==.nil then codec=.QueueGraphPayloadCodec~new; else codec=codecArg
  rows=.directory~new
  if path<>"" then self~load
::method lookup
  expose rows
  use strict arg requestId
  return rows[requestId~string]
::method record
  expose path codec rows
  use strict arg requestId, requestDigest, response
  existing=rows[requestId~string]
  if existing<>.nil then return existing["digest"]=requestDigest
  row=.table~new; row["digest"]=requestDigest; row["response"]=response; rows[requestId~string]=row
  if path<>"" then do
    s=.stream~new(path); s~open("write append")
    enc=codec~encode(response)
    ignore=s~lineout(requestId || "09"x || requestDigest || "09"x || c2x(enc))
    s~close
  end
  return .true
::method load private
  expose path codec rows
  if stream(path,"c","query exists")="" then return
  s=.stream~new(path); s~open("read")
  do while s~lines>0
    line=s~linein
    parse var line requestId "09"x digest "09"x responseHex
    if requestId="" | digest="" | responseHex="" then iterate
    signal on syntax name badRow
    response=codec~decode(x2c(responseHex))
    signal off syntax
    row=.table~new; row["digest"]=digest; row["response"]=response; rows[requestId]=row
  end
  s~close
  return
badRow:
  signal off syntax
  s~close
  raise syntax 88.900 array("invalid JobNode network request ledger row")

::class JobNodeNetworkAllocatorService public
::method init
  expose allocator registry eligibilityPolicy placementPolicy requestManager requestQueue responseFabric responseAliases servicePrincipal accessPolicy ledger digestProvider serverId
  use strict arg allocatorArg, registryArg, eligibilityArg, placementPolicyArg, requestManagerArg, requestQueueArg, responseFabricArg, servicePrincipalArg="jna-service", accessPolicyArg=.nil, ledgerArg=.nil, digestArg=.nil, serverIdArg="ALLOCATOR"
  allocator=allocatorArg; registry=registryArg; eligibilityPolicy=eligibilityArg; placementPolicy=placementPolicyArg
  requestManager=requestManagerArg; requestQueue=requestQueueArg~string; responseFabric=responseFabricArg; servicePrincipal=servicePrincipalArg~string
  if accessPolicyArg==.nil then accessPolicy=.JobNodeNetworkAccessPolicy~new; else accessPolicy=accessPolicyArg
  if ledgerArg==.nil then ledger=.JobNodeNetworkRequestLedger~new; else ledger=ledgerArg
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
  serverId=serverIdArg~string; responseAliases=.directory~new
::method bindClientReply
  expose responseAliases
  use strict arg clientId, remoteQueueAlias
  responseAliases[clientId~string~upper]=remoteQueueAlias~string
  return self
::method processOne
  expose requestManager requestQueue servicePrincipal
  claimed=requestManager~claim(requestQueue,servicePrincipal)
  if \claimed~ok then return claimed
  p=claimed~value; wire=p~payload
  response=self~handle(wire)
  staged=self~stageResponseFromRequest(wire["clientId"],response)
  if \staged~ok then do
    ignore=requestManager~release(requestQueue,p~packageId,p~claimToken,servicePrincipal)
    return staged
  end
  acked=requestManager~ack(requestQueue,p~packageId,p~claimToken,servicePrincipal)
  if \acked~ok then return acked
  return .QueueOperationResult~success(response)
::method handle
  expose allocator registry eligibilityPolicy placementPolicy accessPolicy ledger digestProvider serverId
  use strict arg wire
  if wire==.nil then return self~response("","","INVALID_REQUEST","REQUEST_REQUIRED",.nil,.nil)
  if wire["schema"]<>.JobNodeNetworkBuild~REQUEST_SCHEMA then return self~response(wire["requestId"],wire["operation"],"INVALID_REQUEST","SCHEMA_UNSUPPORTED",.nil,.nil)
  requestId=wire["requestId"]~string; op=wire["operation"]~string~upper; clientId=wire["clientId"]~string
  if requestId="" then return self~response("",op,"INVALID_REQUEST","REQUEST_ID_REQUIRED",.nil,.nil)
  placementRequest=.JobNodeNetworkCodec~decodePlacementRequest(wire["placementRequest"])
  lease=.JobNodeNetworkCodec~decodeLease(wire["lease"])
  canonical=op || "|client=" || clientId || "|now=" || wire["nowEpochMs"] || "|duration=" || wire["leaseDurationMs"]
  if placementRequest<>.nil then canonical=canonical || "|request={" || placementRequest~canonical || "}"
  if lease<>.nil then canonical=canonical || "|lease={" || lease~canonical || "}"
  reqDigest=digestProvider~digest(canonical)
  prior=ledger~lookup(requestId)
  if prior<>.nil then do
    if prior["digest"]<>reqDigest then return self~response(requestId,op,"DENIED","REQUEST_ID_CONFLICT",.nil,reqDigest)
    replay=prior["response"]~copy; replay["replayed"]=.true; return replay
  end
  if \accessPolicy~authorised(clientId,op,placementRequest) then do
    response=self~response(requestId,op,"DENIED","CLIENT_NOT_AUTHORISED",.nil,reqDigest)
    ignore=ledger~record(requestId,reqDigest,response); return response
  end
  now=wire["nowEpochMs"]+0; duration=wire["leaseDurationMs"]+0; if duration<=0 then duration=30000
  select
    when op="PLAN" then do
      if placementRequest==.nil then response=self~response(requestId,op,"INVALID_REQUEST","PLACEMENT_REQUEST_REQUIRED",.nil,reqDigest)
      else response=self~plan(requestId,op,placementRequest,now,reqDigest)
    end
    when op="ALLOCATE" then do
      if placementRequest==.nil then response=self~response(requestId,op,"INVALID_REQUEST","PLACEMENT_REQUEST_REQUIRED",.nil,reqDigest)
      else do; d=allocator~allocate(placementRequest,now,duration); response=self~decisionResponse(requestId,op,d,reqDigest); end
    end
    when op="CHECK" then do
      if placementRequest==.nil | lease==.nil then response=self~response(requestId,op,"INVALID_REQUEST","REQUEST_AND_LEASE_REQUIRED",.nil,reqDigest)
      else do
        valid=allocator~verifyLease(lease,placementRequest,now)
        data=.table~new; data["valid"]=valid; data["lease"]=.JobNodeNetworkCodec~encodeLease(lease)
        if valid then response=self~response(requestId,op,"OK","LEASE_VALID",data,reqDigest)
        else response=self~response(requestId,op,"DENIED","LEASE_INVALID",data,reqDigest)
      end
    end
    when op="RENEW" then do
      if placementRequest==.nil | lease==.nil then response=self~response(requestId,op,"INVALID_REQUEST","REQUEST_AND_LEASE_REQUIRED",.nil,reqDigest)
      else do; d=allocator~renewPlacement(lease,placementRequest,now,duration); response=self~decisionResponse(requestId,op,d,reqDigest); end
    end
    when op="RELEASE" then do
      if lease==.nil then response=self~response(requestId,op,"INVALID_REQUEST","LEASE_REQUIRED",.nil,reqDigest)
      else do
        ok=allocator~releasePlacement(lease); data=.table~new; data["released"]=ok; data["placementId"]=lease~placementId
        if ok then response=self~response(requestId,op,"OK","RELEASED",data,reqDigest)
        else response=self~response(requestId,op,"FAILED","RELEASE_FAILED",data,reqDigest)
      end
    end
    otherwise response=self~response(requestId,op,"INVALID_REQUEST","OPERATION_UNSUPPORTED",.nil,reqDigest)
  end
  if \ledger~record(requestId,reqDigest,response) then return self~response(requestId,op,"FAILED","LEDGER_CONFLICT",.nil,reqDigest)
  return response
::method plan private
  expose registry eligibilityPolicy placementPolicy
  use strict arg requestId, op, placementRequest, now, reqDigest
  rows=.array~new; candidates=.array~new; ids=registry~nodeIds; ids~sort
  do nodeId over ids
    a=eligibilityPolicy~assess(placementRequest,registry~capability(nodeId),registry~capacity(nodeId),now)
    rows~append(.JobNodeNetworkCodec~encodeAssessment(a))
    if a~eligible then candidates~append(.array~of(placementPolicy~score(placementRequest,a),nodeId))
  end
  selected=""; score=0
  do c over candidates
    if selected="" | c[1]>score | (c[1]=score & c[2]<selected) then do; score=c[1]; selected=c[2]; end
  end
  data=.table~new; data["advisory"]=.true; data["selectedNodeId"]=selected; data["selectedScore"]=score; data["assessments"]=rows
  if selected="" then return self~response(requestId,op,"DENIED","NO_ELIGIBLE_NODE",data,reqDigest)
  return self~response(requestId,op,"OK","PLAN_READY",data,reqDigest)
::method decisionResponse private
  use strict arg requestId, op, decision, reqDigest
  data=.JobNodeNetworkCodec~encodeDecision(decision)
  if decision~placed then return self~response(requestId,op,"OK",decision~code,data,reqDigest)
  return self~response(requestId,op,"DENIED",decision~code,data,reqDigest)
::method response private
  expose serverId
  use strict arg requestId, operation, status, code, data=.nil, requestDigest=""
  t=.table~new; t["schema"]=.JobNodeNetworkBuild~RESPONSE_SCHEMA; t["api"]=.JobNodeNetworkBuild~API
  t["requestId"]=requestId~string; t["operation"]=operation~string; t["status"]=status~string; t["code"]=code~string
  t["serverId"]=serverId; t["requestDigest"]=requestDigest~string; t["replayed"]=.false; t["data"]=data
  return t
::method stageResponseFromRequest
  /* exposed for tests / explicit services that separate handle from delivery */
  expose responseFabric responseAliases
  use strict arg clientId, response
  response["clientId"]=clientId
  alias=responseAliases[clientId~string~upper]
  if alias==.nil then return .QueueOperationResult~failure("CLIENT_REPLY_ROUTE_UNBOUND",clientId)
  options=.table~new; options["persistent"]=.true; options["securityDomain"]="JNA"; options["correlationId"]=response["requestId"]
  return responseFabric~put(alias,response,options,"jna-service")

::class JobNodeNetworkAllocatorClient public
::method init
  expose fabric requestAlias replyManager replyQueue clientId principal digestProvider
  use strict arg fabricArg, requestAliasArg, replyManagerArg, replyQueueArg, clientIdArg, principalArg="jna-client", digestArg=.nil
  fabric=fabricArg; requestAlias=requestAliasArg~string; replyManager=replyManagerArg; replyQueue=replyQueueArg~string; clientId=clientIdArg~string; principal=principalArg~string
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
::method submit
  expose fabric requestAlias clientId principal
  use strict arg requestId, operation, placementRequest=.nil, lease=.nil, nowEpochMs=0, leaseDurationMs=30000
  wire=.table~new; wire["schema"]=.JobNodeNetworkBuild~REQUEST_SCHEMA; wire["api"]=.JobNodeNetworkBuild~API
  wire["requestId"]=requestId~string; wire["clientId"]=clientId; wire["operation"]=operation~string~upper
  wire["placementRequest"]=.JobNodeNetworkCodec~encodePlacementRequest(placementRequest); wire["lease"]=.JobNodeNetworkCodec~encodeLease(lease)
  wire["nowEpochMs"]=nowEpochMs+0; wire["leaseDurationMs"]=leaseDurationMs+0
  options=.table~new; options["persistent"]=.true; options["securityDomain"]="JNA"; options["correlationId"]=requestId~string
  return fabric~put(requestAlias,wire,options,principal)
::method receive
  expose replyManager replyQueue principal
  r=replyManager~get(replyQueue,principal)
  if \r~ok then return r
  return .QueueOperationResult~success(r~value~payload)

::requires "JobNodeAllocator.cls"
::requires "ObjectQueueChannels.cls"
