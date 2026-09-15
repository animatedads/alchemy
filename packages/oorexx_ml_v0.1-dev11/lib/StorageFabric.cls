/* ooRexx Storage Fabric v0.1-dev7
 *
 * Provider-neutral catalogue, capacity-domain-aware workspace allocation,
 * replica safety and transfer contracts for large data.
 */

::class StorageFabricBuild public
::constant VERSION "0.1-dev7"
::constant API "storage.fabric/0.1"

::class StoragePoolMode public
::constant WORKSPACE "WORKSPACE"
::constant DURABLE "DURABLE"
::constant BOTH "BOTH"

::class StorageSafetyClass public
::constant SAFE "SAFE"
::constant DISPOSABLE "DISPOSABLE"
::constant UNKNOWN "UNKNOWN"

::class StorageLifecycleState public
::constant STABLE "STABLE"
::constant TEMPORARY "TEMPORARY"
::constant CREDIT_LIMITED "CREDIT_LIMITED"
::constant EXPIRING "EXPIRING"
::constant TERMINATING "TERMINATING"

::class StorageServiceLifecycle public
::attribute safetyClass get
::attribute state get
::attribute expectedEnd get
::attribute reason get
::attribute observedAt get
::attribute evidenceRef get
::method init
  expose safetyClass state expectedEnd reason observedAt evidenceRef
  use arg safetyArg="SAFE", stateArg="STABLE", expectedEndArg="", reasonArg="", observedArg="", evidenceArg=""
  safetyClass=safetyArg~string~strip~upper
  state=stateArg~string~strip~upper
  expectedEnd=expectedEndArg~string~strip
  reason=reasonArg~string
  observedAt=observedArg~string
  evidenceRef=evidenceArg~string
  if safetyClass<>.StorageSafetyClass~SAFE & safetyClass<>.StorageSafetyClass~DISPOSABLE & safetyClass<>.StorageSafetyClass~UNKNOWN then raise syntax 88.900 array("invalid storage safety class")
  if state<>.StorageLifecycleState~STABLE & state<>.StorageLifecycleState~TEMPORARY & state<>.StorageLifecycleState~CREDIT_LIMITED & state<>.StorageLifecycleState~EXPIRING & state<>.StorageLifecycleState~TERMINATING then raise syntax 88.900 array("invalid storage lifecycle state")
::method countsAsDurable
  expose safetyClass state
  if safetyClass<>.StorageSafetyClass~SAFE then return .false
  /* Service/account lifecycle is part of safety: only STABLE service capacity
   * may satisfy a durable-replica requirement. */
  if state<>.StorageLifecycleState~STABLE then return .false
  return .true
::method workspaceAdmissible
  expose state
  return state<>.StorageLifecycleState~TERMINATING
::method disposable
  expose safetyClass
  return safetyClass=.StorageSafetyClass~DISPOSABLE

::class StorageLocationState public
::constant AVAILABLE "AVAILABLE"
::constant OFFLINE "OFFLINE"
::constant UNKNOWN "UNKNOWN"

::class StorageAllocationState public
::constant ACTIVE "ACTIVE"
::constant RELEASED "RELEASED"

::class StorageTransferState public
::constant PLANNED "PLANNED"
::constant COPYING "COPYING"
::constant COPIED "COPIED"
::constant VERIFIED "VERIFIED"
::constant COMMITTED "COMMITTED"
::constant FAILED "FAILED"

::class StorageRef public
::attribute objectId get
::attribute digest get
::method init
  expose objectId digest
  use arg objectArg, digestArg=""
  objectId=objectArg~string~strip
  digest=digestArg~string~strip
  if objectId="" then raise syntax 88.900 array("StorageRef objectId must not be empty")
::method string
  expose objectId
  return objectId

::class StorageLocation public
::attribute providerId get
::attribute locator get
::attribute capacityDomainId get
::attribute state get
::attribute observedAt get
::attribute verified get
::attribute verificationRef get
::attribute safetyClass get
::attribute lifecycleState get
::attribute nodeId get
::method init
  expose providerId locator capacityDomainId state observedAt verified verificationRef safetyClass lifecycleState nodeId
  use arg providerArg, locatorArg, domainArg="", stateArg="AVAILABLE", observedArg="", verifiedArg=.false, verificationArg="", safetyArg="SAFE", lifecycleArg="STABLE", nodeArg=""
  providerId=providerArg~string~strip
  locator=locatorArg~string
  capacityDomainId=domainArg~string~strip
  state=stateArg~string~strip~upper
  observedAt=observedArg~string
  verified=(verifiedArg==.true)
  verificationRef=verificationArg~string
  safetyClass=safetyArg~string~strip~upper
  lifecycleState=lifecycleArg~string~strip~upper
  nodeId=nodeArg~string~strip
  if providerId="" then raise syntax 88.900 array("StorageLocation providerId must not be empty")
  if locator="" then raise syntax 88.900 array("StorageLocation locator must not be empty")
  if safetyClass<>.StorageSafetyClass~SAFE & safetyClass<>.StorageSafetyClass~DISPOSABLE & safetyClass<>.StorageSafetyClass~UNKNOWN then raise syntax 88.900 array("invalid location safety class")
  if lifecycleState<>.StorageLifecycleState~STABLE & lifecycleState<>.StorageLifecycleState~TEMPORARY & lifecycleState<>.StorageLifecycleState~CREDIT_LIMITED & lifecycleState<>.StorageLifecycleState~EXPIRING & lifecycleState<>.StorageLifecycleState~TERMINATING then raise syntax 88.900 array("invalid location lifecycle state")
::method countsAsDurable
  expose state verified safetyClass lifecycleState
  if state<>.StorageLocationState~AVAILABLE then return .false
  if \verified then return .false
  if safetyClass<>.StorageSafetyClass~SAFE then return .false
  if lifecycleState<>.StorageLifecycleState~STABLE then return .false
  return .true
::method canonical
  expose providerId locator capacityDomainId state observedAt verified verificationRef safetyClass lifecycleState nodeId
  return "provider="||providerId||";locator="||locator||";domain="||capacityDomainId||";state="||state||";verified="||verified||";verification="||verificationRef||";safety="||safetyClass||";lifecycle="||lifecycleState||";node="||nodeId||";observed="||observedAt

::class StorageObject public
::attribute ref get
::attribute displayName get
::attribute sizeBytes get
::attribute mediaType get
::attribute locations get
::attribute eas get
::method init
  expose ref displayName sizeBytes mediaType locations eas
  use arg refArg, nameArg="", sizeArg=0, mediaArg="application/octet-stream"
  if refArg==.nil then raise syntax 88.900 array("StorageObject ref is mandatory")
  ref=refArg
  displayName=nameArg~string
  sizeBytes=sizeArg+0
  mediaType=mediaArg~string
  locations=.array~new
  eas=.StorageEASet~new
  if sizeBytes<0 then raise syntax 88.900 array("StorageObject size must not be negative")
::method addLocation
  expose locations
  use arg location
  if location==.nil then raise syntax 88.900 array("location is mandatory")
  /* Replace the same provider+locator observation rather than duplicating it. */
  do i=1 to locations~items
    cur=locations[i]
    if cur~providerId=location~providerId & cur~locator=location~locator then do
      locations[i]=location
      return self
    end
  end
  locations~append(location)
  return self
::method availableLocations
  expose locations
  answer=.array~new
  do l over locations
    if l~state=.StorageLocationState~AVAILABLE then answer~append(l)
  end
  return answer
::method hasProvider
  expose locations
  use arg providerArg
  p=providerArg~string
  do l over locations
    if l~providerId=p then return .true
  end
  return .false
::method setEA
  expose eas
  use arg ea
  eas~put(ea)
  return self
::method ea
  expose eas
  use arg keyArg
  return eas~get(keyArg)
::method eaValue
  expose eas
  use arg keyArg, defaultArg=""
  ea=eas~get(keyArg)
  if ea==.nil then return defaultArg
  return ea~value

::class StorageSearchHit public
::attribute object get
::attribute match get
::method init
  expose object match
  use arg objectArg, matchArg=""
  object=objectArg; match=matchArg~string

::class StorageCatalogue public
::attribute count get
::method init
  expose objects count
  objects=.directory~new
  count=0
::method put
  expose objects count
  use arg object
  if object==.nil then raise syntax 88.900 array("catalogue object is mandatory")
  key=object~ref~objectId
  if objects[key]==.nil then count+=1
  objects[key]=object
  return object
::method get
  expose objects
  use arg objectId
  return objects[objectId~string]
::method all
  expose objects
  a=.array~new
  do key over objects
    a~append(objects[key])
  end
  return a
::method search
  expose objects
  use arg queryArg, limitArg=100
  q=queryArg~string~strip~lower
  limit=limitArg+0
  if limit<1 then limit=100
  hits=.array~new
  do key over objects
    o=objects[key]
    if hits~items>=limit then leave
    matched=""
    if q="" then matched="ALL"
    else if o~displayName~lower~pos(q)>0 then matched="NAME"
    else if o~ref~objectId~lower~pos(q)>0 then matched="OBJECT_ID"
    else do ea over o~eas~all
      if ea~key~pos(q)>0 | ea~value~string~lower~pos(q)>0 then do
        matched="EA"
        leave
      end
    end
    if matched="" then do l over o~locations
      if l~locator~lower~pos(q)>0 | l~providerId~lower~pos(q)>0 then do
        matched="LOCATION"
        leave
      end
    end
    if matched<>"" then hits~append(.StorageSearchHit~new(o,matched))
  end
  return hits
::method byProvider
  expose objects
  use arg providerArg
  p=providerArg~string
  a=.array~new
  do key over objects
    o=objects[key]
    if o~hasProvider(p) then a~append(o)
  end
  return a
::method save
  expose objects
  use arg pathArg
  path=pathArg~string
  call SysFileDelete path
  do key over objects
    o=objects[key]
    if o~locations~items=0 then do
      line=.StorageCodec~enc(o~ref~objectId)||"09"x||.StorageCodec~enc(o~ref~digest)||"09"x||.StorageCodec~enc(o~displayName)||"09"x||o~sizeBytes||"09"x||.StorageCodec~enc(o~mediaType)||"09"x||"09"x||"09"x||"09"x||"UNKNOWN"||"09"x||"0"||"09"x||"09"x||.StorageCodec~enc(o~eas~serialize)||"09"x||.StorageSafetyClass~UNKNOWN||"09"x||.StorageLifecycleState~STABLE||"09"x||""
      call lineout path,line
    end
    else do l over o~locations
      line=.StorageCodec~enc(o~ref~objectId)||"09"x||.StorageCodec~enc(o~ref~digest)||"09"x||.StorageCodec~enc(o~displayName)||"09"x||o~sizeBytes||"09"x||.StorageCodec~enc(o~mediaType)||"09"x||.StorageCodec~enc(l~providerId)||"09"x||.StorageCodec~enc(l~locator)||"09"x||.StorageCodec~enc(l~capacityDomainId)||"09"x||l~state||"09"x||l~verified||"09"x||.StorageCodec~enc(l~verificationRef)||"09"x||.StorageCodec~enc(o~eas~serialize)||"09"x||l~safetyClass||"09"x||l~lifecycleState||"09"x||.StorageCodec~enc(l~nodeId)
      call lineout path,line
    end
  end
  call lineout path
  return self
