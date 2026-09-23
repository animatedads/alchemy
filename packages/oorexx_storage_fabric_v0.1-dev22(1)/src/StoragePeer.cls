/* ooRexx Storage Fabric peer/object transfer seam.
 *
 * API storage.fabric.peer/0.1
 *
 * The peer protocol transports Storage identity and bounded immutable bytes.
 * A remote HAVE/STAT response is evidence only.  A destination may admit a
 * peer replica only after it has independently verified the complete bytes
 * against the pinned StorageRef digest.
 *
 * The protocol is transport-neutral.  StoragePeerQueueRexxBinding below is a
 * thin optional adapter for QueueRexx~bindServiceRoute() / Queue Fabric.  This
 * package deliberately does not ::requires QueueRexx or Queue Fabric, so the
 * Storage core remains independently loadable.
 */

::class StoragePeerBuild public
::constant VERSION "0.1-dev13"
::constant API "storage.fabric.peer/0.1"

::class StoragePeerContract public
::constant API "storage.fabric.peer/0.1"
::constant REQUEST_SCHEMA "storage.fabric.peer.request/1"
::constant RESPONSE_SCHEMA "storage.fabric.peer.response/1"
::constant SECURITY_DOMAIN "STORAGE"
::constant MAX_READ_BYTES 1048576

::class StoragePeerOperation public
::constant HELLO "HELLO"
::constant HAVE "HAVE"
::constant STAT "STAT"
::constant READ "READ"

::class StoragePeerDisposition public
::constant AVAILABLE "AVAILABLE"
::constant NOT_PRESENT "NOT_PRESENT"
::constant OFFLINE "OFFLINE"
::constant UNVERIFIED "UNVERIFIED"

::class StoragePeerCodec public
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
::method refDirectory class
  use strict arg ref
  d=.directory~new
  d["object_id"]=ref~objectId
  d["digest"]=ref~digest
  return d
::method refFromDirectory class
  use strict arg d
  if d==.nil | \d~isA(.Directory) then return .nil
  objectId=self~value(d,"object_id","")~string~strip
  digest=self~value(d,"digest","")~string~strip
  if objectId="" then return .nil
  return .StorageRef~new(objectId,digest)
::method refKey class
  use strict arg ref
  return ref~objectId||"1F"x||ref~digest
::method normaliseSha256 class
  use strict arg digestArg
  d=digestArg~string~strip~lower
  if left(d,7)="sha256:" then d=substr(d,8)
  if length(d)<>64 then return ""
  do i=1 to 64
    c=substr(d,i,1)
    if pos(c,"0123456789abcdef")=0 then return ""
  end
  return d
::method newRequest class
  use strict arg requestId,fromNode,toNode,operation,ref=.nil,offset=0,maxBytes=0
  d=.directory~new
  d["schema"]=.StoragePeerContract~REQUEST_SCHEMA
  d["api"]=.StoragePeerContract~API
  d["request_id"]=requestId~string
  d["from_node"]=fromNode~string
  d["to_node"]=toNode~string
  d["operation"]=operation~string~upper
  if ref<>.nil then d["ref"]=self~refDirectory(ref)
  if operation~string~upper=.StoragePeerOperation~READ then do
    d["offset"]=offset+0
    d["max_bytes"]=maxBytes+0
  end
  return d
::method response class
  use strict arg request,sourceNode,status,code="",payload=.nil
  d=.directory~new
  d["schema"]=.StoragePeerContract~RESPONSE_SCHEMA
  d["api"]=.StoragePeerContract~API
  d["request_id"]=self~value(request,"request_id","")
  d["from_node"]=self~value(request,"from_node","")
  d["to_node"]=self~value(request,"to_node","")
  d["source_node"]=sourceNode~string
  d["operation"]=self~value(request,"operation","")
  d["status"]=status~string~upper
  d["code"]=code~string
  if payload<>.nil then d["payload"]=payload
  return d

/* One immutable export.  The source factory must return a fresh object
 * implementing StorageByteSource for every range request. */
