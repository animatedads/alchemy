/* Storage Fabric CLI service adapter v0.1-dev22 candidate.
 * Only the existing Storage Fabric catalogue, authority store, peer materialiser
 * and Git provider own storage semantics.  This is a command surface.
 */
/* Storage byte counts, offsets and capacity values routinely exceed the ooRexx
 * default 9-digit arithmetic context (a 2,005,735,208-byte object already does).
 * Keep them exact in every Storage package.  (precision1, from dev22 backup-floor
 * line; Claude (Opus 5.5).) */
::options digits 30

::class StorageCommandBuild public
::constant VERSION "0.1-dev22-candidate"
::constant API "storage.fabric.command/0.1"

::class StorageCommandService public
::attribute snapshot get
::attribute nodeId get
::method init
  expose store snapshot nodeId localProvider localSafety localVendor localSite gitProvider peerClient
  use strict arg stateRoot, nodeArg, localSafetyArg="UNKNOWN", localVendorArg="", localSiteArg="", gitArg=.nil, peerArg=.nil
  nodeId=nodeArg~string~strip
  if nodeId="" then raise syntax 88.900 array("node id is mandatory")
  localProvider="fs:"||nodeId
  localSafety=localSafetyArg~string~strip~upper
  if pos("|"||localSafety||"|","|UNKNOWN|SAFE|DISPOSABLE|")=0 then raise syntax 88.900 array("invalid local safety")
  localVendor=localVendorArg~string~strip
  localSite=localSiteArg~string~strip
  if localSite="" then localSite=nodeId
  store=.StorageAuthorityStore~new(stateRoot)
  snapshot=store~load
  if snapshot==.nil then snapshot=.StorageAuthoritySnapshot~new
  gitProvider=gitArg
  peerClient=peerArg
::method configureGit
  expose gitProvider
  use strict arg provider
  gitProvider=provider
  return self
::method configurePeer
  expose peerClient
  use strict arg client
  peerClient=client
  return self
/* Reload the last fully committed disk authority for long-lived read peers.
 * Configure a distinct read-only service to avoid discarding pending mutations. */
::method refresh
  expose snapshot store
  latest=store~load
  if latest==.nil then return snapshot~revision=0
  snapshot=latest
  return .true
::method objects
  expose snapshot
  return snapshot~catalogue~all
::method lookup
  expose snapshot
  use strict arg queryArg
  query=queryArg~string~strip
  answer=.directory~new
  answer["ok"]=.false; answer["code"]="NOT_FOUND"; answer["object"]=.nil
  if query="" then do
    answer["code"]="QUERY_REQUIRED"; return answer
  end
  obj=snapshot~catalogue~get(query)
  if obj<>.nil then do
    answer["ok"]=.true; answer["code"]="OK"; answer["object"]=obj
    return answer
  end
  if left(query,1)="/" then do
    pathMatches=.directory~new
    do ns over snapshot~allNamespaces
      b=ns~localBinding(query)
      if b<>.nil then pathMatches[b~ref~objectId]=b~ref~objectId
    end
    if pathMatches~items=1 then do
      do id over pathMatches
        answer["ok"]=.true; answer["code"]="OK"; answer["object"]=snapshot~catalogue~get(id)
        return answer
      end
    end
    if pathMatches~items>1 then do
      answer["code"]="AMBIGUOUS_VIRTUAL_PATH"; return answer
    end
  end
  matches=.array~new
  /* Filename lookup is exact and unique: a substring must not choose a random
   * video on which to perform a materialisation or Azure upload. */
  do obj over snapshot~catalogue~all
    matched=(obj~displayName~lower=query~lower)
    if \matched then do l over obj~locations
      if l~locator=query then do
        matched=.true
        leave
      end
    end
    if matched then matches~append(obj)
  end
  if matches~items=1 then do
    answer["ok"]=.true; answer["code"]="OK"; answer["object"]=matches[1]
  end
  else if matches~items>1 then answer["code"]="AMBIGUOUS_NAME_USE_OBJECT_ID"
  return answer