::method load
  expose objects count
  use arg pathArg
  path=pathArg~string
  objects=.directory~new; count=0
  if stream(path,"c","query exists")="" then return self
  do while lines(path)>0
    line=linein(path)
    if line="" then iterate
    fields=.StorageCodec~splitTabs(line)
    if fields~items<11 then iterate
    id=.StorageCodec~dec(fields[1]); digest=.StorageCodec~dec(fields[2]); name=.StorageCodec~dec(fields[3])
    size=fields[4]+0; media=.StorageCodec~dec(fields[5])
    o=objects[id]
    if o==.nil then do
      o=.StorageObject~new(.StorageRef~new(id,digest),name,size,media)
      objects[id]=o; count+=1
    end
    if fields~items>=12 then o~eas~loadSerialized(.StorageCodec~dec(fields[12]))
    provider=.StorageCodec~dec(fields[6])
    if provider<>"" then do
      safety=.StorageSafetyClass~SAFE
      lifecycle=.StorageLifecycleState~STABLE
      node=""
      if fields~items>=13 then safety=fields[13]
      if fields~items>=14 then lifecycle=fields[14]
      if fields~items>=15 then node=.StorageCodec~dec(fields[15])
      loc=.StorageLocation~new(provider,.StorageCodec~dec(fields[7]),.StorageCodec~dec(fields[8]),fields[9],"",fields[10]="1",.StorageCodec~dec(fields[11]),safety,lifecycle,node)
      o~addLocation(loc)
    end
  end
  call stream path,"c","close"
  return self

::class StorageCodec public
::method enc class
  use arg valueArg
  s=valueArg~string
  s=changestr("%",s,"%25")
  s=changestr("09"x,s,"%09")
  s=changestr("0A"x,s,"%0A")
  s=changestr("0D"x,s,"%0D")
  s=changestr("1E"x,s,"%1E")
  s=changestr("1F"x,s,"%1F")
  return s
::method dec class
  use arg valueArg
  s=valueArg~string
  /* Decode escaped controls before percent itself. */
  s=changestr("%09",s,"09"x)
  s=changestr("%0A",s,"0A"x)
  s=changestr("%0D",s,"0D"x)
  s=changestr("%1E",s,"1E"x)
  s=changestr("%1F",s,"1F"x)
  s=changestr("%25",s,"%")
  return s
::method splitTabs class
  use arg line
  a=.array~new
  start=1
  do forever
    p=pos("09"x,line,start)
    if p=0 then do
      a~append(substr(line,start)); leave
    end
    a~append(substr(line,start,p-start))
    start=p+1
  end
  return a

::class StorageCapacityObservation public
::attribute capacityDomainId get
::attribute totalBytes get
::attribute freeBytes get
::attribute observedAt get
::attribute expiresAt get
::attribute evidenceRef get
::method init
  expose capacityDomainId totalBytes freeBytes observedAt expiresAt evidenceRef
  use arg domainArg, totalArg, freeArg, observedArg="", expiresArg="", evidenceArg=""
  capacityDomainId=domainArg~string~strip
  totalBytes=totalArg+0; freeBytes=freeArg+0
  observedAt=observedArg~string; expiresAt=expiresArg~string; evidenceRef=evidenceArg~string
  if capacityDomainId="" then raise syntax 88.900 array("capacityDomainId must not be empty")
  if totalBytes<0 | freeBytes<0 then raise syntax 88.900 array("capacity must not be negative")
  if freeBytes>totalBytes then raise syntax 88.900 array("freeBytes must not exceed totalBytes")

::class StoragePool public
::attribute poolId get
::attribute providerId get
::attribute root get
::attribute capacityDomainId get
::attribute mode get
::attribute safetyFloorBytes get
::attribute nodeId get
::attribute region get
::attribute lifecycle get
::method init
  expose poolId providerId root capacityDomainId mode safetyFloorBytes nodeId region lifecycle
  use arg poolArg, providerArg, rootArg, domainArg, modeArg="WORKSPACE", floorArg=0, nodeArg="", regionArg="", lifecycleArg=.nil
  poolId=poolArg~string~strip; providerId=providerArg~string~strip; root=rootArg~string
  capacityDomainId=domainArg~string~strip; mode=modeArg~string~upper; safetyFloorBytes=floorArg+0
  nodeId=nodeArg~string~strip; region=regionArg~string~strip~upper
  if lifecycleArg==.nil then lifecycle=.StorageServiceLifecycle~new
  else lifecycle=lifecycleArg
  if poolId="" | providerId="" | root="" | capacityDomainId="" then raise syntax 88.900 array("pool/provider/root/capacityDomain are mandatory")
  if safetyFloorBytes<0 then raise syntax 88.900 array("safety floor must not be negative")
  if mode<>.StoragePoolMode~WORKSPACE & mode<>.StoragePoolMode~DURABLE & mode<>.StoragePoolMode~BOTH then raise syntax 88.900 array("invalid storage pool mode")
::method canWorkspace
  expose mode lifecycle
  if \lifecycle~workspaceAdmissible then return .false
  return mode=.StoragePoolMode~WORKSPACE | mode=.StoragePoolMode~BOTH
::method canDurable
  expose mode
  return mode=.StoragePoolMode~DURABLE | mode=.StoragePoolMode~BOTH
::method countsAsDurable
  expose lifecycle
  return self~canDurable & lifecycle~countsAsDurable
::method disposable
  expose lifecycle
  return lifecycle~disposable

::class StorageAllocation public
::attribute allocationId get
::attribute pool get
::attribute reservedBytes get
::attribute owner get
::attribute locator get
::attribute state get
::method init
  expose allocationId pool reservedBytes owner locator state
  use arg idArg, poolArg, bytesArg, ownerArg="", locatorArg=""
  allocationId=idArg~string~strip; pool=poolArg; reservedBytes=bytesArg+0; owner=ownerArg~string
  locator=locatorArg~string; state=.StorageAllocationState~ACTIVE
  if allocationId="" | pool==.nil then raise syntax 88.900 array("allocation id and pool are mandatory")
::method release
  expose state
  state=.StorageAllocationState~RELEASED
  return self

::class StorageWorkspaceManager public
::method init
  expose pools observations reservations allocations sequence
  pools=.directory~new; observations=.directory~new; reservations=.directory~new; allocations=.directory~new; sequence=0
::method registerPool
  expose pools reservations
  use arg pool
  if pool==.nil then raise syntax 88.900 array("pool is mandatory")
  pools[pool~poolId]=pool
  if reservations[pool~capacityDomainId]==.nil then reservations[pool~capacityDomainId]=0
  return self
::method observeCapacity
  expose observations reservations
  use arg observation
  if observation==.nil then raise syntax 88.900 array("capacity observation is mandatory")
  observations[observation~capacityDomainId]=observation
  if reservations[observation~capacityDomainId]==.nil then reservations[observation~capacityDomainId]=0
  return self
::method pool
  expose pools
  use arg poolId
  return pools[poolId~string]
::method observation
  expose observations
  use arg domainId
  return observations[domainId~string]
::method reservedForDomain
  expose reservations
  use arg domainId
  r=reservations[domainId~string]
  if r==.nil then return 0
  return r+0
::method availableForPool
  expose pools observations reservations
  use arg poolIdArg
  p=pools[poolIdArg~string]
  if p==.nil then return 0
  if \p~canWorkspace then return 0
  o=observations[p~capacityDomainId]
  if o==.nil then return 0
  r=reservations[p~capacityDomainId]
  if r==.nil then r=0
  a=o~freeBytes-r-p~safetyFloorBytes
  if a<0 then a=0
  return a
::method poolsForNode
  expose pools
  use arg nodeArg
  n=nodeArg~string~strip
  a=.array~new
  do key over pools
    p=pools[key]
    if p~nodeId=n then a~append(p)
  end
  return a
::method bestWorkspacePoolForNode
  expose pools
  use arg nodeArg, bytesArg
  n=nodeArg~string~strip
  bytes=bytesArg+0
  best=.nil; bestAvail=-1
  do key over pools
    p=pools[key]
    if p~nodeId=n & p~canWorkspace then do
      av=self~availableForPool(p~poolId)
      if av>=bytes & av>bestAvail then do
        best=p; bestAvail=av
      end
    end
  end
  return best
::method allocate
  expose pools observations reservations allocations sequence
  use arg poolIdArg, bytesArg, ownerArg="", allocationIdArg=""
  p=pools[poolIdArg~string]
  if p==.nil then raise syntax 88.900 array("unknown storage pool")
  if \p~canWorkspace then raise syntax 88.900 array("pool is not a workspace pool")
  bytes=bytesArg+0
  if bytes<=0 then raise syntax 88.900 array("allocation size must be positive")
  if self~availableForPool(p~poolId)<bytes then return .nil
  id=allocationIdArg~string~strip
  if id="" then do
    sequence+=1; id="ws-"||sequence
  end
  if allocations[id]<>.nil then raise syntax 88.900 array("duplicate allocation id")
  root=p~root
  if right(root,1)="/" then root=left(root,length(root)-1)
  locator=root||"/workspaces/"||id
  a=.StorageAllocation~new(id,p,bytes,ownerArg,locator)
  allocations[id]=a
  reservations[p~capacityDomainId]=self~reservedForDomain(p~capacityDomainId)+bytes
  return a
::method allocateBest
  expose pools
  use arg bytesArg, ownerArg="", allocationIdArg=""
  best=.nil; bestAvail=-1
  do key over pools
    p=pools[key]
    if p~canWorkspace then do
      av=self~availableForPool(p~poolId)
      if av>=bytesArg & av>bestAvail then do; best=p; bestAvail=av; end
    end
  end
  if best==.nil then return .nil
  return self~allocate(best~poolId,bytesArg,ownerArg,allocationIdArg)