::class StoragePeerExport public
::attribute ref get
::attribute sizeBytes get
::attribute mediaType get
::attribute sourceFactory get
::attribute disposition get
::method init
  expose ref sizeBytes mediaType sourceFactory disposition
  use strict arg refArg,sizeArg,sourceFactoryArg,mediaArg="application/octet-stream",dispositionArg="AVAILABLE"
  ref=refArg; sizeBytes=sizeArg+0; sourceFactory=sourceFactoryArg; mediaType=mediaArg~string; disposition=dispositionArg~string~upper
  if ref==.nil | sourceFactory==.nil | sizeBytes<0 then raise syntax 88.900 array("invalid Storage peer export")
::method source
  expose sourceFactory
  if sourceFactory~hasMethod("NEWSOURCE") then return sourceFactory~newSource
  if sourceFactory~hasMethod("CALL") then return sourceFactory~call
  raise syntax 88.900 array("Storage peer source factory must implement newSource/call")

::class StoragePeerLocalFileSourceFactory public
::method init
  expose path
  use strict arg pathArg
  path=pathArg~string
::method newSource
  expose path
  return .StorageLocalFileByteSource~new(path)

::class StoragePeerExportRegistry public
::method init
  expose exports
  exports=.directory~new
::method publish
  expose exports
  use strict arg export
  exports[.StoragePeerCodec~refKey(export~ref)]=export
  return export
::method withdraw
  expose exports
  use strict arg ref
  return exports~remove(.StoragePeerCodec~refKey(ref))
::method resolve
  expose exports
  use strict arg ref
  return exports[.StoragePeerCodec~refKey(ref)]
::method count
  expose exports
  return exports~items

::class StoragePeerService public
::attribute nodeId get
::attribute registry get
::method init
  expose nodeId registry maximumReadBytes
  use strict arg nodeArg,registryArg=.nil,maximumReadArg=1048576
  nodeId=nodeArg~string~strip
  if registryArg==.nil then registry=.StoragePeerExportRegistry~new; else registry=registryArg
  maximumReadBytes=maximumReadArg+0
  if nodeId="" | maximumReadBytes<1 then raise syntax 88.900 array("invalid Storage peer service")
::method handle
  expose nodeId registry maximumReadBytes
  use strict arg request
  if request==.nil | \request~isA(.Directory) then return .StoragePeerCodec~response(.directory~new,nodeId,"ERROR","REQUEST_INVALID")
  if .StoragePeerCodec~value(request,"schema","")<>.StoragePeerContract~REQUEST_SCHEMA | .StoragePeerCodec~value(request,"api","")<>.StoragePeerContract~API then return .StoragePeerCodec~response(request,nodeId,"ERROR","CONTRACT_MISMATCH")
  if .StoragePeerCodec~value(request,"to_node","")<>nodeId then return .StoragePeerCodec~response(request,nodeId,"ERROR","DESTINATION_MISMATCH")
  if .StoragePeerCodec~value(request,"from_node","")="" | .StoragePeerCodec~value(request,"request_id","")="" then return .StoragePeerCodec~response(request,nodeId,"ERROR","IDENTITY_REQUIRED")
  op=.StoragePeerCodec~value(request,"operation","")~upper
  if op=.StoragePeerOperation~HELLO then do
    p=.directory~new; p["node_id"]=nodeId; p["api"]=.StoragePeerContract~API; p["max_read_bytes"]=maximumReadBytes
    return .StoragePeerCodec~response(request,nodeId,"OK","HELLO",p)
  end
  ref=.StoragePeerCodec~refFromDirectory(request["ref"])
  if ref==.nil then return .StoragePeerCodec~response(request,nodeId,"ERROR","REF_REQUIRED")
  export=registry~resolve(ref)
  if op=.StoragePeerOperation~HAVE then do
    p=.directory~new; p["ref"]=.StoragePeerCodec~refDirectory(ref)
    if export==.nil then p["disposition"]=.StoragePeerDisposition~NOT_PRESENT
    else p["disposition"]=export~disposition
    return .StoragePeerCodec~response(request,nodeId,"OK","HAVE",p)
  end
  if export==.nil then return .StoragePeerCodec~response(request,nodeId,"ERROR","NOT_PRESENT")
  if export~disposition<>.StoragePeerDisposition~AVAILABLE then return .StoragePeerCodec~response(request,nodeId,"ERROR",export~disposition)
  if op=.StoragePeerOperation~STAT then do
    p=.directory~new; p["ref"]=.StoragePeerCodec~refDirectory(export~ref); p["size_bytes"]=export~sizeBytes; p["media_type"]=export~mediaType; p["disposition"]=export~disposition
    return .StoragePeerCodec~response(request,nodeId,"OK","STAT",p)
  end
  if op=.StoragePeerOperation~READ then return self~handleRead(request,export,maximumReadBytes,nodeId)
  return .StoragePeerCodec~response(request,nodeId,"ERROR","OPERATION_UNSUPPORTED")

