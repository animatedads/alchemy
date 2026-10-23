/* ClusterObjectMemoryFabricTransport.cls
 * Cluster object execution transport over Queue Fabric + Memory Fabric.
 *
 * API: cluster.object.peer/0.2
 *
 * Authority split:
 *   Memory Fabric  owns memory provider/block identity, residency and fencing.
 *   Queue Fabric   owns inter-node object/control transport.
 *   Job-to-Node    remains execution placement/admission authority.
 *   Application objects know nothing about clustering.
 *
 * The transport moves execution state toward resident memory.  A MEMORY_BLOCK
 * argument is a compact fenced reference; payload bytes are never carried by
 * this protocol merely because execution moved.
 */

::class ClusterObjectTransportBuild public
::constant VERSION "0.2"
::constant API "cluster.object.peer/0.2"

::class ClusterObjectContract public
::constant API "cluster.object.peer/0.2"
::constant REQUEST_SCHEMA "cluster.object.peer.request/2"
::constant RESPONSE_SCHEMA "cluster.object.peer.response/2"
::constant ENVELOPE_SCHEMA "cluster.object.envelope/2"
::constant ARG_SCHEMA "cluster.object.arg/2"
::constant MEMORY_REF_SCHEMA "cluster.object.memory-ref/1"
::constant SECURITY_DOMAIN "OBJECT"

::class ClusterObjectOperation public
::constant HELLO "HELLO"
::constant MOVE "MOVE"
::constant CALL "CALL"
::constant SNAPSHOT "SNAPSHOT"

::class ClusterObjectArgKind public
::constant VALUE "VALUE"
::constant MEMORY_BLOCK "MEMORY_BLOCK"

/* ====================================================================== */
::class ClusterObjectCodec public

::method value class
  use strict arg directory,key,defaultValue=""
  if directory==.nil then return defaultValue
  v=directory[key]
  if v==.nil then return defaultValue
  return v

::method whole class
  use strict arg directory,key,defaultValue=0
  v=self~value(directory,key,defaultValue)
  if \datatype(v,"W") then return defaultValue
  return v+0

::method newRequest class
  use strict arg requestId,fromNode,toNode,operation
  d=.directory~new
  d["schema"]=.ClusterObjectContract~REQUEST_SCHEMA
  d["api"]=.ClusterObjectContract~API
  d["request_id"]=requestId~string
  d["from_node"]=fromNode~string
  d["to_node"]=toNode~string
  d["operation"]=operation~string~upper
  return d

::method response class
  use strict arg request,sourceNode,status,code="",payload=.nil
  d=.directory~new
  d["schema"]=.ClusterObjectContract~RESPONSE_SCHEMA
  d["api"]=.ClusterObjectContract~API
  d["request_id"]=self~value(request,"request_id","")
  d["from_node"]=self~value(request,"from_node","")
  d["to_node"]=self~value(request,"to_node","")
  d["source_node"]=sourceNode~string
  d["operation"]=self~value(request,"operation","")
  d["status"]=status~string~upper
  d["code"]=code~string
  if payload<>.nil then d["payload"]=payload
  return d

::method envelope class
  use strict arg objectId,adapterId,generation,state
  d=.directory~new
  d["schema"]=.ClusterObjectContract~ENVELOPE_SCHEMA
  d["object_id"]=objectId~string
  d["adapter_id"]=adapterId~string
  d["generation"]=generation+0
  d["state"]=state
  return d

::method valueArg class
  use strict arg valueArg
  d=.directory~new
  d["schema"]=.ClusterObjectContract~ARG_SCHEMA
  d["kind"]=.ClusterObjectArgKind~VALUE
  d["value"]=valueArg
  return d

::method memoryRef class
  use strict arg fabricId,block
  d=.directory~new
  d["schema"]=.ClusterObjectContract~MEMORY_REF_SCHEMA
  d["fabric_id"]=fabricId~string
  d["block_id"]=block~blockId
  d["generation"]=block~generation
  d["provider_id"]=block~providerId
  d["owner_epoch"]=block~ownerEpoch
  return d