::method release
  expose allocations reservations
  use arg allocationIdArg
  a=allocations[allocationIdArg~string]
  if a==.nil then return .false
  if a~state=.StorageAllocationState~RELEASED then return .false
  domain=a~pool~capacityDomainId
  r=self~reservedForDomain(domain)-a~reservedBytes
  if r<0 then r=0
  reservations[domain]=r
  a~release
  return .true
::method allocations
  expose allocations
  a=.array~new
  do key over allocations; a~append(allocations[key]); end
  return a

::class StoragePosixDfProbe public
::method sample
  use arg pathArg, observedArg=""
  path=pathArg~string
  if path="" then raise syntax 88.900 array("path is mandatory")
  tmp=SysTempFileName("/tmp/oorexx-storage-df-??????")
  qpath=self~shellQuote(path); qtmp=self~shellQuote(tmp)
  address system "/bin/df -Pk -- "||qpath||" > "||qtmp||" 2>/dev/null"
  rc=rc
  if rc<>0 then do; call SysFileDelete tmp; return .nil; end
  header=linein(tmp)
  data=""
  do while lines(tmp)>0
    x=linein(tmp)
    if x~strip<>"" then data=x
  end
  call stream tmp,"c","close"; call SysFileDelete tmp
  if data="" then return .nil
  /* POSIX -P gives six whitespace-separated fields; mount path may not contain spaces in this profile. */
  filesystem=word(data,1); blocks=word(data,2)+0; available=word(data,4)+0
  if filesystem="" | blocks<0 | available<0 then return .nil
  domain="posixfs:"||filesystem
  return .StorageCapacityObservation~new(domain,blocks*1024,available*1024,observedArg,"","df -Pk "||path)
::method shellQuote private
  use arg s
  /* Single-quote for POSIX shell, escaping embedded single quotes. */
  sq="'"; dq='"'
  replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

::class LocalFilesystemProvider public
::attribute providerId get
::attribute pool get
::method init
  expose providerId pool
  use arg providerArg, poolArg
  providerId=providerArg~string~strip; pool=poolArg
  if providerId="" | pool==.nil then raise syntax 88.900 array("providerId and pool are mandatory")
::method scan
  expose providerId pool
  use arg catalogue, recursiveArg=.true
  if catalogue==.nil then raise syntax 88.900 array("catalogue is mandatory")
  root=pool~root
  pattern=root
  if right(pattern,1)<>"/" then pattern=pattern||"/"
  pattern=pattern||"*"
  opts="FO"
  if recursiveArg==.true then opts="FSO"
  call SysFileTree pattern,"files.",opts
  do i=1 to files.0
    path=files.i
    size=stream(path,"c","query size")
    if datatype(size,"N")=0 then size=0
    id="path:"||providerId||":"||path
    name=self~baseName(path)
    obj=.StorageObject~new(.StorageRef~new(id),name,size,self~mediaType(path))
    obj~addLocation(.StorageLocation~new(providerId,path,pool~capacityDomainId,.StorageLocationState~AVAILABLE,"",.false,""))
    catalogue~put(obj)
  end
  return files.0
::method baseName private
  use arg path
  p=lastpos("/",path)
  if p=0 then return path
  return substr(path,p+1)
::method mediaType private
  use arg path
  p=lastpos(".",path)
  if p=0 then return "application/octet-stream"
  ext=substr(path,p+1)~lower
  select
    when ext="wav" then return "audio/wav"
    when ext="mp3" then return "audio/mpeg"
    when ext="flac" then return "audio/flac"
    when ext="m4a" then return "audio/mp4"
    when ext="mp4" then return "video/mp4"
    when ext="mov" then return "video/quicktime"
    when ext="mkv" then return "video/x-matroska"
    when ext="jpg" | ext="jpeg" then return "image/jpeg"
    when ext="png" then return "image/png"
    otherwise return "application/octet-stream"
  end

::class RemoteNodeStorageProvider public
::attribute providerId get
::attribute nodeId get
::attribute pool get
::method init
  expose providerId nodeId pool
  use arg providerArg, nodeArg, poolArg
  providerId=providerArg~string~strip; nodeId=nodeArg~string~strip; pool=poolArg
  if providerId="" | nodeId="" | pool==.nil then raise syntax 88.900 array("providerId, nodeId and pool are mandatory")
::method ownsTransport
  /* Remote execution/SSH remains outside Storage; this adapter publishes storage. */
  return .false

::class GoogleDriveStorageProvider public
::attribute providerId get
::attribute capacityDomainId get
::attribute rootId get
::attribute accountKey get
::attribute lifecycle get
::method init
  expose providerId capacityDomainId rootId accountKey lifecycle
  use arg providerArg="google-drive", accountKeyArg="default", rootArg="root", lifecycleArg=.nil
  providerId=providerArg~string~strip
  accountKey=accountKeyArg~string~strip
  capacityDomainId="gdrive:"||accountKey
  rootId=rootArg~string
  if lifecycleArg==.nil then lifecycle=.StorageServiceLifecycle~new
  else lifecycle=lifecycleArg
::method canCatalogue
  return .true
::method canDurable
  /* Physical/provider capability.  Whether a copy counts as safety additionally
   * depends on the configured service/account lifecycle. */
  return .true
::method countsAsDurable
  expose lifecycle
  return lifecycle~countsAsDurable
::method canWorkspace
  /* Drive is an offload/durable store, not an execution workspace. */
  return .false
::method requiresStreamingDataPlane
  return .true
::method controlPlaneApi
  return "api.client/0.3+"
::method dataPlaneRequirement
  return "BOUNDED_MEMORY_STREAMING"
::method dataPlaneApi
  return "storage.fabric.streaming/0.1"
::method supportsResumableUpload
  return .true
::method supportsRangeDownload
  return .true
::method resumableChunkQuantumBytes
  return 262144
::method recommendedTransferChunkBytes
  return 8388608

::class StorageTransfer public
::attribute transferId get
::attribute sourceRef get
::attribute sourceLocation get
::attribute targetProviderId get
::attribute targetLocator get
::attribute sizeBytes get
::attribute bytesTransferred get
::attribute state get
::attribute verificationRef get
::attribute failure get
::method init
  expose transferId sourceRef sourceLocation targetProviderId targetLocator sizeBytes bytesTransferred state verificationRef failure
  use arg idArg, refArg, sourceArg, targetProviderArg, targetLocatorArg="", sizeArg=0
  transferId=idArg~string~strip; sourceRef=refArg; sourceLocation=sourceArg
  targetProviderId=targetProviderArg~string~strip; targetLocator=targetLocatorArg~string
  sizeBytes=sizeArg+0; bytesTransferred=0; state=.StorageTransferState~PLANNED; verificationRef=""; failure=""
  if transferId="" | sourceRef==.nil | sourceLocation==.nil | targetProviderId="" then raise syntax 88.900 array("invalid transfer")
::method begin
  expose state
  if state<>.StorageTransferState~PLANNED then return .false
  state=.StorageTransferState~COPYING; return .true
::method progress
  expose state bytesTransferred sizeBytes
  use arg bytesArg
  if state<>.StorageTransferState~COPYING then return .false
  n=bytesArg+0
  if n<bytesTransferred | n>sizeBytes then return .false
  bytesTransferred=n; return .true
::method copied
  expose state bytesTransferred sizeBytes
  if state<>.StorageTransferState~COPYING then return .false
  if bytesTransferred<>sizeBytes then return .false
  state=.StorageTransferState~COPIED; return .true
::method verify
  expose state verificationRef
  use arg verificationArg
  if state<>.StorageTransferState~COPIED then return .false
  if verificationArg~string~strip="" then return .false
  verificationRef=verificationArg~string
  state=.StorageTransferState~VERIFIED; return .true
::method commit
  expose state
  if state<>.StorageTransferState~VERIFIED then return .false
  state=.StorageTransferState~COMMITTED; return .true
::method fail
  expose state failure
  use arg reasonArg
  state=.StorageTransferState~FAILED; failure=reasonArg~string; return self

::class StorageReplicaPolicy public
::method safeToEvict
  use arg object, locationToRemove
  if object==.nil | locationToRemove==.nil then return .false
  /* A verified copy on disposable/unsafe service capacity is still not safety.
   * Never evict unless another AVAILABLE, VERIFIED, SAFE durable location exists. */
  do l over object~locations
    same=(l~providerId=locationToRemove~providerId & l~locator=locationToRemove~locator)
    if \same & l~countsAsDurable then return .true
  end
  return .false
::method durableReplicaCount
  use arg object
  if object==.nil then return 0
  n=0
  do l over object~locations
    if l~countsAsDurable then n+=1
  end
  return n
::method requiredDurabilitySatisfied
  use arg object, requiredArg=1
  return self~durableReplicaCount(object)>=(requiredArg+0)

::class StorageManager public
::attribute catalogue get
::attribute workspace get
::method init
  expose catalogue workspace providers
  catalogue=.StorageCatalogue~new; workspace=.StorageWorkspaceManager~new; providers=.directory~new
::method registerPool
  expose workspace
  use arg pool
  workspace~registerPool(pool); return self
::method observeCapacity
  expose workspace
  use arg observation
  workspace~observeCapacity(observation); return self
::method registerProvider
  expose providers
  use arg providerIdArg, provider
  providers[providerIdArg~string]=provider; return self
::method provider
  expose providers
  use arg providerIdArg
  return providers[providerIdArg~string]
::method search
  expose catalogue
  use arg q, limit=100
  return catalogue~search(q,limit)

/* -------------------------------------------------------------------------
 * v0.1-dev2 namespace / EA / environment model.
 *
 * Object identity, physical location, namespace path and path policy are
 * deliberately separate.  A namespace is a projection over StorageRefs;
 * query folders are catalogue filters; Test/Development can overlay Live
 * without copying immutable source objects.
 * ---------------------------------------------------------------------- */

::class StorageWritePolicy public
::constant READ_ONLY "READ_ONLY"
::constant DIRECT "DIRECT"
::constant COPY_ON_WRITE "COPY_ON_WRITE"
::constant TRACKED "TRACKED"
::constant VERSIONED "VERSIONED"
::constant APPEND_ONLY "APPEND_ONLY"
::constant EPHEMERAL "EPHEMERAL"

::class StorageEnvironmentKind public
::constant LIVE "LIVE"
::constant TEST "TEST"
::constant DEVELOPMENT "DEVELOPMENT"

::class StorageNamespaceEntryKind public
::constant STATIC "STATIC"
::constant QUERY "QUERY"
::constant INHERITED "INHERITED"
::constant CHANGESET "CHANGESET"
::constant ALIAS "ALIAS"
::constant UNION "UNION"