/* Authenticated transports must bind their authenticated peer identity to the
 * claimed from_node.  handle() remains available for in-process/local use; a
 * network adapter must use handleFrom(). */
::method handleFrom
  expose nodeId
  use strict arg authenticatedPeerNodeId,request
  peer=authenticatedPeerNodeId~string~strip
  if peer="" then return .StoragePeerCodec~response(request,nodeId,"ERROR","AUTHENTICATED_PEER_REQUIRED")
  if .StoragePeerCodec~value(request,"from_node","")<>peer then return .StoragePeerCodec~response(request,nodeId,"ERROR","PEER_IDENTITY_MISMATCH")
  return self~handle(request)

::method handleRead private
  use strict arg request,export,maximumReadBytes,nodeId
  source=.nil
  offset=.StoragePeerCodec~whole(request,"offset",-1); want=.StoragePeerCodec~whole(request,"max_bytes",-1)
  if offset<0 | want<1 | want>maximumReadBytes then return .StoragePeerCodec~response(request,nodeId,"ERROR","READ_RANGE_INVALID")
  if offset>export~sizeBytes then return .StoragePeerCodec~response(request,nodeId,"ERROR","READ_RANGE_INVALID")
  remaining=export~sizeBytes-offset; if want>remaining then want=remaining
  signal on syntax name sourceFailed
  source=export~source
  source~openAt(offset)
  if want=0 then chunk=.StorageByteChunk~new(offset,"",.true)
  else chunk=source~readChunk(want)
  source~close
  signal off syntax
  if chunk==.nil | chunk~offset<>offset | chunk~data~length>want then return .StoragePeerCodec~response(request,nodeId,"ERROR","SOURCE_PROTOCOL_INVALID")
  p=.directory~new; p["ref"]=.StoragePeerCodec~refDirectory(export~ref); p["offset"]=offset; p["data_hex"]=c2x(chunk~data); p["eof"]=chunk~eof; p["size_bytes"]=export~sizeBytes
  return .StoragePeerCodec~response(request,nodeId,"OK","READ",p)
sourceFailed:
  signal off syntax
  if source<>.nil then source~close
  return .StoragePeerCodec~response(request,nodeId,"ERROR","SOURCE_READ_FAILED")

/* Transport contract: request(peerNodeId, requestDirectory) -> responseDirectory
 * or .nil on transport failure. */
::class StoragePeerClient public
::attribute localNodeId get
::method init
  expose localNodeId transport counter
  use strict arg localNodeArg,transportArg
  localNodeId=localNodeArg~string~strip; transport=transportArg; counter=0
  if localNodeId="" | transport==.nil then raise syntax 88.900 array("Storage peer client requires local node and transport")
::method call private
  expose localNodeId transport counter
  use strict arg peerNodeId,operation,ref=.nil,offset=0,maxBytes=0
  counter+=1
  requestId="storage-peer-"||localNodeId||"-"||counter||"-"||time("F")
  request=.StoragePeerCodec~newRequest(requestId,localNodeId,peerNodeId,operation,ref,offset,maxBytes)
  response=transport~request(peerNodeId,request)
  if response==.nil | \response~isA(.Directory) then return .nil
  if .StoragePeerCodec~value(response,"schema","")<>.StoragePeerContract~RESPONSE_SCHEMA | .StoragePeerCodec~value(response,"api","")<>.StoragePeerContract~API then return .nil
  if .StoragePeerCodec~value(response,"request_id","")<>requestId then return .nil
  if .StoragePeerCodec~value(response,"source_node","")<>peerNodeId~string then return .nil
  if .StoragePeerCodec~value(response,"from_node","")<>localNodeId then return .nil
  return response