::method memoryBlockArg class
  use strict arg fabricId,block
  d=.directory~new
  d["schema"]=.ClusterObjectContract~ARG_SCHEMA
  d["kind"]=.ClusterObjectArgKind~MEMORY_BLOCK
  d["memory_ref"]=self~memoryRef(fabricId,block)
  return d

::method replaySignature class
  use strict arg request
  op=self~value(request,"operation","")
  objectId=self~value(request,"object_id","")
  env=request["envelope"]
  if objectId="" & env<>.nil then objectId=self~value(env,"object_id","")
  generation=""
  if env<>.nil then generation=self~value(env,"generation","")
  methodName=self~value(request,"method","")
  target=request["memory_target"]
  targetText=""
  if target<>.nil then targetText=self~value(target,"block_id","")||":"||self~value(target,"generation","")||":"||self~value(target,"owner_epoch","")
  return op||"1F"x||objectId||"1F"x||generation||"1F"x||methodName||"1F"x||targetText

/* ====================================================================== */
::class ClusterObjectAdapterRegistry public
::method init
  expose adapters
  adapters=.directory~new
::method register
  expose adapters
  use strict arg adapter
  id=adapter~adapterId~string
  if id="" then raise syntax 88.900 array("cluster object adapter id is required")
  adapters[id]=adapter
  return adapter
::method resolve
  expose adapters
  use strict arg adapterId
  return adapters[adapterId~string]

/* ====================================================================== */
/* Node-local association between a current MemoryFabricBlockRef and the
 * resident application object/data view represented by that block. */
::class ClusterMemoryResidentRegistry public
::method init
  expose resources
  resources=.directory~new
::method key class
  use strict arg blockId,generation,ownerEpoch
  return blockId~string||"/"||generation||"/"||ownerEpoch
::method publish
  expose resources
  use strict arg block,object
  resources[.ClusterMemoryResidentRegistry~key(block~blockId,block~generation,block~ownerEpoch)]=object
  return object
::method resolve
  expose resources
  use strict arg block
  return resources[.ClusterMemoryResidentRegistry~key(block~blockId,block~generation,block~ownerEpoch)]
::method withdraw
  expose resources
  use strict arg block
  return resources~remove(.ClusterMemoryResidentRegistry~key(block~blockId,block~generation,block~ownerEpoch))

/* ====================================================================== */
::class ClusterResidentObject public
::method init
  expose objectId object adapterId generation
  use strict arg objectIdArg,objectArg,adapterIdArg,generationArg
  objectId=objectIdArg~string; object=objectArg; adapterId=adapterIdArg~string; generation=generationArg+0
::attribute objectId get
::attribute object get
::attribute adapterId get
::attribute generation get

/* ====================================================================== */
::class ClusterObjectHost public
::method init
  expose nodeId adapters memoryFabric localProviderIds memoryResidents residents highGeneration
  use strict arg nodeIdArg,adapterRegistryArg,memoryFabricArg,localProviderIdsArg,memoryResidentsArg=.nil
  nodeId=nodeIdArg~string~strip
  if nodeId="" then raise syntax 88.900 array("cluster object host node id is required")
  adapters=adapterRegistryArg
  memoryFabric=memoryFabricArg
  localProviderIds=.directory~new
  do providerId over localProviderIdsArg
    localProviderIds[providerId~string]=.true
  end
  if memoryResidentsArg==.nil then memoryResidents=.ClusterMemoryResidentRegistry~new; else memoryResidents=memoryResidentsArg
  residents=.directory~new
  highGeneration=.directory~new

::attribute nodeId get
::attribute memoryResidents get

::method ownsProvider
  expose localProviderIds
  use strict arg providerId
  return localProviderIds[providerId~string]<>.nil

::method attach
  expose residents highGeneration adapters
  use strict arg objectId,object,adapterId,generation=1
  adapter=adapters~resolve(adapterId)
  if adapter==.nil | generation<1 then return .false
  residents[objectId]=.ClusterResidentObject~new(objectId,object,adapterId,generation)
  previous=highGeneration[objectId]
  if previous==.nil | generation>previous then highGeneration[objectId]=generation
  return .true

