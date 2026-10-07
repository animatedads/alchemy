/* ooRexx Storage Fabric v0.1-dev21
 * Surface-neutral authority persistence.
 *
 * FUSE, relation/query, intentions, object callers and peer services are all
 * projections/clients of this state.  None of those surfaces owns restart
 * persistence.  Provider credentials and transient surface handles are
 * deliberately excluded.
 */

::class StorageAuthorityBuild public
::constant VERSION "0.1-dev21"
::constant API "storage.fabric.authority/0.1"

::class StorageCapacityModel public
::constant FINITE "FINITE"
::constant ELASTIC "ELASTIC"
::constant UNKNOWN "UNKNOWN"

::class StorageAuthorityProviderRecord public
::attribute providerId get
::attribute providerType get
::attribute capacityModel get
::attribute vendorId get
::attribute siteId get
::attribute failureDomainId get
::attribute safetyClass get
::attribute lifecycleState get
::method init
  expose providerId providerType capacityModel vendorId siteId failureDomainId safetyClass lifecycleState
  use arg idArg,typeArg="",capacityArg="UNKNOWN",vendorArg="",siteArg="",domainArg="",safetyArg="SAFE",lifecycleArg="STABLE"
  providerId=idArg~string~strip
  providerType=typeArg~string~strip
  capacityModel=capacityArg~string~strip~upper
  vendorId=vendorArg~string~strip
  siteId=siteArg~string~strip
  failureDomainId=domainArg~string~strip
  safetyClass=safetyArg~string~strip~upper
  lifecycleState=lifecycleArg~string~strip~upper
  if providerId="" then raise syntax 88.900 array("provider id is mandatory")

::class StorageReplicaPolicyBook public
::method init
  expose requirements
  requirements=.directory~new
::method put
  expose requirements
  use arg objectIdArg,requirement
  id=objectIdArg~string
  if id="" | requirement==.nil then raise syntax 88.900 array("object id and replica requirement are mandatory")
  requirements[id]=requirement
  return requirement
::method get
  expose requirements
  use arg objectIdArg
  return requirements[objectIdArg~string]
::method allObjectIds
  expose requirements
  a=.array~new
  do id over requirements; a~append(id); end
  return a

::class StorageAuthoritySnapshot public
::attribute revision get
::attribute catalogue get
::attribute replicaPolicies get
::method init
  expose revision catalogue replicaPolicies environments namespaces providers
  use arg revisionArg=0,catalogueArg=.nil
  revision=revisionArg+0
  if catalogueArg==.nil then catalogue=.StorageCatalogue~new; else catalogue=catalogueArg
  replicaPolicies=.StorageReplicaPolicyBook~new
  environments=.directory~new
  namespaces=.directory~new
  providers=.directory~new
::method setRevision
  expose revision
  use arg revisionArg
  revision=revisionArg+0
  return self
::method addEnvironment
  expose environments
  use arg environment
  if environment==.nil then raise syntax 88.900 array("environment is mandatory")
  environments[environment~environmentId]=environment
  return environment
::method environment
  expose environments
  use arg idArg
  return environments[idArg~string]
::method allEnvironments
  expose environments
  a=.array~new
  do id over environments; a~append(environments[id]); end
  return a
::method addNamespace
  expose namespaces
  use arg namespace
  if namespace==.nil then raise syntax 88.900 array("namespace is mandatory")
  namespaces[namespace~namespaceId]=namespace
  return namespace
::method namespace
  expose namespaces
  use arg idArg
  return namespaces[idArg~string]
::method allNamespaces
  expose namespaces
  a=.array~new
  do id over namespaces; a~append(namespaces[id]); end
  return a
::method addProvider
  expose providers
  use arg provider
  if provider==.nil then raise syntax 88.900 array("provider record is mandatory")
  providers[provider~providerId]=provider
  return provider
::method provider
  expose providers
  use arg idArg
  return providers[idArg~string]
::method allProviders
  expose providers
  a=.array~new
  do id over providers; a~append(providers[id]); end
  return a

::class StorageAuthorityStore public
::attribute root get
::method init
  expose root
  use arg rootArg
  root=rootArg~string~strip
  if root="" then raise syntax 88.900 array("authority store root is mandatory")
  call SysMkDir root
::method currentPath private
  expose root
  return root||"/CURRENT"
::method authorityPath private
  expose root
  use arg slotArg
  return root||"/authority."||slotArg~string~lower
::method cataloguePath private
  expose root
  use arg slotArg
  return root||"/catalogue."||slotArg~string~lower