::method hello
  use strict arg peerNodeId
  return self~call(peerNodeId,.StoragePeerOperation~HELLO)
::method have
  use strict arg peerNodeId,ref
  return self~call(peerNodeId,.StoragePeerOperation~HAVE,ref)
::method stat
  use strict arg peerNodeId,ref
  return self~call(peerNodeId,.StoragePeerOperation~STAT,ref)
::method read
  use strict arg peerNodeId,ref,offset,maxBytes
  return self~call(peerNodeId,.StoragePeerOperation~READ,ref,offset,maxBytes)

::class StoragePeerInProcessTransport public
::method init
  expose services
  services=.directory~new
::method bind
  expose services
  use strict arg nodeId,service
  services[nodeId~string]=service; return self
::method request
  expose services
  use strict arg peerNodeId,request
  service=services[peerNodeId~string]
  if service==.nil then return .nil
  return service~handle(request)

/* Bounded remote byte source.  Each read is an independent peer READ request;
 * transport retries may therefore resume exactly at the acknowledged offset. */
::class StoragePeerByteSource subclass StorageByteSource public
::attribute sizeBytes get
::attribute position get
::attribute opened get
::method init
  expose client peerNodeId ref sizeBytes position opened chunkLimit
  use strict arg clientArg,peerArg,refArg,chunkArg=262144
  client=clientArg; peerNodeId=peerArg~string; ref=refArg; chunkLimit=chunkArg+0; position=0; opened=.false
  stat=client~stat(peerNodeId,ref)
  if stat==.nil | .StoragePeerCodec~value(stat,"status","")<>"OK" then raise syntax 88.900 array("remote StorageRef STAT failed",ref~objectId)
  p=stat["payload"]; sizeBytes=.StoragePeerCodec~whole(p,"size_bytes",-1)
  if sizeBytes<0 | chunkLimit<1 | chunkLimit>.StoragePeerContract~MAX_READ_BYTES then raise syntax 88.900 array("invalid peer byte source")
::method resumeIdentity
  expose peerNodeId ref sizeBytes
  return "STORAGE_PEER_SOURCE|"||peerNodeId||"|"||ref~objectId||"|"||ref~digest||"|"||sizeBytes
::method openAt
  expose sizeBytes position opened
  use strict arg offsetArg=0
  offset=offsetArg+0
  if offset<0 | offset>sizeBytes then raise syntax 88.900 array("peer source offset outside object",offset,sizeBytes)
  position=offset; opened=.true; return self
::method readChunk
  expose client peerNodeId ref sizeBytes position opened chunkLimit
  use strict arg maximumArg
  if \opened then raise syntax 88.900 array("peer source is not open")
  maximum=maximumArg+0
  if maximum<1 then raise syntax 88.900 array("peer chunk size must be positive")
  if position>=sizeBytes then return .StorageByteChunk~new(position,"",.true)
  want=min(maximum,chunkLimit,sizeBytes-position)
  response=client~read(peerNodeId,ref,position,want)
  if response==.nil | .StoragePeerCodec~value(response,"status","")<>"OK" then raise syntax 88.900 array("peer READ failed",peerNodeId,position,want)
  p=response["payload"]; off=.StoragePeerCodec~whole(p,"offset",-1); hex=.StoragePeerCodec~value(p,"data_hex","")
  if off<>position | length(hex)//2<>0 then raise syntax 88.900 array("peer READ response invalid")
  data=x2c(hex); if data~length>want then raise syntax 88.900 array("peer READ exceeded requested range")
  start=position; position+=data~length
  if data~length=0 & position<sizeBytes then raise syntax 88.900 array("peer READ made no progress")
  return .StorageByteChunk~new(start,data,position>=sizeBytes)