::class StorageResolutionStatus public
::constant FOUND "FOUND"
::constant NOT_FOUND "NOT_FOUND"
::constant AMBIGUOUS "AMBIGUOUS"
::constant LINK_LOOP "LINK_LOOP"

::class StorageChangeOperation public
::constant WRITE "WRITE"
::constant UNLINK "UNLINK"

::class StorageProviderAvailability public
::constant ALWAYS "ALWAYS"
::constant INTERMITTENT "INTERMITTENT"
::constant REMOTE "REMOTE"

::class StoragePath public
::method normalize class
  use arg pathArg
  p=pathArg~string~strip
  if p="" then return "/"
  p=changestr("\",p,"/")
  do while p~pos("//")>0
    p=changestr("//",p,"/")
  end
  if left(p,1)<>"/" then p="/"||p
  if length(p)>1 & right(p,1)="/" then p=left(p,length(p)-1)
  return p
::method parent class
  use arg pathArg
  p=self~normalize(pathArg)
  if p="/" then return "/"
  x=lastpos("/",p)
  if x<=1 then return "/"
  return left(p,x-1)
::method name class
  use arg pathArg
  p=self~normalize(pathArg)
  if p="/" then return "/"
  x=lastpos("/",p)
  return substr(p,x+1)
::method join class
  use arg parentArg, nameArg
  p=self~normalize(parentArg)
  n=nameArg~string
  if p="/" then return self~normalize("/"||n)
  return self~normalize(p||"/"||n)
::method isDirectChild class
  use arg childArg, parentArg
  child=self~normalize(childArg); parent=self~normalize(parentArg)
  if child=parent then return .false
  return self~parent(child)=parent

::class StorageEA public
::attribute namespace get
::attribute name get
::attribute type get
::attribute value get
::attribute provenance get
::attribute authority get
::attribute createdAt get
::method init
  expose namespace name type value provenance authority createdAt
  use arg namespaceArg, nameArg, valueArg, typeArg="STRING", provenanceArg="", authorityArg="", createdArg=""
  namespace=namespaceArg~string~strip
  name=nameArg~string~strip
  value=valueArg
  type=typeArg~string~strip~upper
  provenance=provenanceArg~string
  authority=authorityArg~string
  createdAt=createdArg~string
  if namespace="" | name="" then raise syntax 88.900 array("EA namespace and name are mandatory")
::method key
  expose namespace name
  return namespace~lower||"."||name~lower

::class StorageEASet public
::method init
  expose values
  values=.directory~new
::method put
  expose values
  use arg ea
  if ea==.nil then raise syntax 88.900 array("EA is mandatory")
  values[ea~key]=ea
  return ea
::method get
  expose values
  use arg keyArg
  return values[keyArg~string~strip~lower]
::method remove
  expose values
  use arg keyArg
  k=keyArg~string~strip~lower
  if values[k]==.nil then return .false
  values~remove(k)
  return .true
::method all
  expose values
  a=.array~new
  do k over values
    a~append(values[k])
  end
  return a
::method serialize
  expose values
  records=.array~new
  do k over values
    ea=values[k]
    rec=.StorageCodec~enc(ea~namespace)||"1F"x||.StorageCodec~enc(ea~name)||"1F"x||.StorageCodec~enc(ea~type)||"1F"x||.StorageCodec~enc(ea~value)||"1F"x||.StorageCodec~enc(ea~provenance)||"1F"x||.StorageCodec~enc(ea~authority)||"1F"x||.StorageCodec~enc(ea~createdAt)
    records~append(rec)
  end
  out=""
  do i=1 to records~items
    if i>1 then out=out||"1E"x
    out=out||records[i]
  end
  return out
::method loadSerialized
  use arg serializedArg
  s=serializedArg~string
  if s="" then return self
  start=1
  do forever
    p=pos("1E"x,s,start)
    if p=0 then do; rec=substr(s,start); done=.true; end
    else do; rec=substr(s,start,p-start); done=.false; end
    fields=.array~new; fs=1
    do forever
      fp=pos("1F"x,rec,fs)
      if fp=0 then do; fields~append(substr(rec,fs)); leave; end
      fields~append(substr(rec,fs,fp-fs)); fs=fp+1
    end
    if fields~items>=7 then self~put(.StorageEA~new(.StorageCodec~dec(fields[1]),.StorageCodec~dec(fields[2]),.StorageCodec~dec(fields[4]),.StorageCodec~dec(fields[3]),.StorageCodec~dec(fields[5]),.StorageCodec~dec(fields[6]),.StorageCodec~dec(fields[7])))
    if done then leave
    start=p+1
  end
  return self
::method count
  expose values
  return values~items

::class StorageFilterClause public
::attribute field get
::attribute operator get
::attribute expected get
::method init
  expose field operator expected
  use arg fieldArg, expectedArg="", operatorArg="EQ"
  field=fieldArg~string~strip
  operator=operatorArg~string~strip~upper
  expected=expectedArg
  if field="" then raise syntax 88.900 array("filter field is mandatory")
::method matches
  use arg object
  if object==.nil then return .false
  actual=self~fieldValue(object)
  op=self~operator
  if op="EXISTS" then return actual<>.nil
  if actual==.nil then return .false
  a=actual~string; e=self~expected~string
  select
    when op="EQ" then return a~lower=e~lower
    when op="EXACT" then return a=e
    when op="CONTAINS" then return a~lower~pos(e~lower)>0
    when op="PREFIX" then return left(a~lower,length(e))=e~lower
    when op="GT" then do; if datatype(a,"N")=0 | datatype(e,"N")=0 then return .false; return a+0>e+0; end
    when op="GE" then do; if datatype(a,"N")=0 | datatype(e,"N")=0 then return .false; return a+0>=e+0; end
    when op="LT" then do; if datatype(a,"N")=0 | datatype(e,"N")=0 then return .false; return a+0<e+0; end
    when op="LE" then do; if datatype(a,"N")=0 | datatype(e,"N")=0 then return .false; return a+0<=e+0; end
    otherwise raise syntax 88.900 array("unsupported filter operator: "||op)
  end
::method fieldValue private
  use arg object
  f=self~field~lower
  select
    when f="name" | f="displayname" then return object~displayName
    when f="mediatype" | f="media.type" then return object~mediaType
    when f="size" | f="sizebytes" then return object~sizeBytes
    otherwise do
      if left(f,3)="ea:" then do
        key=substr(f,4)
        ea=object~ea(key)
        if ea==.nil then return .nil
        return ea~value
      end
      return .nil
    end
  end

::class StorageFilter public
::method init
  expose clauses
  clauses=.array~new
::method add
  expose clauses
  use arg clause
  if clause==.nil then raise syntax 88.900 array("filter clause is mandatory")
  clauses~append(clause)
  return self
::method matches
  expose clauses
  use arg object
  do c over clauses
    if \c~matches(object) then return .false
  end
  return .true
::method count
  expose clauses
  return clauses~items

::class StorageNamespaceEntry public
::attribute path get
::attribute ref get
::attribute writePolicy get
::attribute kind get
::attribute origin get
::method init
  expose path ref writePolicy kind origin
  use arg pathArg, refArg, policyArg="READ_ONLY", kindArg="STATIC", originArg=""
  path=.StoragePath~normalize(pathArg)
  ref=refArg
  writePolicy=policyArg~string~strip~upper
  kind=kindArg~string~strip~upper
  origin=originArg~string
  if ref==.nil then raise syntax 88.900 array("namespace entry ref is mandatory")

::class StorageQueryFolder public
::attribute path get
::attribute filter get
::attribute writePolicy get
::method init
  expose path filter writePolicy
  use arg pathArg, filterArg, policyArg="READ_ONLY"
  path=.StoragePath~normalize(pathArg)
  filter=filterArg
  writePolicy=policyArg~string~strip~upper
  if filter==.nil then raise syntax 88.900 array("query folder filter is mandatory")

::class StoragePathAlias public
::attribute path get
::attribute targetPath get
::attribute writePolicy get
::method init
  expose path targetPath writePolicy
  use arg pathArg, targetArg, policyArg="READ_ONLY"
  path=.StoragePath~normalize(pathArg)
  targetPath=.StoragePath~normalize(targetArg)
  writePolicy=policyArg~string~strip~upper
  if path=targetPath then raise syntax 88.900 array("alias path and target path must differ")

::class StorageResolution public
::attribute status get
::attribute entry get
::attribute message get
::method init
  expose status entry message
  use arg statusArg, entryArg=.nil, messageArg=""
  status=statusArg~string~strip~upper
  entry=entryArg
  message=messageArg~string
::method found
  expose status
  return status=.StorageResolutionStatus~FOUND

::class StorageEnvironment public
::attribute environmentId get
::attribute kind get
::attribute parentId get
::attribute baseGeneration get
::attribute generation get
::attribute defaultWritePolicy get
::method init
  expose environmentId kind parentId baseGeneration generation defaultWritePolicy
  use arg idArg, kindArg, parentArg="", baseGenerationArg=0, generationArg=0, policyArg=""
  environmentId=idArg~string~strip
  kind=kindArg~string~strip~upper
  parentId=parentArg~string~strip
  baseGeneration=baseGenerationArg+0
  generation=generationArg+0
  defaultWritePolicy=policyArg~string~strip~upper
  if environmentId="" then raise syntax 88.900 array("environment id is mandatory")
  if defaultWritePolicy="" then do
    select
      when kind=.StorageEnvironmentKind~LIVE then defaultWritePolicy=.StorageWritePolicy~VERSIONED
      when kind=.StorageEnvironmentKind~TEST then defaultWritePolicy=.StorageWritePolicy~COPY_ON_WRITE
      when kind=.StorageEnvironmentKind~DEVELOPMENT then defaultWritePolicy=.StorageWritePolicy~TRACKED
      otherwise defaultWritePolicy=.StorageWritePolicy~READ_ONLY
    end
  end
::method save
  expose environmentId kind parentId baseGeneration generation defaultWritePolicy
  use arg pathArg
  path=pathArg~string
  call SysFileDelete path
  line="ENV"||"09"x||.StorageCodec~enc(environmentId)||"09"x||kind||"09"x||.StorageCodec~enc(parentId)||"09"x||baseGeneration||"09"x||generation||"09"x||defaultWritePolicy
  call lineout path,line
  call lineout path
  return self
::method load class
  use arg pathArg
  path=pathArg~string
  if stream(path,"c","query exists")="" then return .nil
  line=linein(path)
  call stream path,"c","close"
  f=.StorageCodec~splitTabs(line)
  if f~items<7 | f[1]<>"ENV" then return .nil
  return .StorageEnvironment~new(.StorageCodec~dec(f[2]),f[3],.StorageCodec~dec(f[4]),f[5]+0,f[6]+0,f[7])
::method advanceGeneration
  expose generation
  generation+=1
  return generation

::class StorageChange public
::attribute operation get
::attribute path get
::attribute baseRef get
::attribute newRef get
::attribute writePolicy get
::attribute sequence get
::method init
  expose operation path baseRef newRef writePolicy sequence
  use arg operationArg, pathArg, baseArg=.nil, newArg=.nil, policyArg="", sequenceArg=0
  operation=operationArg~string~strip~upper
  path=.StoragePath~normalize(pathArg)
  baseRef=baseArg; newRef=newArg
  writePolicy=policyArg~string~strip~upper
  sequence=sequenceArg+0

::class StorageChangeSet public
::attribute changeSetId get
::attribute environmentId get
::attribute baseGeneration get
::attribute sealed get
::method init
  expose changeSetId environmentId baseGeneration sealed changes sequence
  use arg idArg, environmentArg, baseGenerationArg=0
  changeSetId=idArg~string~strip
  environmentId=environmentArg~string~strip
  baseGeneration=baseGenerationArg+0
  sealed=.false
  changes=.directory~new; sequence=0
  if changeSetId="" | environmentId="" then raise syntax 88.900 array("change set id and environment are mandatory")
::method recordWrite
  expose sealed changes sequence
  use arg pathArg, baseRef, newRef, policyArg=""
  if sealed then return .false
  if newRef==.nil then raise syntax 88.900 array("new ref is mandatory")
  sequence+=1
  p=.StoragePath~normalize(pathArg)
  changes[p]=.StorageChange~new(.StorageChangeOperation~WRITE,p,baseRef,newRef,policyArg,sequence)
  return .true
::method recordUnlink
  expose sealed changes sequence
  use arg pathArg, baseRef=.nil, policyArg=""
  if sealed then return .false
  sequence+=1
  p=.StoragePath~normalize(pathArg)
  changes[p]=.StorageChange~new(.StorageChangeOperation~UNLINK,p,baseRef,.nil,policyArg,sequence)
  return .true
::method get
  expose changes
  use arg pathArg
  return changes[.StoragePath~normalize(pathArg)]
::method all
  expose changes
  a=.array~new
  do p over changes
    a~append(changes[p])
  end
  return a
::method count
  expose changes
  return changes~items
::method restoreChange
  expose sealed changes sequence
  use arg change
  if change==.nil then return .false
  changes[change~path]=change
  if change~sequence>sequence then sequence=change~sequence
  return .true
::method save
  expose changeSetId environmentId baseGeneration sealed changes
  use arg pathArg
  path=pathArg~string
  call SysFileDelete path
  header="CHANGESET"||"09"x||.StorageCodec~enc(changeSetId)||"09"x||.StorageCodec~enc(environmentId)||"09"x||baseGeneration||"09"x||sealed
  call lineout path,header
  do p over changes
    ch=changes[p]
    baseId=""; baseDigest=""; newId=""; newDigest=""
    if ch~baseRef<>.nil then do; baseId=ch~baseRef~objectId; baseDigest=ch~baseRef~digest; end
    if ch~newRef<>.nil then do; newId=ch~newRef~objectId; newDigest=ch~newRef~digest; end
    line="CHANGE"||"09"x||ch~sequence||"09"x||ch~operation||"09"x||.StorageCodec~enc(ch~path)||"09"x||.StorageCodec~enc(baseId)||"09"x||.StorageCodec~enc(baseDigest)||"09"x||.StorageCodec~enc(newId)||"09"x||.StorageCodec~enc(newDigest)||"09"x||ch~writePolicy
    call lineout path,line
  end
  call lineout path
  return self
::method load class
  use arg pathArg
  path=pathArg~string
  if stream(path,"c","query exists")="" then return .nil
  header=linein(path)
  hf=.StorageCodec~splitTabs(header)
  if hf~items<5 | hf[1]<>"CHANGESET" then do; call stream path,"c","close"; return .nil; end
  cs=.StorageChangeSet~new(.StorageCodec~dec(hf[2]),.StorageCodec~dec(hf[3]),hf[4]+0)
  do while lines(path)>0
    line=linein(path)
    if line="" then iterate
    f=.StorageCodec~splitTabs(line)
    if f~items<9 | f[1]<>"CHANGE" then iterate
    base=.nil; new=.nil
    baseId=.StorageCodec~dec(f[5]); newId=.StorageCodec~dec(f[7])
    if baseId<>"" then base=.StorageRef~new(baseId,.StorageCodec~dec(f[6]))
    if newId<>"" then new=.StorageRef~new(newId,.StorageCodec~dec(f[8]))
    ch=.StorageChange~new(f[3],.StorageCodec~dec(f[4]),base,new,f[9],f[2]+0)
    cs~restoreChange(ch)
  end
  call stream path,"c","close"
  if hf[5]="1" then cs~seal
  return cs
::method seal
  expose sealed
  sealed=.true
  return self

::class StorageMutationDecision public
::attribute allowed get
::attribute action get
::attribute path get
::attribute message get
::method init
  expose allowed action path message
  use arg allowedArg, actionArg, pathArg, messageArg=""
  allowed=(allowedArg==.true)
  action=actionArg~string~strip~upper
  path=.StoragePath~normalize(pathArg)
  message=messageArg~string

::class StorageNamespace public
::attribute namespaceId get
::attribute catalogue get
::attribute environment get
::attribute parent get
::method init
  expose namespaceId catalogue environment parent bindings queryFolders exclusions aliases
  use arg idArg, catalogueArg, environmentArg, parentArg=.nil
  namespaceId=idArg~string~strip
  catalogue=catalogueArg
  environment=environmentArg
  parent=parentArg
  bindings=.directory~new
  queryFolders=.directory~new
  exclusions=.directory~new
  aliases=.directory~new
  if namespaceId="" | catalogue==.nil | environment==.nil then raise syntax 88.900 array("namespace id, catalogue and environment are mandatory")
::method bind
  expose bindings environment aliases
  use arg pathArg, refArg, policyArg=""
  p=.StoragePath~normalize(pathArg)
  policy=policyArg~string~strip~upper
  if policy="" then policy=environment~defaultWritePolicy
  if aliases[p]<>.nil then aliases~remove(p)
  bindings[p]=.StorageNamespaceEntry~new(p,refArg,policy,.StorageNamespaceEntryKind~STATIC,namespaceId)
  return bindings[p]
::method localBinding
  expose bindings
  use arg pathArg
  return bindings[.StoragePath~normalize(pathArg)]
::method unlinkLocal
  expose bindings
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  if bindings[p]==.nil then return .false
  bindings~remove(p)
  return .true
::method addQueryFolder
  expose queryFolders
  use arg folder
  if folder==.nil then raise syntax 88.900 array("query folder is mandatory")
  queryFolders[folder~path]=folder
  return self
::method queryFolder
  expose queryFolders
  use arg pathArg
  return queryFolders[.StoragePath~normalize(pathArg)]
::method addAlias
  expose aliases bindings
  use arg pathArg, targetArg, policyArg="READ_ONLY"
  a=.StoragePathAlias~new(pathArg,targetArg,policyArg)
  if bindings[a~path]<>.nil then bindings~remove(a~path)
  aliases[a~path]=a
  return a
::method alias
  expose aliases
  use arg pathArg
  return aliases[.StoragePath~normalize(pathArg)]
::method removeAlias
  expose aliases
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  if aliases[p]==.nil then return .false
  aliases~remove(p)
  return .true
::method resolve
  use arg pathArg, changeSet=.nil
  return self~resolveDepth(.StoragePath~normalize(pathArg),changeSet,0)
::method resolveDepth private
  expose environment parent aliases
  use arg p, changeSet=.nil, depth=0
  if depth>16 then return .StorageResolution~new(.StorageResolutionStatus~LINK_LOOP,.nil,"alias resolution depth exceeded")
  if changeSet<>.nil then do
    ch=changeSet~get(p)
    if ch<>.nil then do
      if ch~operation=.StorageChangeOperation~UNLINK then return .StorageResolution~new(.StorageResolutionStatus~NOT_FOUND,.nil,"hidden by change set")
      return .StorageResolution~new(.StorageResolutionStatus~FOUND,.StorageNamespaceEntry~new(p,ch~newRef,ch~writePolicy,.StorageNamespaceEntryKind~CHANGESET,changeSet~changeSetId),"change-set overlay")
    end
  end
  r=self~resolveLocal(p)
  if r~status<>.StorageResolutionStatus~NOT_FOUND then return r
  a=aliases[p]
  if a<>.nil then do
    tr=self~resolveDepth(a~targetPath,changeSet,depth+1)
    if tr~found=.false then return tr
    ae=.StorageNamespaceEntry~new(p,tr~entry~ref,a~writePolicy,.StorageNamespaceEntryKind~ALIAS,a~targetPath)
    return .StorageResolution~new(.StorageResolutionStatus~FOUND,ae,"path alias -> "||a~targetPath)
  end
  if parent<>.nil then do
    pr=parent~resolve(p)
    if pr~found then do
      pe=pr~entry
      inherited=.StorageNamespaceEntry~new(p,pe~ref,environment~defaultWritePolicy,.StorageNamespaceEntryKind~INHERITED,parent~namespaceId)
      return .StorageResolution~new(.StorageResolutionStatus~FOUND,inherited,"inherited projection")
    end
    if pr~status=.StorageResolutionStatus~AMBIGUOUS | pr~status=.StorageResolutionStatus~LINK_LOOP then return pr
  end
  return .StorageResolution~new(.StorageResolutionStatus~NOT_FOUND,.nil,"path not present")
::method resolveLocal private
  expose bindings queryFolders exclusions catalogue namespaceId
  use arg p
  e=bindings[p]
  if e<>.nil then return .StorageResolution~new(.StorageResolutionStatus~FOUND,e,"static binding")
  folderPath=.StoragePath~parent(p)
  folder=queryFolders[folderPath]
  if folder==.nil then return .StorageResolution~new(.StorageResolutionStatus~NOT_FOUND,.nil,"")
  wanted=.StoragePath~name(p)
  found=.array~new
  do obj over catalogue~all
    if obj~displayName=wanted & folder~filter~matches(obj) then do
      k=folderPath||"|"||obj~ref~objectId
      if exclusions[k]==.nil then found~append(obj)
    end
  end
  if found~items=0 then return .StorageResolution~new(.StorageResolutionStatus~NOT_FOUND,.nil,"query result absent")
  if found~items>1 then return .StorageResolution~new(.StorageResolutionStatus~AMBIGUOUS,.nil,"more than one object projects to this path")
  obj=found[1]
  qe=.StorageNamespaceEntry~new(p,obj~ref,folder~writePolicy,.StorageNamespaceEntryKind~QUERY,"QUERY:"||folderPath)
  return .StorageResolution~new(.StorageResolutionStatus~FOUND,qe,"query projection")
::method list
  expose bindings queryFolders exclusions catalogue parent environment aliases
  use arg folderArg, changeSet=.nil
  folderPath=.StoragePath~normalize(folderArg)
  answer=.array~new
  hidden=.directory~new
  /* Parent first; child entries below can shadow the same path. */
  if parent<>.nil then do
    pa=parent~list(folderPath)
    do pe over pa
      ie=.StorageNamespaceEntry~new(pe~path,pe~ref,environment~defaultWritePolicy,.StorageNamespaceEntryKind~INHERITED,parent~namespaceId)
      answer~append(ie)
    end
  end
  /* Explicit child bindings shadow inherited entries. */
  do p over bindings
    if .StoragePath~isDirectChild(p,folderPath) then do
      self~removePathFromArray(answer,p)
      answer~append(bindings[p])
    end
  end
  /* Path aliases are fluid names: their target is resolved at view time. */
  do p over aliases
    if .StoragePath~isDirectChild(p,folderPath) then do
      self~removePathFromArray(answer,p)
      ar=self~resolve(p,changeSet)
      if ar~found then answer~append(ar~entry)
    end
  end
  qf=queryFolders[folderPath]
  if qf<>.nil then do obj over catalogue~all
    if qf~filter~matches(obj) then do
      k=folderPath||"|"||obj~ref~objectId
      if exclusions[k]==.nil then do
        p=.StoragePath~join(folderPath,obj~displayName)
        /* Query collisions intentionally remain as duplicate paths; resolve() reports AMBIGUOUS. */
        answer~append(.StorageNamespaceEntry~new(p,obj~ref,qf~writePolicy,.StorageNamespaceEntryKind~QUERY,"QUERY:"||folderPath))
      end
    end
  end
  if changeSet<>.nil then do ch over changeSet~all
    if .StoragePath~isDirectChild(ch~path,folderPath) then do
      self~removePathFromArray(answer,ch~path)
      if ch~operation=.StorageChangeOperation~WRITE then answer~append(.StorageNamespaceEntry~new(ch~path,ch~newRef,ch~writePolicy,.StorageNamespaceEntryKind~CHANGESET,changeSet~changeSetId))
    end
  end
  return answer
::method removePathFromArray private
  use arg a, pathArg
  /* Array holes are allowed; compact into a replacement then copy back. */
  keep=.array~new
  do e over a
    if e~path<>pathArg then keep~append(e)
  end
  a~empty
  do e over keep; a~append(e); end
  return a
::method exclude
  expose exclusions queryFolders
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  r=self~resolveLocal(p)
  if \r~found then return .false
  e=r~entry
  if e~kind<>.StorageNamespaceEntryKind~QUERY then return .false
  folderPath=.StoragePath~parent(p)
  exclusions[folderPath||"|"||e~ref~objectId]=.true
  return .true
::method applyWrite
  expose environment
  use arg pathArg, newRef, changeSet=.nil
  p=.StoragePath~normalize(pathArg)
  if newRef==.nil then raise syntax 88.900 array("new ref is mandatory")
  r=self~resolve(p,changeSet)
  if \r~found then return .StorageMutationDecision~new(.false,"DENY",p,"path is not resolvable")
  e=r~entry; policy=e~writePolicy
  if e~kind=.StorageNamespaceEntryKind~ALIAS & (policy=.StorageWritePolicy~DIRECT | policy=.StorageWritePolicy~VERSIONED) then do
    a=self~alias(p)
    if a==.nil then return .StorageMutationDecision~new(.false,"DENY",p,"alias metadata unavailable")
    target=self~localBinding(a~targetPath)
    if target==.nil then return .StorageMutationDecision~new(.false,"DENY",p,"direct/versioned alias target must be a local binding")
    if policy=.StorageWritePolicy~VERSIONED then do
      if changeSet==.nil then return .StorageMutationDecision~new(.false,"DENY",p,"versioned alias write requires change evidence")
      changeSet~recordWrite(p,e~ref,newRef,policy)
    end
    self~bind(a~targetPath,newRef,target~writePolicy)
    return .StorageMutationDecision~new(.true,"ALIAS_"||policy,p,"alias target binding advanced")
  end
  select
    when policy=.StorageWritePolicy~READ_ONLY then return .StorageMutationDecision~new(.false,"DENY",p,"view is read-only")
    when policy=.StorageWritePolicy~APPEND_ONLY then return .StorageMutationDecision~new(.false,"DENY",p,"existing append-only entry cannot be replaced")
    when policy=.StorageWritePolicy~DIRECT then do
      self~bind(p,newRef,policy)
      return .StorageMutationDecision~new(.true,"DIRECT_WRITE",p,"namespace binding advanced")
    end
    when policy=.StorageWritePolicy~VERSIONED then do
      if changeSet==.nil then return .StorageMutationDecision~new(.false,"DENY",p,"versioned write requires change evidence")
      changeSet~recordWrite(p,e~ref,newRef,policy)
      self~bind(p,newRef,policy)
      return .StorageMutationDecision~new(.true,"VERSIONED_WRITE",p,"new version bound and change recorded")
    end
    when policy=.StorageWritePolicy~COPY_ON_WRITE then do
      if changeSet==.nil then return .StorageMutationDecision~new(.false,"DENY",p,"copy-on-write requires an overlay change set")
      changeSet~recordWrite(p,e~ref,newRef,policy)
      return .StorageMutationDecision~new(.true,"COPY_ON_WRITE",p,"base binding left untouched")
    end
    when policy=.StorageWritePolicy~TRACKED then do
      if changeSet==.nil then return .StorageMutationDecision~new(.false,"DENY",p,"tracked write requires a change set")
      changeSet~recordWrite(p,e~ref,newRef,policy)
      return .StorageMutationDecision~new(.true,"TRACKED_WRITE",p,"change recorded; base binding left untouched")
    end
    when policy=.StorageWritePolicy~EPHEMERAL then do
      if changeSet==.nil then return .StorageMutationDecision~new(.false,"DENY",p,"ephemeral write requires an overlay")
      changeSet~recordWrite(p,e~ref,newRef,policy)
      return .StorageMutationDecision~new(.true,"EPHEMERAL_WRITE",p,"ephemeral overlay recorded")
    end
    otherwise return .StorageMutationDecision~new(.false,"DENY",p,"unsupported write policy")
  end
::method applyUnlink
  use arg pathArg, changeSet=.nil
  p=.StoragePath~normalize(pathArg)
  r=self~resolve(p,changeSet)
  if \r~found then return .StorageMutationDecision~new(.false,"DENY",p,"path is not resolvable")
  e=r~entry
  if e~writePolicy=.StorageWritePolicy~READ_ONLY then return .StorageMutationDecision~new(.false,"DENY",p,"view is read-only")
  if e~kind=.StorageNamespaceEntryKind~QUERY then do
    if self~exclude(p) then return .StorageMutationDecision~new(.true,"EXCLUDE",p,"query projection hidden; object not destroyed")
  end
  if e~writePolicy=.StorageWritePolicy~COPY_ON_WRITE | e~writePolicy=.StorageWritePolicy~TRACKED | e~writePolicy=.StorageWritePolicy~EPHEMERAL then do
    if changeSet==.nil then return .StorageMutationDecision~new(.false,"DENY",p,"overlay unlink requires change set")
    changeSet~recordUnlink(p,e~ref,e~writePolicy)
    return .StorageMutationDecision~new(.true,"OVERLAY_UNLINK",p,"base namespace left untouched")
  end
  if self~unlinkLocal(p) then return .StorageMutationDecision~new(.true,"UNLINK",p,"namespace binding removed; storage object not destroyed")
  return .StorageMutationDecision~new(.false,"DENY",p,"inherited entry cannot be destructively unlinked without an overlay")

::class StoragePromotionPlan public
::attribute changeSet get
::attribute targetNamespace get
::attribute expectedGeneration get
::attribute valid get
::attribute message get
::method init
  expose changeSet targetNamespace expectedGeneration valid message
  use arg changeSetArg, targetArg, expectedGenerationArg
  changeSet=changeSetArg; targetNamespace=targetArg; expectedGeneration=expectedGenerationArg+0
  valid=.false; message=""
  if changeSet==.nil | targetNamespace==.nil then do; message="change set and target namespace are mandatory"; return; end
  if \changeSet~sealed then do; message="change set must be sealed"; return; end
  if targetNamespace~environment~generation<>expectedGeneration then do; message="target generation moved"; return; end
  valid=.true; message="preflight valid"
::method apply
  expose changeSet targetNamespace expectedGeneration valid message
  if \valid then return .false
  if targetNamespace~environment~generation<>expectedGeneration then do; valid=.false; message="target generation moved before apply"; return .false; end
  do ch over changeSet~all
    if ch~operation=.StorageChangeOperation~WRITE then targetNamespace~bind(ch~path,ch~newRef,targetNamespace~environment~defaultWritePolicy)
    else if ch~operation=.StorageChangeOperation~UNLINK then targetNamespace~unlinkLocal(ch~path)
  end
  targetNamespace~environment~advanceGeneration
  message="promotion applied"
  return .true

::class StoragePerformanceObservation public
::attribute providerId get
::attribute sequentialReadMBps get
::attribute sequentialWriteMBps get
::attribute latencyMs get
::attribute observedAt get
::attribute evidenceRef get
::method init
  expose providerId sequentialReadMBps sequentialWriteMBps latencyMs observedAt evidenceRef
  use arg providerArg, readArg=0, writeArg=0, latencyArg=0, observedArg="", evidenceArg=""
  providerId=providerArg~string~strip
  sequentialReadMBps=readArg+0; sequentialWriteMBps=writeArg+0; latencyMs=latencyArg+0
  observedAt=observedArg~string; evidenceRef=evidenceArg~string
  if providerId="" then raise syntax 88.900 array("performance provider id is mandatory")
  if sequentialReadMBps<0 | sequentialWriteMBps<0 | latencyMs<0 then raise syntax 88.900 array("performance values must not be negative")

::class StoragePerformanceBook public
::method init
  expose latest
  latest=.directory~new
::method observe
  expose latest
  use arg observation
  if observation==.nil then raise syntax 88.900 array("performance observation is mandatory")
  latest[observation~providerId]=observation
  return self
::method latestFor
  expose latest
  use arg providerArg
  return latest[providerArg~string]

::class RemovableStorageProvider public
::attribute providerId get
::attribute volumeId get
::attribute filesystemId get
::attribute mountPath get
::attribute state get
::method init
  expose providerId volumeId filesystemId mountPath state
  use arg providerArg, volumeArg, filesystemArg="", mountArg=""
  providerId=providerArg~string~strip
  volumeId=volumeArg~string~strip
  filesystemId=filesystemArg~string~strip
  mountPath=mountArg~string
  if providerId="" | volumeId="" then raise syntax 88.900 array("removable provider id and stable volume id are mandatory")
  if mountPath="" then state=.StorageLocationState~OFFLINE
  else state=.StorageLocationState~AVAILABLE
::method availability
  return .StorageProviderAvailability~INTERMITTENT
::method canCatalogue
  return .true
::method canDurable
  return .true
::method canWorkspace
  expose state
  return state=.StorageLocationState~AVAILABLE
::method connect
  expose mountPath state
  use arg mountArg
  m=mountArg~string~strip
  if m="" then raise syntax 88.900 array("mount path is mandatory")
  mountPath=.StoragePath~normalize(m)
  state=.StorageLocationState~AVAILABLE
  return self
::method disconnect
  expose mountPath state
  mountPath=""
  state=.StorageLocationState~OFFLINE
  return self
::method stableIdentity
  expose providerId volumeId filesystemId
  return providerId||":"||volumeId||":"||filesystemId


/* -------------------------------------------------------------------------
 * v0.1-dev5 service-lifecycle safety and locality evidence.
 *
 * "Fast" and "large" are not synonyms for "safe".  A pool can be excellent
 * scratch/workspace while its provider/account lifecycle makes it unsuitable
 * as a durable replica.  Placement evidence reports movement and capacity
 * facts to Job-to-Node Allocation; it does not override that component's hard
 * security/legal/runtime eligibility decisions.
 * ---------------------------------------------------------------------- */

::class StoragePlacementAction public
::constant JOB_TO_DATA "JOB_TO_DATA"
::constant DATA_TO_JOB "DATA_TO_JOB"
::constant MIXED "MIXED"
::constant INFEASIBLE "INFEASIBLE"

::class StoragePlacementEvidence public
::attribute nodeId get
::attribute feasible get
::attribute pool get
::attribute workspaceRequiredBytes get
::attribute workspaceAvailableBytes get
::attribute inputBytes get
::attribute localInputBytes get
::attribute materializeBytes get
::attribute jobPackageBytes get
::attribute expectedOutputBytes get
::attribute mandatoryOutputCommitBytes get
::attribute movementBytes get
::attribute action get
::attribute message get
::method init
  expose nodeId feasible pool workspaceRequiredBytes workspaceAvailableBytes inputBytes localInputBytes materializeBytes jobPackageBytes expectedOutputBytes mandatoryOutputCommitBytes movementBytes action message
  use arg nodeArg, feasibleArg=.false, poolArg=.nil, workspaceReqArg=0, workspaceAvailArg=0, inputArg=0, localArg=0, materializeArg=0, jobArg=0, outputArg=0, outputCommitArg=0, actionArg="INFEASIBLE", messageArg=""
  nodeId=nodeArg~string~strip
  feasible=(feasibleArg==.true)
  pool=poolArg
  workspaceRequiredBytes=workspaceReqArg+0
  workspaceAvailableBytes=workspaceAvailArg+0
  inputBytes=inputArg+0
  localInputBytes=localArg+0
  materializeBytes=materializeArg+0
  jobPackageBytes=jobArg+0
  expectedOutputBytes=outputArg+0
  mandatoryOutputCommitBytes=outputCommitArg+0
  movementBytes=jobPackageBytes+materializeBytes+mandatoryOutputCommitBytes
  action=actionArg~string~strip~upper
  message=messageArg~string

::class StoragePlacementAdvisor public
::method assessCandidate
  use arg nodeArg, inputObjects, workspaceBytesArg, jobPackageBytesArg=0, expectedOutputBytesArg=0, workspaceManager
  node=nodeArg~string~strip
  workspaceBytes=workspaceBytesArg+0
  jobBytes=jobPackageBytesArg+0
  outputBytes=expectedOutputBytesArg+0
  if node="" | workspaceManager==.nil then raise syntax 88.900 array("node and workspace manager are mandatory")
  if workspaceBytes<0 | jobBytes<0 | outputBytes<0 then raise syntax 88.900 array("placement sizes must not be negative")
  if inputObjects==.nil then inputObjects=.array~new
  inputBytes=0; localBytes=0
  do obj over inputObjects
    if obj==.nil then iterate
    inputBytes+=obj~sizeBytes
    local=.false
    do loc over obj~locations
      if loc~state=.StorageLocationState~AVAILABLE & loc~nodeId=node then do
        local=.true
        leave
      end
    end
    if local then localBytes+=obj~sizeBytes
  end
  materialize=inputBytes-localBytes
  pool=workspaceManager~bestWorkspacePoolForNode(node,workspaceBytes)
  if pool==.nil then return .StoragePlacementEvidence~new(node,.false,.nil,workspaceBytes,0,inputBytes,localBytes,materialize,jobBytes,outputBytes,0,.StoragePlacementAction~INFEASIBLE,"no single workspace pool on node satisfies reservation")
  avail=workspaceManager~availableForPool(pool~poolId)
  /* A non-durable/disposable workspace must export required output before the
   * output can count as durable completion.  Count that byte movement here. */
  outputCommit=0
  if outputBytes>0 & \pool~countsAsDurable then outputCommit=outputBytes
  if materialize=0 then action=.StoragePlacementAction~JOB_TO_DATA
  else if localBytes=0 then action=.StoragePlacementAction~DATA_TO_JOB
  else action=.StoragePlacementAction~MIXED
  msg="storage feasibility only; hard node eligibility remains Job-to-Node authority"
  if pool~disposable then msg=msg||"; workspace is disposable and output commit is mandatory"
  return .StoragePlacementEvidence~new(node,.true,pool,workspaceBytes,avail,inputBytes,localBytes,materialize,jobBytes,outputBytes,outputCommit,action,msg)

::class StorageDurableCompletionPolicy public
::method outputSatisfied
  use arg object, requiredReplicasArg=1
  return .StorageReplicaPolicy~new~requiredDurabilitySatisfied(object,requiredReplicasArg)

/* -------------------------------------------------------------------------
 * v0.1-dev7 node/storage topology inventory.
 *
 * Node identity, provider identity, network endpoint and block-device
 * observations are separate facts.  A visible block device is not workspace
 * until explicitly admitted.  Likewise, a node endpoint is routing evidence,
 * not hard liveness/eligibility authority; Job-to-Node retains that authority.
 * ---------------------------------------------------------------------- */

::class StorageDeviceAdmission public
::constant UNQUALIFIED "UNQUALIFIED"
::constant WORKSPACE "WORKSPACE"
::constant DURABLE "DURABLE"
::constant BOTH "BOTH"
::constant REJECTED "REJECTED"

::class StorageNodeDescriptor public
::attribute nodeId get
::attribute providerId get
::attribute endpoint get
::attribute region get
::attribute lifecycle get
::attribute observedAt get
::attribute evidenceRef get
::method init
  expose nodeId providerId endpoint region lifecycle observedAt evidenceRef
  use arg nodeArg, providerArg, endpointArg="", regionArg="", lifecycleArg=.nil, observedArg="", evidenceArg=""
  nodeId=nodeArg~string~strip
  providerId=providerArg~string~strip~lower
  endpoint=endpointArg~string~strip
  region=regionArg~string~strip~upper
  if lifecycleArg==.nil then lifecycle=.StorageServiceLifecycle~new(.StorageSafetyClass~UNKNOWN,.StorageLifecycleState~STABLE)
  else lifecycle=lifecycleArg
  observedAt=observedArg~string~strip
  evidenceRef=evidenceArg~string
  if nodeId="" | providerId="" then raise syntax 88.900 array("nodeId and providerId are mandatory")
::method canonical
  expose nodeId providerId endpoint region lifecycle observedAt evidenceRef
  return "node="||nodeId||";provider="||providerId||";endpoint="||endpoint||";region="||region||";safety="||lifecycle~safetyClass||";lifecycle="||lifecycle~state||";expectedEnd="||lifecycle~expectedEnd||";observed="||observedAt||";evidence="||evidenceRef

::class StorageDeviceObservation public
::attribute nodeId get
::attribute deviceId get
::attribute sizeBytes get
::attribute admission get
::attribute model get
::attribute observedAt get
::attribute evidenceRef get
::method init
  expose nodeId deviceId sizeBytes admission model observedAt evidenceRef
  use arg nodeArg, deviceArg, sizeArg, admissionArg="UNQUALIFIED", modelArg="", observedArg="", evidenceArg=""
  nodeId=nodeArg~string~strip
  deviceId=deviceArg~string~strip
  sizeBytes=sizeArg+0
  admission=admissionArg~string~strip~upper
  model=modelArg~string
  observedAt=observedArg~string~strip
  evidenceRef=evidenceArg~string
  if nodeId="" | deviceId="" then raise syntax 88.900 array("device nodeId and deviceId are mandatory")
  if sizeBytes<0 then raise syntax 88.900 array("device size must not be negative")
  if admission<>.StorageDeviceAdmission~UNQUALIFIED & admission<>.StorageDeviceAdmission~WORKSPACE & admission<>.StorageDeviceAdmission~DURABLE & admission<>.StorageDeviceAdmission~BOTH & admission<>.StorageDeviceAdmission~REJECTED then raise syntax 88.900 array("invalid storage device admission")
::method workspaceAdmitted
  expose admission
  return admission=.StorageDeviceAdmission~WORKSPACE | admission=.StorageDeviceAdmission~BOTH
::method durableAdmitted
  expose admission
  return admission=.StorageDeviceAdmission~DURABLE | admission=.StorageDeviceAdmission~BOTH

::class StorageNodeInventory public
::method init
  expose nodes devices
  nodes=.directory~new
  devices=.directory~new
::method putNode
  expose nodes
  use arg node
  if node==.nil then raise syntax 88.900 array("node descriptor is mandatory")
  nodes[node~nodeId]=node
  return node
::method node
  expose nodes
  use arg nodeArg
  return nodes[nodeArg~string~strip]
::method allNodes
  expose nodes
  a=.array~new
  do key over nodes
    a~append(nodes[key])
  end
  return a
::method byProvider
  expose nodes
  use arg providerArg
  p=providerArg~string~strip~lower
  a=.array~new
  do key over nodes
    n=nodes[key]
    if n~providerId=p then a~append(n)
  end
  return a
::method observeDevice
  expose devices
  use arg observation
  if observation==.nil then raise syntax 88.900 array("device observation is mandatory")
  devices[observation~nodeId||"1F"x||observation~deviceId]=observation
  return observation
::method devicesForNode
  expose devices
  use arg nodeArg
  n=nodeArg~string~strip
  a=.array~new
  do key over devices
    d=devices[key]
    if d~nodeId=n then a~append(d)
  end
  return a
::method admittedWorkspaceDevicesForNode
  use arg nodeArg
  a=.array~new
  do d over self~devicesForNode(nodeArg)
    if d~workspaceAdmitted then a~append(d)
  end
  return a
::method save
  expose nodes devices
  use arg pathArg
  path=pathArg~string
  call SysFileDelete path
  do key over nodes
    n=nodes[key]; l=n~lifecycle
    line="NODE"||"09"x||.StorageCodec~enc(n~nodeId)||"09"x||.StorageCodec~enc(n~providerId)||"09"x||.StorageCodec~enc(n~endpoint)||"09"x||.StorageCodec~enc(n~region)||"09"x||l~safetyClass||"09"x||l~state||"09"x||.StorageCodec~enc(l~expectedEnd)||"09"x||.StorageCodec~enc(l~reason)||"09"x||.StorageCodec~enc(n~observedAt)||"09"x||.StorageCodec~enc(n~evidenceRef)
    call lineout path,line
  end
  do key over devices
    d=devices[key]
    line="DEVICE"||"09"x||.StorageCodec~enc(d~nodeId)||"09"x||.StorageCodec~enc(d~deviceId)||"09"x||d~sizeBytes||"09"x||d~admission||"09"x||.StorageCodec~enc(d~model)||"09"x||.StorageCodec~enc(d~observedAt)||"09"x||.StorageCodec~enc(d~evidenceRef)
    call lineout path,line
  end
  call lineout path
  return self
::method load
  expose nodes devices
  use arg pathArg
  path=pathArg~string
  nodes=.directory~new; devices=.directory~new
  if stream(path,"c","query exists")="" then return self
  do while lines(path)>0
    line=linein(path)
    if line="" then iterate
    f=.StorageCodec~splitTabs(line)
    kind=f[1]
    if kind="NODE" & f~items>=11 then do
      life=.StorageServiceLifecycle~new(f[6],f[7],.StorageCodec~dec(f[8]),.StorageCodec~dec(f[9]))
      n=.StorageNodeDescriptor~new(.StorageCodec~dec(f[2]),.StorageCodec~dec(f[3]),.StorageCodec~dec(f[4]),.StorageCodec~dec(f[5]),life,.StorageCodec~dec(f[10]),.StorageCodec~dec(f[11]))
      self~putNode(n)
    end
    else if kind="DEVICE" & f~items>=8 then do
      d=.StorageDeviceObservation~new(.StorageCodec~dec(f[2]),.StorageCodec~dec(f[3]),f[4]+0,f[5],.StorageCodec~dec(f[6]),.StorageCodec~dec(f[7]),.StorageCodec~dec(f[8]))
      self~observeDevice(d)
    end
  end
  call stream path,"c","close"
  return self

::class StoragePlacementMatrix public
::method init
  expose evidence
  evidence=.directory~new
::method put
  expose evidence
  use arg e
  if e==.nil then raise syntax 88.900 array("placement evidence is mandatory")
  evidence[e~nodeId]=e
  return e
::method forNode
  expose evidence
  use arg nodeArg
  return evidence[nodeArg~string~strip]
::method all
  expose evidence
  a=.array~new
  do key over evidence
    a~append(evidence[key])
  end
  return a

::class StorageFleetPlacementAdvisor public
::method assessInventory
  use arg inventory, inputObjects, workspaceBytesArg, jobPackageBytesArg=0, expectedOutputBytesArg=0, workspaceManager
  if inventory==.nil | workspaceManager==.nil then raise syntax 88.900 array("inventory and workspace manager are mandatory")
  matrix=.StoragePlacementMatrix~new
  advisor=.StoragePlacementAdvisor~new
  do n over inventory~allNodes
    matrix~put(advisor~assessCandidate(n~nodeId,inputObjects,workspaceBytesArg,jobPackageBytesArg,expectedOutputBytesArg,workspaceManager))
  end
  return matrix

/* -------------------------------------------------------------------------
 * v0.1-dev3 TVFS-inspired ordered search-path / union projection.
 *
 * A layer maps a virtual root onto an existing StorageNamespace root.
 * Resolution searches layers in priority order; listing unions children and
 * first-layer names shadow lower layers.  No physical copies are implied.
 * ---------------------------------------------------------------------- */

::class StorageUnionLayer public
::attribute namespace get
::attribute rootPath get
::attribute label get
::method init
  expose namespace rootPath label
  use arg namespaceArg, rootArg="/", labelArg=""
  namespace=namespaceArg
  rootPath=.StoragePath~normalize(rootArg)
  label=labelArg~string
  if namespace==.nil then raise syntax 88.900 array("union layer namespace is mandatory")
  if label="" then label=namespace~namespaceId
::method mapPath
  expose rootPath
  use arg virtualArg
  v=.StoragePath~normalize(virtualArg)
  if v="/" then return rootPath
  if rootPath="/" then return v
  return .StoragePath~normalize(rootPath||v)
::method virtualPath
  use arg sourceArg, virtualParentArg="/"
  return .StoragePath~join(virtualParentArg,.StoragePath~name(sourceArg))

::class StorageUnionResolution public
::attribute status get
::attribute entry get
::attribute layerIndex get
::attribute sourcePath get
::attribute message get
::method init
  expose status entry layerIndex sourcePath message
  use arg statusArg, entryArg=.nil, layerIndexArg=0, sourcePathArg="", messageArg=""
  status=statusArg~string~strip~upper
  entry=entryArg
  layerIndex=layerIndexArg+0
  sourcePath=sourcePathArg~string
  message=messageArg~string
::method found
  expose status
  return status=.StorageResolutionStatus~FOUND

::class StorageUnionView public
::attribute viewId get
::attribute writeLayerIndex get
::method init
  expose viewId layers writeLayerIndex
  use arg idArg
  viewId=idArg~string~strip
  layers=.array~new
  writeLayerIndex=0
  if viewId="" then raise syntax 88.900 array("union view id is mandatory")
::method addLayer
  expose layers writeLayerIndex
  use arg namespaceArg, rootArg="/", labelArg=""
  layers~append(.StorageUnionLayer~new(namespaceArg,rootArg,labelArg))
  if writeLayerIndex=0 then writeLayerIndex=1
  return layers~items
::method setWriteLayer
  expose layers writeLayerIndex
  use arg indexArg
  i=indexArg+0
  if i<1 | i>layers~items then raise syntax 88.900 array("union write layer index out of range")
  writeLayerIndex=i
  return self
::method layerCount
  expose layers
  return layers~items
::method layer
  expose layers
  use arg indexArg
  i=indexArg+0
  if i<1 | i>layers~items then return .nil
  return layers[i]
::method resolve
  expose layers
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  do i=1 to layers~items
    l=layers[i]
    source=l~mapPath(p)
    r=l~namespace~resolve(source)
    if r~status=.StorageResolutionStatus~AMBIGUOUS | r~status=.StorageResolutionStatus~LINK_LOOP then return .StorageUnionResolution~new(r~status,.nil,i,source,r~message)
    if r~found then do
      e=r~entry
      ue=.StorageNamespaceEntry~new(p,e~ref,e~writePolicy,.StorageNamespaceEntryKind~UNION,l~label||":"||source)
      return .StorageUnionResolution~new(.StorageResolutionStatus~FOUND,ue,i,source,"resolved from layer "||i||" "||l~label)
    end
  end
  return .StorageUnionResolution~new(.StorageResolutionStatus~NOT_FOUND,.nil,0,"","not present in any union layer")
::method list
  expose layers
  use arg folderArg
  folder=.StoragePath~normalize(folderArg)
  answer=.array~new
  seen=.directory~new
  do i=1 to layers~items
    l=layers[i]
    sourceFolder=l~mapPath(folder)
    entries=l~namespace~list(sourceFolder)
    do e over entries
      name=.StoragePath~name(e~path)
      key=name~lower
      if seen[key]==.nil then do
        virtualPath=.StoragePath~join(folder,name)
        answer~append(.StorageNamespaceEntry~new(virtualPath,e~ref,e~writePolicy,.StorageNamespaceEntryKind~UNION,l~label||":"||e~path))
        seen[key]=i
      end
    end
  end
  return answer
::method applyWrite
  expose layers writeLayerIndex
  use arg pathArg, newRef, changeSet=.nil
  if writeLayerIndex<1 | writeLayerIndex>layers~items then return .StorageMutationDecision~new(.false,"DENY",pathArg,"union has no write layer")
  l=layers[writeLayerIndex]
  source=l~mapPath(pathArg)
  return l~namespace~applyWrite(source,newRef,changeSet)
::method applyUnlink
  expose layers writeLayerIndex
  use arg pathArg, changeSet=.nil
  if writeLayerIndex<1 | writeLayerIndex>layers~items then return .StorageMutationDecision~new(.false,"DENY",pathArg,"union has no write layer")
  l=layers[writeLayerIndex]
  source=l~mapPath(pathArg)
  return l~namespace~applyUnlink(source,changeSet)

/* Small persistent journal facade.  Environment generations and sealed or
 * in-progress change sets are restartable evidence rather than process-local
 * state.  Namespace snapshot persistence is deliberately a later seam. */
::class StorageEnvironmentJournal public
::attribute root get
::method init
  expose root
  use arg rootArg
  root=rootArg~string~strip
  if root="" then raise syntax 88.900 array("environment journal root is mandatory")
  call SysMkDir root
::method environmentPath private
  expose root
  use arg idArg
  return root||"/environment-"||idArg~string||".state"
::method changeSetPath private
  expose root
  use arg idArg
  return root||"/changeset-"||idArg~string||".state"
::method saveEnvironment
  use arg environment
  if environment==.nil then raise syntax 88.900 array("environment is mandatory")
  environment~save(self~environmentPath(environment~environmentId))
  return self
::method loadEnvironment
  use arg idArg
  return .StorageEnvironment~load(self~environmentPath(idArg))
::method saveChangeSet
  use arg changeSet
  if changeSet==.nil then raise syntax 88.900 array("change set is mandatory")
  changeSet~save(self~changeSetPath(changeSet~changeSetId))
  return self
::method loadChangeSet
  use arg idArg
  return .StorageChangeSet~load(self~changeSetPath(idArg))