::method save
  expose snapshot store
  return store~save(snapshot)
::method registerFile
  expose snapshot nodeId localProvider localSafety localVendor localSite
  use strict arg pathArg, nameArg="", mediaArg="application/octet-stream"
  path=pathArg~string
  if stream(path,"c","query exists")="" then return self~outcome("SOURCE_NOT_FOUND")
  bytes=stream(path,"c","query size")
  if \datatype(bytes,"N") then return self~outcome("SOURCE_SIZE_UNKNOWN")
  if bytes<0 then return self~outcome("SOURCE_SIZE_UNKNOWN")
  digest=.StoragePosixSha256Verifier~new~digestFile(path)~lower
  if .StoragePeerCodec~normaliseSha256(digest)="" then return self~outcome("SOURCE_SHA256_FAILED")
  id="sha256:"||digest
  ref=.StorageRef~new(id,"sha256:"||digest)
  obj=snapshot~catalogue~get(id)
  if obj==.nil then do
    name=nameArg~string
    if name="" then name=filespec("N",path)
    media=mediaArg~string
    if media="" then media="application/octet-stream"
    obj=.StorageObject~new(ref,name,bytes,media)
    snapshot~catalogue~put(obj)
  end
  else if obj~sizeBytes<>bytes then return self~outcome("OBJECT_SIZE_CONFLICT")
  location=.StorageLocation~new(localProvider,path,localProvider,"AVAILABLE","",.true,"sha256:"||digest,localSafety,"STABLE",nodeId,localVendor,localSite,localVendor||"/"||localSite)
  obj~addLocation(location)
  self~save
  return self~outcome("OK",obj,location)
/* Add a real retained virtual namespace binding plus searchable EAs. */
::method addFile
  expose snapshot
  use strict arg pathArg,nameArg,virtualArg,namespaceArg="media",descriptionArg="",tagsArg="",metaArg="",mediaArg="application/octet-stream"
  vp=virtualArg~string
  if vp="" | vp="/" | left(vp,1)<>"/" | .StoragePath~normalize(vp)<>vp then return self~outcome("INVALID_VIRTUAL_PATH")
  ns=self~ensureNamespace(namespaceArg)
  existing=ns~localBinding(vp)
  if existing<>.nil then return self~outcome("VIRTUAL_PATH_EXISTS")
  r=self~registerFile(pathArg,nameArg,mediaArg)
  if \r["ok"] then return r
  obj=r["object"]
  self~applyMetadata(obj,descriptionArg,tagsArg,metaArg)
  ns~bind(vp,obj~ref,.StorageWritePolicy~READ_ONLY)
  self~save
  return self~outcome("OK",obj,r["location"])
::method bindExisting
  use strict arg keyArg,virtualArg,namespaceArg="media"
  vp=virtualArg~string
  if vp="" | vp="/" | left(vp,1)<>"/" | .StoragePath~normalize(vp)<>vp then return self~outcome("INVALID_VIRTUAL_PATH")
  found=self~lookup(keyArg)
  if \found["ok"] then return self~outcome(found["code"])
  ns=self~ensureNamespace(namespaceArg)
  if ns~localBinding(vp)<>.nil then return self~outcome("VIRTUAL_PATH_EXISTS")
  obj=found["object"]
  ns~bind(vp,obj~ref,.StorageWritePolicy~READ_ONLY)
  self~save
  return self~outcome("OK",obj)
::method ensureNamespace
  expose snapshot
  use strict arg idArg
  id=idArg~string~strip
  ns=snapshot~namespace(id)
  if ns<>.nil then return ns
  env=snapshot~environment("STORAGE-CLI-LIVE")
  if env==.nil then do
    env=.StorageEnvironment~new("STORAGE-CLI-LIVE","LIVE")
    snapshot~addEnvironment(env)
  end
  ns=.StorageNamespace~new(id,snapshot~catalogue,env)
  snapshot~addNamespace(ns)
  return ns