::method resident
  expose residents
  use strict arg objectId
  return residents[objectId]

::method snapshot
  expose residents adapters
  use strict arg objectId,generationOverride=.nil
  record=residents[objectId]
  if record==.nil then return .nil
  adapter=adapters~resolve(record~adapterId)
  if adapter==.nil then return .nil
  state=adapter~capture(record~object)
  if state==.nil then return .nil
  generation=record~generation
  if generationOverride<>.nil then generation=generationOverride+0
  return .ClusterObjectCodec~envelope(objectId,record~adapterId,generation,state)

::method acceptEnvelope
  expose residents highGeneration adapters
  use strict arg envelope
  if envelope==.nil | \envelope~isA(.Directory) then return "ENVELOPE_INVALID"
  if .ClusterObjectCodec~value(envelope,"schema","")<>.ClusterObjectContract~ENVELOPE_SCHEMA then return "ENVELOPE_SCHEMA_INVALID"
  objectId=.ClusterObjectCodec~value(envelope,"object_id","")~string~strip
  adapterId=.ClusterObjectCodec~value(envelope,"adapter_id","")~string~strip
  generation=.ClusterObjectCodec~whole(envelope,"generation",0)
  state=envelope["state"]
  if objectId="" | adapterId="" | generation<1 | state==.nil then return "ENVELOPE_FIELDS_INVALID"
  previous=highGeneration[objectId]
  if previous<>.nil then if generation<=previous then return "STALE_GENERATION"
  adapter=adapters~resolve(adapterId)
  if adapter==.nil then return "ADAPTER_NOT_FOUND"
  object=adapter~restore(state)
  if object==.nil then return "RESTORE_FAILED"
  residents[objectId]=.ClusterResidentObject~new(objectId,object,adapterId,generation)
  highGeneration[objectId]=generation
  return "ACCEPTED"

::method remove
  expose residents
  use strict arg objectId,expectedGeneration=.nil
  record=residents[objectId]
  if record==.nil then return .nil
  if expectedGeneration<>.nil then if record~generation<>expectedGeneration then return .nil
  return residents~remove(objectId)

::method validateMemoryRef
  expose memoryFabric
  use strict arg memoryRef
  if memoryRef==.nil | \memoryRef~isA(.Directory) then return .nil
  if .ClusterObjectCodec~value(memoryRef,"schema","")<>.ClusterObjectContract~MEMORY_REF_SCHEMA then return .nil
  if .ClusterObjectCodec~value(memoryRef,"fabric_id","")<>memoryFabric~fabricId then return .nil
  blockId=.ClusterObjectCodec~value(memoryRef,"block_id","")
  generation=.ClusterObjectCodec~whole(memoryRef,"generation",0)
  providerId=.ClusterObjectCodec~value(memoryRef,"provider_id","")
  ownerEpoch=.ClusterObjectCodec~whole(memoryRef,"owner_epoch",0)
  block=memoryFabric~resolveBlock(blockId,generation)
  if block==.nil then return .nil
  if block~providerId<>providerId | block~ownerEpoch<>ownerEpoch then return .nil
  return block

::method validateMemoryTarget
  use strict arg memoryRef
  block=self~validateMemoryRef(memoryRef)
  if block==.nil then return "MEMORY_TARGET_STALE"
  if \self~ownsProvider(block~providerId) then return "MEMORY_TARGET_NOT_LOCAL"
  return "OK"