::method close
  expose opened
  opened=.false; return self

/* Verified materialisation is the admission boundary.  A peer claim is never
 * sufficient.  Only the independently calculated SHA-256 of complete bytes
 * may satisfy a SHA-256 StorageRef digest. */
::class StoragePeerMaterialiser public
::method init
  expose chunkBytes verifier
  use strict arg chunkArg=262144,verifierArg=.nil
  chunkBytes=chunkArg+0
  if verifierArg==.nil then verifier=.StoragePosixSha256Verifier~new; else verifier=verifierArg
  if chunkBytes<1 then raise syntax 88.900 array("peer materialiser chunk must be positive")
::method materialise
  expose chunkBytes verifier
  use strict arg client,peerNodeId,ref,targetPath
  expected=.StoragePeerCodec~normaliseSha256(ref~digest)
  if expected="" then return .StoragePeerMaterialiseResult~new(.false,"DIGEST_REQUIRED",ref,targetPath,"",0)
  /* A Storage materialisation lease is expected to own an unused target.  Do
   * not clobber an existing path: peer transfer is not overwrite authority. */
  if stream(targetPath,"c","query exists")<>"" then return .StoragePeerMaterialiseResult~new(.false,"TARGET_EXISTS",ref,targetPath,"",0)
  stage=SysTempFileName(targetPath||".peer-??????")
  if stage="" then return .StoragePeerMaterialiseResult~new(.false,"STAGE_CREATE_FAILED",ref,targetPath,"",0)
  call SysFileDelete stage
  source=.StoragePeerByteSource~new(client,peerNodeId,ref,chunkBytes)
  sink=.StorageLocalFileByteSink~new(stage)
  source~openAt(0); sink~openAt(0,source~sizeBytes); total=0
  signal on syntax name copyFailed
  do while total<source~sizeBytes
    chunk=source~readChunk(chunkBytes)
    if chunk~data~length=0 & \chunk~eof then signal copyFailed
    ignore=sink~writeChunk(chunk~data); total+=chunk~data~length
  end
  sink~close; source~close
  signal off syntax
  actual=verifier~digestFile(stage)~lower
  if actual="" | actual<>expected then do
    call SysFileDelete stage
    return .StoragePeerMaterialiseResult~new(.false,"DIGEST_MISMATCH",ref,targetPath,actual,total)
  end
  /* Publish only verified bytes.  The surrounding workspace/materialisation
   * lease provides the single-writer target-path authority. */
  rcMove=SysFileMove(stage,targetPath)
  if rcMove<>0 then do
    call SysFileDelete stage
    return .StoragePeerMaterialiseResult~new(.false,"PUBLISH_FAILED",ref,targetPath,actual,total)
  end
  return .StoragePeerMaterialiseResult~new(.true,"VERIFIED",ref,targetPath,actual,total)
copyFailed:
  signal off syntax
  sink~close; source~close; call SysFileDelete stage
  return .StoragePeerMaterialiseResult~new(.false,"TRANSFER_FAILED",ref,targetPath,"",total)

::class StoragePeerMaterialiseResult public
::attribute ok get
::attribute code get
::attribute ref get
::attribute path get
::attribute digest get
::attribute bytes get
::method init
  expose ok code ref path digest bytes
  use strict arg okArg,codeArg,refArg,pathArg,digestArg="",bytesArg=0
  ok=(okArg==.true); code=codeArg~string; ref=refArg; path=pathArg~string; digest=digestArg~string; bytes=bytesArg+0

/* Catalogue admission is deliberately separate from byte transfer.  Only a
 * VERIFIED materialisation may become a StorageLocation.  The default
 * classification is disposable/temporary because a verified local cache is
 * not automatically a durable replica. */