::method applyMetadata
  use strict arg obj,descriptionArg="",tagsArg="",metaArg="",untagsArg="",unsetsArg=""
  if descriptionArg<>"" then obj~setEA(.StorageEA~new("catalog","description",descriptionArg))
  tags=tagsArg~string
  do while tags<>""
    parse var tags tag "1E"x tags
    if tag<>"" then obj~setEA(.StorageEA~new("tag",tag,"1"))
  end
  metas=metaArg~string
  do while metas<>""
    parse var metas pair "1E"x metas
    parse var pair key "1F"x val
    if key<>"" then obj~setEA(.StorageEA~new("meta",key,val))
  end
  untags=untagsArg~string
  do while untags<>""
    parse var untags tag "1E"x untags
    if tag<>"" then obj~eas~remove("tag."||tag)
  end
  unsets=unsetsArg~string
  do while unsets<>""
    parse var unsets key "1E"x unsets
    if key<>"" then obj~eas~remove("meta."||key)
  end
  return obj
::method annotate
  use strict arg keyArg,descriptionArg="",tagsArg="",metaArg="",untagsArg="",unsetsArg=""
  r=self~lookup(keyArg)
  if \r["ok"] then return self~outcome(r["code"])
  obj=r["object"]
  self~applyMetadata(obj,descriptionArg,tagsArg,metaArg,untagsArg,unsetsArg)
  self~save
  return self~outcome("OK",obj)
::method removeBinding
  expose snapshot
  use strict arg keyArg,namespaceArg="media",forgetArg=.false
  key=keyArg~string
  obj=.nil; ns=.nil; binding=.nil
  if left(key,1)="/" then do
    ns=snapshot~namespace(namespaceArg)
    if ns==.nil then return self~outcome("NAMESPACE_NOT_FOUND")
    binding=ns~localBinding(key)
    if binding==.nil then return self~outcome("VIRTUAL_PATH_NOT_FOUND")
    obj=snapshot~catalogue~get(binding~ref~objectId)
    if obj==.nil then return self~outcome("OBJECT_NOT_FOUND")
  end
  else do
    if \forgetArg then return self~outcome("VIRTUAL_PATH_REQUIRED")
    obj=snapshot~catalogue~get(key)
    if obj==.nil then return self~outcome("OBJECT_NOT_FOUND")
  end
  /* Forget is prohibited while any remaining virtual path references content. */
  if forgetArg then do
    do otherNs over snapshot~allNamespaces
      do b over otherNs~localBindings
        if b~ref~objectId=obj~ref~objectId then do
          if ns==.nil then return self~outcome("OBJECT_STILL_BOUND")
          if otherNs~namespaceId<>ns~namespaceId | b~path<>key then return self~outcome("OBJECT_STILL_BOUND")
        end
      end
    end
  end
  if ns<>.nil then ns~unlinkLocal(key)
  if forgetArg then do
    snapshot~replicaPolicies~remove(obj~ref~objectId)
    snapshot~catalogue~remove(obj~ref~objectId)
  end
  self~save
  return self~outcome("OK",obj)