::method resolveArguments
  expose memoryResidents
  use strict arg argSpecs
  args=.array~new
  if argSpecs==.nil then return args
  do spec over argSpecs
    if spec==.nil | \spec~isA(.Directory) then return .nil
    if .ClusterObjectCodec~value(spec,"schema","")<>.ClusterObjectContract~ARG_SCHEMA then return .nil
    kind=.ClusterObjectCodec~value(spec,"kind","")~upper
    if kind=.ClusterObjectArgKind~VALUE then args~append(spec["value"])
    else if kind=.ClusterObjectArgKind~MEMORY_BLOCK then do
      block=self~validateMemoryRef(spec["memory_ref"])
      if block==.nil then return .nil
      if \self~ownsProvider(block~providerId) then return .nil
      localObject=memoryResidents~resolve(block)
      if localObject==.nil then return .nil
      args~append(localObject)
    end
    else return .nil
  end
  return args

::method invoke
  expose residents
  use strict arg objectId,methodName,argSpecs=.nil
  record=residents[objectId]
  if record==.nil then return .ClusterInvocationResult~failure("OBJECT_NOT_RESIDENT")
  args=self~resolveArguments(argSpecs)
  if args==.nil then return .ClusterInvocationResult~failure("ARGUMENT_RESOLUTION_FAILED")
  signal on syntax name invokeFailed
  callMessage=.message~new(record~object,methodName,"a",args)
  returnedValue=callMessage~send
  signal off syntax
  return .ClusterInvocationResult~success(returnedValue,record~generation)
invokeFailed:
  signal off syntax
  conditionObject=condition("O")
  detail=""
  if conditionObject<>.nil then detail=conditionObject~string
  return .ClusterInvocationResult~failure("OBJECT_METHOD_FAILED",detail)

/* ====================================================================== */
::class ClusterInvocationResult public
::method init
  expose ok code detail value generation
  use strict arg okArg,codeArg,detailArg="",valueArg=.nil,generationArg=0
  ok=(okArg==.true); code=codeArg~string; detail=detailArg~string; value=valueArg; generation=generationArg+0
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::attribute generation get
::method success class
  use strict arg valueArg,generationArg
  return self~new(.true,"OK","",valueArg,generationArg)
::method failure class
  use strict arg codeArg,detailArg=""
  return self~new(.false,codeArg,detailArg)

/* ====================================================================== */
::class ClusterObjectPeerService public
::method init
  expose nodeId host replayResponses replaySignatures
  use strict arg nodeIdArg,hostArg
  nodeId=nodeIdArg~string~strip; host=hostArg
  replayResponses=.directory~new; replaySignatures=.directory~new