::method chooseSlot private
  use arg revisionArg
  if (revisionArg+0)//2=0 then return "a"
  return "b"
::method save
  expose root
  use arg snapshot
  if snapshot==.nil then raise syntax 88.900 array("authority snapshot is mandatory")
  revision=snapshot~revision+1
  slot=self~chooseSlot(revision)
  ap=self~authorityPath(slot); cp=self~cataloguePath(slot)
  at=ap||".tmp"; ct=cp||".tmp"
  call SysFileDelete at; call SysFileDelete ct
  snapshot~catalogue~save(ct)
  call lineout at,"AUTHORITY"||"09"x||"1"||"09"x||revision
  do p over snapshot~allProviders
    line="PROVIDER"||"09"x||.StorageCodec~enc(p~providerId)||"09"x||.StorageCodec~enc(p~providerType)||"09"x||p~capacityModel||"09"x||.StorageCodec~enc(p~vendorId)||"09"x||.StorageCodec~enc(p~siteId)||"09"x||.StorageCodec~enc(p~failureDomainId)||"09"x||p~safetyClass||"09"x||p~lifecycleState
    call lineout at,line
  end
  do e over snapshot~allEnvironments
    line="ENV"||"09"x||.StorageCodec~enc(e~environmentId)||"09"x||e~kind||"09"x||.StorageCodec~enc(e~parentId)||"09"x||e~baseGeneration||"09"x||e~generation||"09"x||e~defaultWritePolicy
    call lineout at,line
  end
  do n over snapshot~allNamespaces
    parentId=""
    if n~parent<>.nil then parentId=n~parent~namespaceId
    line="NS"||"09"x||.StorageCodec~enc(n~namespaceId)||"09"x||.StorageCodec~enc(n~environment~environmentId)||"09"x||.StorageCodec~enc(parentId)
    call lineout at,line
    do b over n~localBindings
      line="BIND"||"09"x||.StorageCodec~enc(n~namespaceId)||"09"x||.StorageCodec~enc(b~path)||"09"x||.StorageCodec~enc(b~ref~objectId)||"09"x||.StorageCodec~enc(b~ref~digest)||"09"x||b~writePolicy
      call lineout at,line
    end
    do a over n~allAliases
      line="ALIAS"||"09"x||.StorageCodec~enc(n~namespaceId)||"09"x||.StorageCodec~enc(a~path)||"09"x||.StorageCodec~enc(a~targetPath)||"09"x||a~writePolicy
      call lineout at,line
    end
    do q over n~allQueryFolders
      line="QF"||"09"x||.StorageCodec~enc(n~namespaceId)||"09"x||.StorageCodec~enc(q~path)||"09"x||q~writePolicy
      call lineout at,line
      do c over q~filter~all
        line="QC"||"09"x||.StorageCodec~enc(n~namespaceId)||"09"x||.StorageCodec~enc(q~path)||"09"x||.StorageCodec~enc(c~field)||"09"x||c~operator||"09"x||.StorageCodec~enc(c~expected)
        call lineout at,line
      end
    end
    do k over n~exclusionKeys
      call lineout at,"EXCL"||"09"x||.StorageCodec~enc(n~namespaceId)||"09"x||.StorageCodec~enc(k)
    end
  end
  do objectId over snapshot~replicaPolicies~allObjectIds
    r=snapshot~replicaPolicies~get(objectId)
    call lineout at,"POLICY"||"09"x||.StorageCodec~enc(objectId)||"09"x||r~requiredReplicas||"09"x||r~distinctVendors||"09"x||r~distinctSites||"09"x||r~distinctFailureDomains
  end
  call lineout at,"END"||"09"x||revision
  call stream at,"c","close"
  call stream ct,"c","close"
  /* Publish data files before the tiny CURRENT pointer.  The previous slot is
   * retained so a torn/newest checkpoint never destroys the last complete one. */
  call SysFileDelete cp; call SysFileMove ct,cp
  call SysFileDelete ap; call SysFileMove at,ap
  curTmp=self~currentPath||".tmp"
  call SysFileDelete curTmp
  call lineout curTmp,slot||"09"x||revision
  call stream curTmp,"c","close"
  call SysFileDelete self~currentPath
  call SysFileMove curTmp,self~currentPath
  snapshot~setRevision(revision)
  return revision