::class StoragePeerReplicaAdmission public
::method admit
  use strict arg catalogue,nodeId,materialiseResult,providerId="peer-materialised",capacityDomainId="",safetyClass="DISPOSABLE",lifecycleState="TEMPORARY",mediaType="application/octet-stream",displayName=""
  if catalogue==.nil | materialiseResult==.nil then return .StoragePeerAdmissionResult~failure("MISSING_ARGUMENT")
  if \materialiseResult~ok | materialiseResult~code<>"VERIFIED" then return .StoragePeerAdmissionResult~failure("UNVERIFIED_MATERIALISATION")
  ref=materialiseResult~ref
  expected=.StoragePeerCodec~normaliseSha256(ref~digest)
  actual=.StoragePeerCodec~normaliseSha256(materialiseResult~digest)
  if expected="" | actual="" | expected<>actual then return .StoragePeerAdmissionResult~failure("DIGEST_MISMATCH")
  obj=catalogue~get(ref~objectId)
  if obj==.nil then do
    name=displayName~string; if name="" then name=ref~objectId
    obj=.StorageObject~new(ref,name,materialiseResult~bytes,mediaType)
    catalogue~put(obj)
  end
  else do
    if obj~ref~digest<>"" & .StoragePeerCodec~normaliseSha256(obj~ref~digest)<>expected then return .StoragePeerAdmissionResult~failure("OBJECT_IDENTITY_CONFLICT")
    if obj~sizeBytes<>materialiseResult~bytes then return .StoragePeerAdmissionResult~failure("OBJECT_SIZE_CONFLICT")
  end
  verification="sha256:"||actual
  loc=.StorageLocation~new(providerId,materialiseResult~path,capacityDomainId,.StorageLocationState~AVAILABLE,"",.true,verification,safetyClass,lifecycleState,nodeId)
  obj~addLocation(loc)
  return .StoragePeerAdmissionResult~success(obj,loc)

::class StoragePeerAdmissionResult public
::attribute ok get
::attribute code get
::attribute object get
::attribute location get
::method init
  expose ok code object location
  use strict arg okArg,codeArg,objectArg=.nil,locationArg=.nil
  ok=(okArg==.true); code=codeArg~string; object=objectArg; location=locationArg
::method success class
  use strict arg objectArg,locationArg
  return self~new(.true,"ADMITTED",objectArg,locationArg)
::method failure class
  use strict arg codeArg
  return self~new(.false,codeArg)

/* Optional QueueRexx/Queue Fabric adapter.  The supplied peerMesh must expose
 * bindServiceRoute(), queueManager, channels, listener and adminPrincipal as
 * QueueRexxPeerMeshRuntime does.  No dependency is loaded merely by loading
 * StoragePeer.cls. */
::class StoragePeerQueueRexxBinding public
::method bindClient class
  use strict arg peerMesh,peerNodeId,clientId,principal="storage-client",remoteRequestQueue="STORAGE.PEER.REQUEST",timeoutMs=10000
  localReply="STORAGE.PEER.REPLY."||clientId~string~translate
  route=peerMesh~bindServiceRoute(peerNodeId,"STORAGE.REQUEST."||clientId,localReply,remoteRequestQueue,.StoragePeerContract~SECURITY_DOMAIN,principal)
  if route==.nil | \route~ok then return route
  ignore=peerMesh~queueManager~grant(localReply,principal,"GET",peerMesh~adminPrincipal)
  d=route~value
  transport=.StoragePeerQueueRexxClientTransport~new(peerMesh,d["remote_alias"],d["sender_channel"],localReply,principal,timeoutMs)
  return .StoragePeerBindingResult~success(transport,d)
::method bindServer class
  use strict arg peerMesh,peerNodeId,clientId,service,servicePrincipal="storage-service",remoteReplyQueue="STORAGE.PEER.REPLY."
  requestQueue="STORAGE.PEER.REQUEST"
  remoteReply=remoteReplyQueue||clientId~string~translate
  route=peerMesh~bindServiceRoute(peerNodeId,"STORAGE.REPLY."||clientId,requestQueue,remoteReply,.StoragePeerContract~SECURITY_DOMAIN,servicePrincipal)
  if route==.nil | \route~ok then return route
  ignore=peerMesh~queueManager~grant(requestQueue,servicePrincipal,"GET",peerMesh~adminPrincipal)
  d=route~value
  server=.StoragePeerQueueRexxServer~new(peerMesh,peerNodeId,service,requestQueue,d["remote_alias"],d["sender_channel"],servicePrincipal)
  return .StoragePeerBindingResult~success(server,d)