::method handle
  expose nodeId host replayResponses replaySignatures
  use strict arg request
  if request==.nil | \request~isA(.Directory) then return .ClusterObjectCodec~response(.directory~new,nodeId,"ERROR","REQUEST_INVALID")
  if .ClusterObjectCodec~value(request,"schema","")<>.ClusterObjectContract~REQUEST_SCHEMA | .ClusterObjectCodec~value(request,"api","")<>.ClusterObjectContract~API then return .ClusterObjectCodec~response(request,nodeId,"ERROR","CONTRACT_MISMATCH")
  if .ClusterObjectCodec~value(request,"to_node","")<>nodeId then return .ClusterObjectCodec~response(request,nodeId,"ERROR","DESTINATION_MISMATCH")
  requestId=.ClusterObjectCodec~value(request,"request_id","")~string~strip
  fromNode=.ClusterObjectCodec~value(request,"from_node","")~string~strip
  if requestId="" | fromNode="" then return .ClusterObjectCodec~response(request,nodeId,"ERROR","IDENTITY_REQUIRED")
  signature=.ClusterObjectCodec~replaySignature(request)
  oldResponse=replayResponses[requestId]
  if oldResponse<>.nil then do
    if replaySignatures[requestId]<>signature then return .ClusterObjectCodec~response(request,nodeId,"ERROR","REQUEST_ID_CONFLICT")
    return oldResponse
  end
  operation=.ClusterObjectCodec~value(request,"operation","")~upper
  if operation=.ClusterObjectOperation~HELLO then do
    payload=.directory~new; payload["node_id"]=nodeId; payload["api"]=.ClusterObjectContract~API; payload["memory_api"]=.MemoryFabricBuild~API
    answer=.ClusterObjectCodec~response(request,nodeId,"OK","HELLO",payload)
  end
  else if operation=.ClusterObjectOperation~MOVE then do
    targetCode=host~validateMemoryTarget(request["memory_target"])
    if targetCode<>"OK" then answer=.ClusterObjectCodec~response(request,nodeId,"ERROR",targetCode)
    else do
      code=host~acceptEnvelope(request["envelope"])
      if code="ACCEPTED" then do
        env=request["envelope"]
        payload=.directory~new
        payload["object_id"]=.ClusterObjectCodec~value(env,"object_id","")
        payload["generation"]=.ClusterObjectCodec~whole(env,"generation",0)
        payload["owner_node"]=nodeId
        payload["memory_target"]=request["memory_target"]
        answer=.ClusterObjectCodec~response(request,nodeId,"OK","MOVE_ACCEPTED",payload)
      end
      else answer=.ClusterObjectCodec~response(request,nodeId,"ERROR",code)
    end
  end
  else if operation=.ClusterObjectOperation~CALL then do
    objectId=.ClusterObjectCodec~value(request,"object_id","")
    methodName=.ClusterObjectCodec~value(request,"method","")
    invocation=host~invoke(objectId,methodName,request["args"])
    if invocation~ok then do
      payload=.directory~new; payload["object_id"]=objectId; payload["generation"]=invocation~generation; payload["value"]=invocation~value
      answer=.ClusterObjectCodec~response(request,nodeId,"OK","CALL_COMPLETED",payload)
    end
    else answer=.ClusterObjectCodec~response(request,nodeId,"ERROR",invocation~code)
  end
  else if operation=.ClusterObjectOperation~SNAPSHOT then do
    objectId=.ClusterObjectCodec~value(request,"object_id","")
    env=host~snapshot(objectId)
    if env==.nil then answer=.ClusterObjectCodec~response(request,nodeId,"ERROR","OBJECT_NOT_RESIDENT")
    else answer=.ClusterObjectCodec~response(request,nodeId,"OK","SNAPSHOT",env)
  end
  else answer=.ClusterObjectCodec~response(request,nodeId,"ERROR","OPERATION_UNSUPPORTED")
  replaySignatures[requestId]=signature; replayResponses[requestId]=answer
  return answer

::method handleFrom
  expose nodeId
  use strict arg authenticatedPeerNodeId,request
  peer=authenticatedPeerNodeId~string~strip
  if peer="" then return .ClusterObjectCodec~response(request,nodeId,"ERROR","AUTHENTICATED_PEER_REQUIRED")
  if .ClusterObjectCodec~value(request,"from_node","")<>peer then return .ClusterObjectCodec~response(request,nodeId,"ERROR","PEER_IDENTITY_MISMATCH")
  return self~handle(request)

/* ====================================================================== */
::class ClusterObjectPeerClient public
::method init
  expose localNodeId transport counter
  use strict arg localNodeArg,transportArg
  localNodeId=localNodeArg~string~strip; transport=transportArg; counter=0
::method nextRequestId private
  expose localNodeId counter
  counter+=1
  return "cluster-object-"||localNodeId||"-"||counter||"-"||time("F")
::method call private
  expose localNodeId transport
  use strict arg peerNodeId,operation,requestMutator=.nil,fixedRequestId=""
  requestId=fixedRequestId~string
  if requestId="" then requestId=self~nextRequestId
  request=.ClusterObjectCodec~newRequest(requestId,localNodeId,peerNodeId,operation)
  if requestMutator<>.nil then requestMutator~apply(request)
  response=transport~request(peerNodeId,request)
  if response==.nil | \response~isA(.Directory) then return .nil
  if .ClusterObjectCodec~value(response,"schema","")<>.ClusterObjectContract~RESPONSE_SCHEMA | .ClusterObjectCodec~value(response,"api","")<>.ClusterObjectContract~API then return .nil
  if .ClusterObjectCodec~value(response,"request_id","")<>requestId then return .nil
  if .ClusterObjectCodec~value(response,"source_node","")<>peerNodeId~string then return .nil
  if .ClusterObjectCodec~value(response,"from_node","")<>localNodeId then return .nil
  return response