::method materialise
  expose snapshot nodeId localProvider localSafety localVendor localSite gitProvider peerClient
  use strict arg keyArg,targetArg,preferredPeer=""
  found=self~lookup(keyArg)
  if \found["ok"] then return self~outcome(found["code"])
  obj=found["object"]; ref=obj~ref
  target=targetArg~string
  if target="" then return self~outcome("TARGET_REQUIRED")
  if stream(target,"c","query exists")<>"" then return self~outcome("TARGET_EXISTS")
  stage=SysTempFileName(target||".storage-??????")
  if stage="" then return self~outcome("STAGE_CREATE_FAILED")
  call SysFileDelete stage
  ok=.false; code="NO_AVAILABLE_SOURCE"
  if preferredPeer<>"" then do
    if peerClient==.nil then return self~outcome("PEER_TRANSPORT_NOT_CONFIGURED")
    r=.StoragePeerMaterialiser~new~materialise(peerClient,preferredPeer,ref,stage)
    ok=r~ok; code=r~code
  end
  else do
    if gitProvider==.nil then return self~outcome("GIT_PROVIDER_NOT_CONFIGURED")
    do loc over obj~locations
      if loc~providerId=gitProvider~providerId then do
        if loc~state="AVAILABLE" then do
          if loc~verified then do
            r=gitProvider~materialiseLocation(ref,loc,stage)
            ok=r~ok; code=r~code
            if ok then leave
          end
        end
      end
    end
  end
  if \ok then do
    call SysFileDelete stage
    return self~outcome(code)
  end
  expected=.StoragePeerCodec~normaliseSha256(ref~digest)
  digest=.StoragePosixSha256Verifier~new~digestFile(stage)~lower
  if expected="" | digest<>expected then do
    call SysFileDelete stage
    return self~outcome("STAGE_DIGEST_MISMATCH")
  end
  /* Caller must own the destination path.  Never overwrite an existing file. */
  if stream(target,"c","query exists")<>"" then do
    call SysFileDelete stage
    return self~outcome("TARGET_EXISTS")
  end
  moveRc=SysFileMove(stage,target)
  if moveRc<>0 then do
    call SysFileDelete stage
    return self~outcome("PUBLISH_FAILED")
  end
  loc=.StorageLocation~new(localProvider,target,localProvider,"AVAILABLE","",.true,"sha256:"||digest,localSafety,"STABLE",nodeId,localVendor,localSite,localVendor||"/"||localSite)
  obj~addLocation(loc)
  self~save
  return self~outcome("OK",obj,loc)
::method ensureAzure
  expose snapshot nodeId localProvider gitProvider
  use strict arg keyArg
  found=self~lookup(keyArg)
  if \found["ok"] then return self~outcome(found["code"])
  obj=found["object"]
  if gitProvider==.nil then return self~outcome("GIT_PROVIDER_NOT_CONFIGURED")
  expected=.StoragePeerCodec~normaliseSha256(obj~ref~digest)
  if expected="" then return self~outcome("OBJECT_SHA256_REQUIRED")
  source=""
  do l over obj~locations
    if l~providerId=localProvider then do
      if l~nodeId=nodeId then do
        if l~countsAsDurable then do
          p=l~locator
          if stream(p,"c","query exists")<>"" then do
            actual=.StoragePosixSha256Verifier~new~digestFile(p)~lower
            if actual=expected then do
              source=p
              leave
            end
          end
        end
      end
    end
  end
  if source="" then return self~outcome("NO_DURABLE_LOCAL_SOURCE")
  put=gitProvider~store(obj~ref,source)
  if \put~ok then return self~outcome("AZURE_GIT_"||put~code)
  obj~addLocation(put~location)
  snapProvider=.StorageAuthorityProviderRecord~new(gitProvider~providerId,"GIT","ELASTIC",gitProvider~vendorId,gitProvider~siteId,gitProvider~failureDomainId,"SAFE","STABLE")
  snapshot~addProvider(snapProvider)
  requirement=.StorageReplicaRequirement~new(2,0,0,2)
  snapshot~replicaPolicies~put(obj~ref~objectId,requirement)
  assessment=.StorageReplicaPolicy~new~assess(obj,requirement)
  self~save
  if \assessment~satisfied then return self~outcome("REPLICA_POLICY_UNSATISFIED",obj,put~location)
  return self~outcome("OK",obj,put~location)
::method outcome
  use arg code, obj=.nil,loc=.nil
  d=.directory~new
  d["ok"]=(code="OK")
  d["code"]=code
  d["object"]=obj
  d["location"]=loc
  return d

::requires "StorageAuthority.cls"
::requires "StoragePeer.cls"
::requires "StorageGit.cls"