::class StoragePeerBindingResult public
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

::class StoragePeerQueueRexxClientTransport public
::method init
  expose peerMesh channels manager requestAlias requestChannel replyQueue listener admin localPrincipal timeoutMs
  use strict arg peerMeshArg,requestAliasArg,requestChannelArg,replyQueueArg,principalArg,timeoutArg=10000
  peerMesh=peerMeshArg; channels=peerMesh~channels; manager=peerMesh~queueManager; listener=peerMesh~listener; admin=peerMesh~adminPrincipal
  requestAlias=requestAliasArg~string; requestChannel=requestChannelArg~string; replyQueue=replyQueueArg~string; localPrincipal=principalArg~string; timeoutMs=timeoutArg+0
::method request
  expose channels manager requestAlias requestChannel replyQueue listener admin localPrincipal timeoutMs
  use strict arg peerNodeId,request
  if listener<>.nil then do
    if \listener~start then return .nil
    a=.StoragePeerServeOneActivity~new(listener); ignore=a~run
  end
  options=.table~new; options["persistent"]=.true; options["securityDomain"]=.StoragePeerContract~SECURITY_DOMAIN; options["correlationId"]=.StoragePeerCodec~value(request,"request_id","")
  r=channels~put(requestAlias,request,options,localPrincipal); if \r~ok then return .nil
  r=channels~pump(requestChannel,0,admin); if \r~ok then return .nil
  loops=timeoutMs%25; if loops<1 then loops=1
  do i=1 to loops
    got=manager~get(replyQueue,localPrincipal)
    if got~ok then return got~value~payload
    if got~code<>"QUEUE_EMPTY" then return .nil
    call SysSleep 0.025
  end
  return .nil

::class StoragePeerServeOneActivity public
::method init
  expose listener
  use strict arg listenerArg
  listener=listenerArg
::method run
  expose listener
  reply .true
  ignore=listener~serveOne
  return

::class StoragePeerQueueRexxServer public
::method init
  expose peerMesh service expectedPeerNodeId requestQueue replyAlias replyChannel servicePrincipal manager channels admin
  use strict arg peerMeshArg,expectedPeerArg,serviceArg,requestQueueArg,replyAliasArg,replyChannelArg,principalArg
  peerMesh=peerMeshArg; expectedPeerNodeId=expectedPeerArg~string~strip; service=serviceArg; requestQueue=requestQueueArg~string; replyAlias=replyAliasArg~string; replyChannel=replyChannelArg~string; servicePrincipal=principalArg~string
  if expectedPeerNodeId="" then raise syntax 88.900 array("Storage peer QueueRexx server requires authenticated peer identity")
  manager=peerMesh~queueManager; channels=peerMesh~channels; admin=peerMesh~adminPrincipal
::method processOne
  expose service expectedPeerNodeId requestQueue replyAlias replyChannel servicePrincipal manager channels admin
  got=manager~get(requestQueue,servicePrincipal)
  if \got~ok then return .StoragePeerBindingResult~failure(got~code,got~detail)
  response=service~handleFrom(expectedPeerNodeId,got~value~payload)
  options=.table~new; options["persistent"]=.true; options["securityDomain"]=.StoragePeerContract~SECURITY_DOMAIN; options["correlationId"]=.StoragePeerCodec~value(response,"request_id","")
  r=channels~put(replyAlias,response,options,servicePrincipal); if \r~ok then return .StoragePeerBindingResult~failure(r~code,r~detail)
  r=channels~pump(replyChannel,0,admin); if \r~ok then return .StoragePeerBindingResult~failure(r~code,r~detail)
  return .StoragePeerBindingResult~success(response)

::requires "StorageFabric.cls"
::requires "StorageStreaming.cls"