::method move
  use strict arg peerNodeId,envelope,memoryTarget,fixedRequestId=""
  return self~call(peerNodeId,.ClusterObjectOperation~MOVE,.ClusterMoveRequestMutator~new(envelope,memoryTarget),fixedRequestId)
::method invoke
  use strict arg peerNodeId,objectId,methodName,argSpecs=.nil
  return self~call(peerNodeId,.ClusterObjectOperation~CALL,.ClusterCallRequestMutator~new(objectId,methodName,argSpecs))

::class ClusterMoveRequestMutator public
::method init
  expose envelope memoryTarget
  use strict arg envelopeArg,memoryTargetArg
  envelope=envelopeArg; memoryTarget=memoryTargetArg
::method apply
  expose envelope memoryTarget
  use strict arg request
  request["envelope"]=envelope; request["memory_target"]=memoryTarget

::class ClusterCallRequestMutator public
::method init
  expose objectId methodName argSpecs
  use strict arg objectIdArg,methodNameArg,argSpecsArg=.nil
  objectId=objectIdArg~string; methodName=methodNameArg~string; argSpecs=argSpecsArg
::method apply
  expose objectId methodName argSpecs
  use strict arg request
  request["object_id"]=objectId; request["method"]=methodName
  if argSpecs<>.nil then request["args"]=argSpecs

/* ====================================================================== */
::class ClusterObjectMoveCoordinator public
::method init
  expose localHost client moveCounter
  use strict arg localHostArg,clientArg
  localHost=localHostArg; client=clientArg; moveCounter=0
::method moveToBlock
  expose localHost client moveCounter
  use strict arg objectId,destinationNode,memoryBlock,fabricId
  record=localHost~resident(objectId)
  if record==.nil then return .ClusterMoveResult~failure("OBJECT_NOT_RESIDENT")
  nextGeneration=record~generation+1
  envelope=localHost~snapshot(objectId,nextGeneration)
  if envelope==.nil then return .ClusterMoveResult~failure("SNAPSHOT_FAILED")
  memoryTarget=.ClusterObjectCodec~memoryRef(fabricId,memoryBlock)
  moveCounter+=1
  moveId="move-"||localHost~nodeId||"-"||objectId||"-"||nextGeneration||"-"||moveCounter
  response=client~move(destinationNode,envelope,memoryTarget,moveId)
  if response==.nil then return .ClusterMoveResult~failure("MOVE_UNCERTAIN")
  if .ClusterObjectCodec~value(response,"status","")<>"OK" then return .ClusterMoveResult~failure(.ClusterObjectCodec~value(response,"code","MOVE_FAILED"))
  payload=response["payload"]
  if payload==.nil then return .ClusterMoveResult~failure("MOVE_RESPONSE_INVALID")
  if .ClusterObjectCodec~value(payload,"object_id","")<>objectId | .ClusterObjectCodec~whole(payload,"generation",0)<>nextGeneration then return .ClusterMoveResult~failure("MOVE_RESPONSE_INVALID")
  removed=localHost~remove(objectId,record~generation)
  if removed==.nil then return .ClusterMoveResult~failure("LOCAL_RELEASE_FAILED")
  return .ClusterMoveResult~success(objectId,destinationNode,nextGeneration)

::class ClusterMoveResult public
::method init
  expose ok code objectId ownerNode generation
  use strict arg okArg,codeArg,objectIdArg="",ownerNodeArg="",generationArg=0
  ok=(okArg==.true); code=codeArg~string; objectId=objectIdArg~string; ownerNode=ownerNodeArg~string; generation=generationArg+0
::attribute ok get
::attribute code get
::attribute objectId get
::attribute ownerNode get
::attribute generation get
::method success class
  use strict arg objectId,ownerNode,generation
  return self~new(.true,"OK",objectId,ownerNode,generation)
::method failure class
  use strict arg code
  return self~new(.false,code)