::method load
  cur=self~currentPath
  preferred=""; other=""
  if stream(cur,"c","query exists")<>"" then do
    line=linein(cur); call stream cur,"c","close"
    f=.StorageCodec~splitTabs(line)
    if f~items>=1 then preferred=f[1]
  end
  if preferred="a" then other="b"
  else if preferred="b" then other="a"
  else do; preferred="a"; other="b"; end
  s=self~loadSlot(preferred)
  if s<>.nil then return s
  return self~loadSlot(other)
::method loadSlot private
  use arg slotArg
  ap=self~authorityPath(slotArg); cp=self~cataloguePath(slotArg)
  if stream(ap,"c","query exists")="" | stream(cp,"c","query exists")="" then return .nil
  first=linein(ap)
  hf=.StorageCodec~splitTabs(first)
  if hf~items<3 | hf[1]<>"AUTHORITY" then do; call stream ap,"c","close"; return .nil; end
  revision=hf[3]+0
  records=.array~new; valid=.false
  do while lines(ap)>0
    line=linein(ap)
    if line="" then iterate
    f=.StorageCodec~splitTabs(line)
    if f~items>=2 & f[1]="END" then do
      if f[2]+0=revision then valid=.true
      leave
    end
    records~append(line)
  end
  call stream ap,"c","close"
  if \valid then return .nil
  cat=.StorageCatalogue~new; cat~load(cp)
  snap=.StorageAuthoritySnapshot~new(revision,cat)
  /* Pass 1: provider/environment/namespace shells. */
  parentIds=.directory~new
  do line over records
    f=.StorageCodec~splitTabs(line); kind=f[1]
    select
      when kind="PROVIDER" & f~items>=9 then snap~addProvider(.StorageAuthorityProviderRecord~new(.StorageCodec~dec(f[2]),.StorageCodec~dec(f[3]),f[4],.StorageCodec~dec(f[5]),.StorageCodec~dec(f[6]),.StorageCodec~dec(f[7]),f[8],f[9]))
      when kind="ENV" & f~items>=7 then snap~addEnvironment(.StorageEnvironment~new(.StorageCodec~dec(f[2]),f[3],.StorageCodec~dec(f[4]),f[5]+0,f[6]+0,f[7]))
      when kind="NS" & f~items>=4 then do
        id=.StorageCodec~dec(f[2]); env=snap~environment(.StorageCodec~dec(f[3]))
        if env<>.nil then do
          ns=.StorageNamespace~new(id,cat,env)
          snap~addNamespace(ns); parentIds[id]=.StorageCodec~dec(f[4])
        end
      end
      otherwise nop
    end
  end
  do id over parentIds
    pid=parentIds[id]
    if pid<>"" then do
      n=snap~namespace(id); p=snap~namespace(pid)
      if n<>.nil & p<>.nil then n~restoreParent(p)
    end
  end
  /* Pass 2: namespace contents and replica policy. */
  do line over records
    f=.StorageCodec~splitTabs(line); kind=f[1]
    select
      when kind="BIND" & f~items>=6 then do
        n=snap~namespace(.StorageCodec~dec(f[2]))
        if n<>.nil then n~bind(.StorageCodec~dec(f[3]),.StorageRef~new(.StorageCodec~dec(f[4]),.StorageCodec~dec(f[5])),f[6])
      end
      when kind="ALIAS" & f~items>=5 then do
        n=snap~namespace(.StorageCodec~dec(f[2]))
        if n<>.nil then n~addAlias(.StorageCodec~dec(f[3]),.StorageCodec~dec(f[4]),f[5])
      end
      when kind="QF" & f~items>=4 then do
        n=snap~namespace(.StorageCodec~dec(f[2]))
        if n<>.nil then n~addQueryFolder(.StorageQueryFolder~new(.StorageCodec~dec(f[3]),.StorageFilter~new,f[4]))
      end
      when kind="QC" & f~items>=6 then do
        n=snap~namespace(.StorageCodec~dec(f[2]))
        if n<>.nil then do
          q=n~queryFolder(.StorageCodec~dec(f[3]))
          if q<>.nil then q~filter~add(.StorageFilterClause~new(.StorageCodec~dec(f[4]),.StorageCodec~dec(f[6]),f[5]))
        end
      end
      when kind="EXCL" & f~items>=3 then do
        n=snap~namespace(.StorageCodec~dec(f[2])); if n<>.nil then n~restoreExclusion(.StorageCodec~dec(f[3]))
      end
      when kind="POLICY" & f~items>=6 then snap~replicaPolicies~put(.StorageCodec~dec(f[2]),.StorageReplicaRequirement~new(f[3]+0,f[4]+0,f[5]+0,f[6]+0))
      otherwise nop
    end
  end
  return snap

::requires "StorageFabric.cls"