/* ====================================================================== */
/* Direct Queue Fabric request/reply binding.  Carrier is supplied by
 * QueueChannelFabric (in-process for qualification, XTP in deployed Grid).
 */
::class ClusterObjectQueueFabricClientTransport public
::method init
  expose channels manager requestAlias requestChannel replyQueue admin localPrincipal timeoutMs
  use strict arg channelsArg,requestAliasArg,requestChannelArg,replyQueueArg,principalArg,timeoutArg=10000
  channels=channelsArg; manager=channels~queueManager; admin=channels~adminPrincipal
  requestAlias=requestAliasArg~string; requestChannel=requestChannelArg~string; replyQueue=replyQueueArg~string; localPrincipal=principalArg~string; timeoutMs=timeoutArg+0
::method request
  expose channels manager requestAlias requestChannel replyQueue admin localPrincipal timeoutMs
  use strict arg peerNodeId,request
  options=.table~new; options["persistent"]=.false; options["securityDomain"]=.ClusterObjectContract~SECURITY_DOMAIN; options["correlationId"]=.ClusterObjectCodec~value(request,"request_id","")
  transportOutcome=channels~put(requestAlias,request,options,localPrincipal)
  if \transportOutcome~ok then return .nil
  transportOutcome=channels~pump(requestChannel,1,admin)
  if \transportOutcome~ok then return .nil
  loops=timeoutMs%10; if loops<1 then loops=1
  do i=1 to loops
    got=manager~get(replyQueue,localPrincipal)
    if got~ok then return got~value~payload
    if got~code<>"QUEUE_EMPTY" then return .nil
    call SysSleep 0.01
  end
  return .nil

::class ClusterObjectQueueFabricServer public
::method init
  expose service expectedPeerNodeId requestQueue replyAlias replyChannel servicePrincipal manager channels admin waitMs
  use strict arg channelsArg,expectedPeerArg,serviceArg,requestQueueArg,replyAliasArg,replyChannelArg,principalArg,waitArg=5000
  channels=channelsArg; manager=channels~queueManager; admin=channels~adminPrincipal
  expectedPeerNodeId=expectedPeerArg~string; service=serviceArg; requestQueue=requestQueueArg~string; replyAlias=replyAliasArg~string; replyChannel=replyChannelArg~string; servicePrincipal=principalArg~string; waitMs=waitArg+0
::method processOne
  expose service expectedPeerNodeId requestQueue replyAlias replyChannel servicePrincipal manager channels admin waitMs
  loops=waitMs%10; if loops<1 then loops=1
  got=.nil
  do i=1 to loops
    got=manager~get(requestQueue,servicePrincipal)
    if got~ok then leave
    if got~code<>"QUEUE_EMPTY" then return .ClusterObjectBindingResult~failure(got~code,got~detail)
    call SysSleep 0.01
  end
  if got==.nil | \got~ok then return .ClusterObjectBindingResult~failure("REQUEST_TIMEOUT")
  response=service~handleFrom(expectedPeerNodeId,got~value~payload)
  options=.table~new; options["persistent"]=.false; options["securityDomain"]=.ClusterObjectContract~SECURITY_DOMAIN; options["correlationId"]=.ClusterObjectCodec~value(response,"request_id","")
  transportOutcome=channels~put(replyAlias,response,options,servicePrincipal)
  if \transportOutcome~ok then return .ClusterObjectBindingResult~failure(transportOutcome~code,transportOutcome~detail)
  transportOutcome=channels~pump(replyChannel,1,admin)
  if \transportOutcome~ok then return .ClusterObjectBindingResult~failure(transportOutcome~code,transportOutcome~detail)
  return .ClusterObjectBindingResult~success(response)

::class ClusterObjectBindingResult public
::method init
  expose ok code detail value
  use strict arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=(okArg==.true); code=codeArg~string; detail=detailArg~string; value=valueArg
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method success class
  use strict arg valueArg
  return self~new(.true,"OK","",valueArg)
::method failure class
  use strict arg codeArg,detailArg=""
  return self~new(.false,codeArg,detailArg)

::requires "MemoryFabric.cls"
