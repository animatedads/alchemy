/* ooRexx WebDAV Gateway v0.1-dev3 -- protocol/storage core. */

::class WebDavBuild public
::constant VERSION "0.1-dev4"
::constant API "webdav.gateway/0.1"

::class WebDavStatus public
::constant OK 200
::constant PARTIAL_CONTENT 206
::constant CREATED 201
::constant NO_CONTENT 204
::constant MULTI_STATUS 207
::constant BAD_REQUEST 400
::constant FORBIDDEN 403
::constant NOT_FOUND 404
::constant METHOD_NOT_ALLOWED 405
::constant NOT_ACCEPTABLE 406
::constant CONFLICT 409
::constant PRECONDITION_FAILED 412
::constant UNSUPPORTED_MEDIA_TYPE 415
::constant RANGE_NOT_SATISFIABLE 416
::constant LOCKED 423
::constant FAILED_DEPENDENCY 424
::constant INTERNAL_ERROR 500
::constant INSUFFICIENT_STORAGE 507

::class WebDavUtil public
::method xmlEscape class
  use arg value
  s=value~string
  s=changestr('&',s,'&amp;')
  s=changestr('<',s,'&lt;')
  s=changestr('>',s,'&gt;')
  s=changestr('"',s,'&quot;')
  return s
::method xmlUnescape class
  use arg value
  s=value~string
  s=changestr('&lt;',s,'<')
  s=changestr('&gt;',s,'>')
  s=changestr('&quot;',s,'"')
  s=changestr('&amp;',s,'&')
  return s
::method href class
  use arg mountPath, storagePath
  m=mountPath~string
  if m='' then m='/dav'
  if right(m,1)='/' then m=left(m,length(m)-1)
  p=.StoragePath~normalize(storagePath)
  if p='/' then return m'/'
  return m||p
::method quoteEtag class
  use arg ref
  if ref==.nil then return '"missing"'
  token=ref~digest
  if token='' then token=ref~objectId
  token=changestr('"',token,'')
  return '"'||token||'"'
::method trimQuotes class
  use arg value
  s=value~string~strip
  if length(s)>=2 & left(s,1)='"' & right(s,1)='"' then return substr(s,2,length(s)-2)
  return s
::method startsWithPath class
  use arg candidateArg, ancestorArg
  c=.StoragePath~normalize(candidateArg); a=.StoragePath~normalize(ancestorArg)
  if c=a then return .true
  if a='/' then return .true
  return left(c,length(a)+1)=a||'/'
::method destinationPath class
  use arg destinationArg, mountArg
  d=destinationArg~string~strip
  if d='' then return ''
  /* accept absolute URI or path; WebDAV authority/host is transport evidence,
   * never Storage identity. */
  p=d~pos('://')
  if p>0 then do
    tail=d~substr(p+3)
    slash=tail~pos('/')
    if slash=0 then d='/'
    else d=tail~substr(slash)
  end
  m=mountArg~string
  if m<>'' & left(d,length(m))=m then d=d~substr(length(m)+1)
  if d='' then d='/'
  return .StoragePath~normalize(d)
::method secondsNow class
  /* Good enough for bounded lease expiry; persisted created-at/timeout remain
   * authoritative evidence across restarts. */
  return time('S')+0

::class WebDavUnavailableContentStore public
::method nextId
  raise syntax 88.900 array('WebDAV byte content store is not configured')
::method put
  raise syntax 88.900 array('WebDAV byte content store is not configured')
::method get
  return .nil
::method remove
  return self
::method digest
  raise syntax 88.900 array('WebDAV byte content store is not configured')

/* Protocol-test harness only. Production mounts must inject a durable
 * Storage-backed content/materialisation provider. */
::class WebDavMemoryContentStore public
::method init
  expose bodies sequence
  bodies=.directory~new; sequence=0
::method nextId
  expose sequence
  sequence+=1; return 'webdav-'||sequence
::method put
  expose bodies
  use arg objectId, bytes
  bodies[objectId~string]=bytes~string; return self
::method get
  expose bodies
  use arg objectId
  if bodies~hasIndex(objectId~string) then return bodies[objectId~string]
  return .nil
::method remove
  expose bodies
  use arg objectId
  if bodies~hasIndex(objectId~string) then bodies~remove(objectId~string)
  return self
::method digest
  use arg bytes
  s=bytes~string; a=1; b=0
  do i=1 to length(s)
    a=(a+c2d(c2x(substr(s,i,1))))//65521; b=(b+a)//65521
  end
  return 'adler32-'||b||'-'||a||'-'||length(s)

::class WebDavCollectionSet public
::method init
  expose rows
  rows=.directory~new; rows['/']=.true
::method add
  expose rows
  use arg pathArg
  p=.StoragePath~normalize(pathArg); rows[p]=.true; return p
::method has
  expose rows
  use arg pathArg
  return rows~hasIndex(.StoragePath~normalize(pathArg))
::method remove
  expose rows
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  if p='/' then return .false
  if rows~hasIndex(p) then do; rows~remove(p); return .true; end
  return .false
::method children
  expose rows
  use arg parentArg
  a=.array~new; p=.StoragePath~normalize(parentArg)
  do child over rows
    if child<>'/' & .StoragePath~isDirectChild(child,p) then a~append(child)
  end
  return a
::method all
  expose rows
  a=.array~new
  do p over rows; a~append(p); end
  return a

/* DAV-only dead properties for collection resources. File/object dead
 * properties are StorageEA-backed. */
::class WebDavCollectionPropertyStore public
::method init
  expose byPath
  byPath=.directory~new
::method set
  expose byPath
  use arg pathArg, nsArg, nameArg, valueArg
  p=.StoragePath~normalize(pathArg); key=nsArg~string~lower||'|'||nameArg~string~lower
  d=byPath[p]; if d==.nil then do; d=.directory~new; byPath[p]=d; end
  d[key]=.WebDavDeadProperty~new(nsArg,nameArg,valueArg); return .true
::method remove
  expose byPath
  use arg pathArg, nsArg, nameArg
  p=.StoragePath~normalize(pathArg); d=byPath[p]
  if d==.nil then return .false
  key=nsArg~string~lower||'|'||nameArg~string~lower
  if d[key]==.nil then return .false
  d~remove(key); return .true
::method all
  expose byPath
  use arg pathArg
  p=.StoragePath~normalize(pathArg); d=byPath[p]; a=.array~new
  if d==.nil then return a
  do k over d; a~append(d[k]); end
  return a
::method moveTree
  expose byPath
  use arg sourceArg, destinationArg, copyOnly=.false
  source=.StoragePath~normalize(sourceArg); destination=.StoragePath~normalize(destinationArg)
  moves=.array~new
  do p over byPath
    if .WebDavUtil~startsWithPath(p,source) then moves~append(p)
  end
  do p over moves
    suffix=p~substr(length(source)+1)
    np=.StoragePath~normalize(destination||suffix)
    byPath[np]=byPath[p]
    if \copyOnly then byPath~remove(p)
  end
  return self

::class WebDavDeadProperty public
::attribute namespace get
::attribute name get
::attribute value get
::method init
  expose namespace name value
  use arg namespaceArg, nameArg, valueArg=''
  namespace=namespaceArg~string; name=nameArg~string; value=valueArg~string

/* A persisted/recoverable DAV write-lock authority.  It owns lock semantics,
 * not Storage mutation semantics. */
::class WebDavLockRecord public
::attribute token get
::attribute path get
::attribute depth get
::attribute owner get
::attribute timeoutSeconds get
::attribute createdSeconds get
::attribute scope get
::method init
  expose token path depth owner timeoutSeconds createdSeconds scope
  use arg tokenArg,pathArg,depthArg='infinity',ownerArg='',timeoutArg=3600,createdArg=0,scopeArg='exclusive'
  token=tokenArg~string; path=.StoragePath~normalize(pathArg); depth=depthArg~string~lower
  owner=ownerArg~string; timeoutSeconds=timeoutArg+0
  scope=scopeArg~string~strip~lower
  if scope<>'exclusive' & scope<>'shared' then raise syntax 88.900 array('invalid DAV lock scope')
  if createdArg=0 then createdSeconds=.WebDavUtil~secondsNow; else createdSeconds=createdArg+0
::method covers
  expose depth path
  use arg candidateArg
  if depth='0' then return .StoragePath~normalize(candidateArg)=path
  return .WebDavUtil~startsWithPath(candidateArg,path)
::method conflictsWith
  expose scope
  use arg otherArg
  if otherArg==.nil then return .false
  if scope='shared' & otherArg~scope='shared' then return .false
  return .true
::method expired
  expose createdSeconds timeoutSeconds
  now=.WebDavUtil~secondsNow
  elapsed=now-createdSeconds
  if elapsed<0 then elapsed+=86400
  return elapsed>=timeoutSeconds

::class WebDavLockStore public
::method init
  expose locks sequence journalPath
  use arg journalArg=''
  locks=.directory~new; sequence=0; journalPath=journalArg~string
  if journalPath<>'' then self~load
::method lock
  expose locks sequence
  use arg pathArg, depthArg='infinity', ownerArg='', timeoutArg=3600, refreshToken='', scopeArg='exclusive'
  self~purgeExpired
  p=.StoragePath~normalize(pathArg); scope=scopeArg~string~lower
  if scope<>'exclusive' & scope<>'shared' then return .nil
  if refreshToken<>'' then do
    r=locks[refreshToken]
    if r==.nil | r~path<>p then return .nil
    locks[refreshToken]=.WebDavLockRecord~new(refreshToken,p,r~depth,r~owner,timeoutArg,0,r~scope)
    self~save; return locks[refreshToken]
  end
  candidate=.WebDavLockRecord~new('candidate',p,depthArg,ownerArg,timeoutArg,0,scope)
  do token over locks
    r=locks[token]
    overlaps=(r~covers(p) | (.WebDavUtil~startsWithPath(r~path,p) & depthArg~string~lower='infinity'))
    if overlaps & candidate~conflictsWith(r) then return .nil
  end
  sequence+=1
  token='opaquelocktoken:oorexx-webdav-'||sequence||'-'||.WebDavUtil~secondsNow
  locks[token]=.WebDavLockRecord~new(token,p,depthArg,ownerArg,timeoutArg,0,scope)
  self~save; return locks[token]
::method unlock
  expose locks
  use arg pathArg, tokenArg
  self~purgeExpired
  r=locks[tokenArg~string]
  if r==.nil | r~path<>.StoragePath~normalize(pathArg) then return .false
  locks~remove(tokenArg~string); self~save; return .true
::method applicable
  expose locks
  use arg pathArg
  self~purgeExpired; a=.array~new
  do token over locks
    r=locks[token]
    if r~covers(pathArg) then a~append(r)
  end
  return a
::method tokensFor
  use arg pathArg
  a=.array~new
  do r over self~applicable(pathArg); a~append(r~token); end
  return a
::method mutationAllowed
  use arg pathArg, ifHeaderArg='', lockTokenArg='', currentEtagArg=''
  a=self~applicable(pathArg)
  if a~items=0 then return .true
  supplied=ifHeaderArg~string
  if lockTokenArg~string<>'' then supplied=supplied||' (<'||lockTokenArg~string||'>)'
  return .WebDavIfEvaluator~evaluate(supplied,pathArg,currentEtagArg,self~tokensFor(pathArg))
::method purgeExpired
  expose locks
  gone=.array~new
  do token over locks
    if locks[token]~expired then gone~append(token)
  end
  do token over gone; locks~remove(token); end
  if gone~items>0 then self~save
  return gone~items
::method save
  expose locks journalPath
  if journalPath='' then return self
  ignore=stream(journalPath,'c','open write replace')
  call lineout journalPath,'WEBDAVLOCKS2'
  do token over locks
    r=locks[token]
    call lineout journalPath,r~token||'09'x||r~path||'09'x||r~depth||'09'x||r~timeoutSeconds||'09'x||r~createdSeconds||'09'x||r~scope||'09'x||r~owner
  end
  call lineout journalPath
  return self
::method load
  expose locks journalPath sequence
  if journalPath='' | stream(journalPath,'c','query exists')='' then return self
  header=linein(journalPath)
  if header<>'WEBDAVLOCKS2' & header<>'WEBDAVLOCKS1' then do; call stream journalPath,'c','close'; return self; end
  old=(header='WEBDAVLOCKS1')
  do while lines(journalPath)>0
    line=linein(journalPath); if line='' then iterate
    f=.WebDavText~split(line,'09'x)
    if old then do
      if f~items<6 then iterate
      scope='exclusive'; owner=f[6]
    end
    else do
      if f~items<7 then iterate
      scope=f[6]; owner=f[7]
    end
    locks[f[1]]=.WebDavLockRecord~new(f[1],f[2],f[3],owner,f[4]+0,f[5]+0,scope)
    sequence+=1
  end
  call stream journalPath,'c','close'; self~purgeExpired; return self

::class WebDavText public
::method split class
  use arg textArg, sepArg
  s=textArg~string; sep=sepArg~string; a=.array~new
  do forever
    p=s~pos(sep)
    if p=0 then do; a~append(s); leave; end
    a~append(s~substr(1,p-1)); s=s~substr(p+sep~length)
  end
  return a
::method between class
  use arg textArg, openArg, closeArg, startArg=1
  s=textArg~string; p=s~pos(openArg,startArg)
  if p=0 then return ''
  p+=openArg~length; q=s~pos(closeArg,p)
  if q=0 then return ''
  return s~substr(p,q-p)

::class WebDavStorageAdapter public
::attribute namespace get
::attribute catalogue get
::attribute collections get
::attribute representations get
::attribute locks get
::attribute collectionProperties get
::attribute syncJournal get
::attribute byteSources get
::method init
  expose namespace catalogue content collections mountPath representations locks collectionProperties syncJournal byteSources
  use arg namespaceArg, contentArg=.nil, collectionArg=.nil, mountArg='/dav', representationsArg=.nil, lockArg=.nil, collectionPropsArg=.nil, syncArg=.nil, byteSourcesArg=.nil
  if namespaceArg==.nil then raise syntax 88.900 array('WebDAV StorageNamespace is mandatory')
  namespace=namespaceArg; catalogue=namespace~catalogue
  if contentArg==.nil then content=.WebDavUnavailableContentStore~new; else content=contentArg
  if collectionArg==.nil then collections=.WebDavCollectionSet~new; else collections=collectionArg
  mountPath=mountArg~string
  if representationsArg==.nil then representations=.WebDavRepresentationRegistry~new; else representations=representationsArg
  if lockArg==.nil then locks=.WebDavLockStore~new; else locks=lockArg
  if collectionPropsArg==.nil then collectionProperties=.WebDavCollectionPropertyStore~new; else collectionProperties=collectionPropsArg
  if syncArg==.nil then syncJournal=.WebDavSyncJournal~new; else syncJournal=syncArg
  if byteSourcesArg==.nil then byteSources=.WebDavByteSourceRegistry~new; else byteSources=byteSourcesArg
::method mountPath
  expose mountPath
  return mountPath
::method exists
  expose namespace collections
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  if collections~has(p) then return .true
  return namespace~resolve(p)~found
::method isCollection
  expose collections namespace
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  if collections~has(p) then return .true
  return namespace~list(p)~items>0
::method objectAt
  expose namespace catalogue
  use arg pathArg
  r=namespace~resolve(pathArg)
  if \r~found then return .nil
  return catalogue~get(r~entry~ref~objectId)
::method etag
  expose namespace
  use arg pathArg
  r=namespace~resolve(pathArg)
  if \r~found then return ''
  return .WebDavUtil~quoteEtag(r~entry~ref)
::method registerByteSource
  expose byteSources
  use arg refArg,sourceArg
  byteSources~register(refArg,sourceArg); return self
::method readRange
  expose namespace byteSources content
  use arg pathArg,offsetArg,lengthArg,maximumArg=8388608
  r=namespace~resolve(pathArg)
  if \r~found then return .nil
  ref=r~entry~ref
  if byteSources~has(ref) then return byteSources~readAt(ref,offsetArg,lengthArg,maximumArg)
  bytes=content~get(ref~objectId)
  if bytes==.nil then return .nil
  offset=offsetArg+0; n=lengthArg+0
  if offset<0 | n<0 | offset+n>bytes~length then raise syntax 88.900 array('DAV range outside object')
  return bytes~substr(offset+1,n)
::method recordChange
  expose syncJournal namespace
  use arg pathArg,statusArg=200,operationArg='CHANGE'
  return syncJournal~record(pathArg,statusArg,operationArg,namespace~environment~generation)
::method syncToken
  expose syncJournal
  return syncJournal~currentToken
::method syncChanges
  expose syncJournal
  use arg tokenArg,rootArg='/',limitArg=4096
  return syncJournal~changesSince(tokenArg,rootArg,limitArg)

::method getRepresentation
  expose namespace content representations byteSources
  use arg pathArg, acceptArg=""
  r=namespace~resolve(pathArg)
  if \r~found then return .nil
  o=self~objectAt(pathArg)
  rr=representations~render(o,acceptArg)
  if rr<>.nil then return rr
  bytes=content~get(r~entry~ref~objectId)
  if bytes==.nil then do
    if byteSources~has(r~entry~ref) & o~sizeBytes<=8388608 then bytes=byteSources~readAt(r~entry~ref,0,o~sizeBytes,8388608)
    else return .nil
  end
  return .WebDavRepresentationResult~new(bytes,o~mediaType)
::method getBytes
  use arg pathArg
  rr=self~getRepresentation(pathArg,"")
  if rr==.nil then return .nil
  return rr~body
::method putSequentialMedia
  expose namespace catalogue representations locks
  use arg pathArg, imageArg, canonicalTypeArg="application/vnd.oorexx.storage.sequential-media", ifMatch="", ifNoneMatch="", ifHeader=''
  p=.StoragePath~normalize(pathArg)
  if \locks~mutationAllowed(p,ifHeader,'',self~etag(p)) then return .WebDavMutationResult~new(.false,423,'LOCKED','lock token required',.nil)
  if imageArg==.nil then return .WebDavMutationResult~new(.false,400,'BAD_MEDIA','canonical media image is mandatory',.nil)
  old=namespace~resolve(p); existed=old~found
  if ifNoneMatch='*' & existed then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','resource already exists',.nil)
  if ifMatch<>'' then do
    if \existed then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','If-Match target absent',.nil)
    if .WebDavUtil~trimQuotes(ifMatch)<>.WebDavUtil~trimQuotes(.WebDavUtil~quoteEtag(old~entry~ref)) then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','ETag mismatch',.nil)
  end
  if \existed & \self~isCollection(.StoragePath~parent(p)) then return .WebDavMutationResult~new(.false,409,'CONFLICT','parent collection does not exist',.nil)
  digest=representations~canonicalDigest(imageArg); id='dav-media-'||digest
  ref=.StorageRef~new(id,digest)
  obj=.StorageObject~new(ref,.StoragePath~name(p),representations~canonicalSize(imageArg),canonicalTypeArg)
  representations~decorateStorageObject(obj,imageArg); catalogue~put(obj); representations~register(ref,imageArg)
  outcome=self~bindWrite(p,ref,existed,old,'dav-media-'||digest)
  if \outcome~ok then return outcome
  namespace~environment~advanceGeneration
  if existed then status=204; else status=201
  self~recordChange(p,status,'PUT_MEDIA')
  return .WebDavMutationResult~new(.true,status,'PUT_MEDIA','',ref)
::method putFromSource
  expose namespace catalogue content byteSources locks
  use arg pathArg,sourceArg,sinkArg,mediaType='application/octet-stream',ifMatch='',ifNoneMatch='',ifHeader='',chunkArg=8388608
  p=.StoragePath~normalize(pathArg)
  if sourceArg==.nil | sinkArg==.nil then return .WebDavMutationResult~new(.false,400,'BAD_STREAM','source and sink are mandatory',.nil)
  total=sourceArg~sizeBytes
  old=namespace~resolve(p); existed=old~found
  if ifNoneMatch='*' & existed then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','resource already exists',.nil)
  if \self~isCollection(.StoragePath~parent(p)) & \existed then return .WebDavMutationResult~new(.false,409,'CONFLICT','parent collection absent',.nil)
  if \locks~mutationAllowed(p,ifHeader,'',self~etag(p)) then return .WebDavMutationResult~new(.false,423,'LOCKED','lock token required',.nil)
  moved=.WebDavBoundedTransfer~copy(sourceArg,sinkArg,total,chunkArg)
  if moved<>total then return .WebDavMutationResult~new(.false,500,'SHORT_TRANSFER','bounded transfer incomplete',.nil)
  id='dav-stream-'||content~nextId
  if \sinkArg~hasMethod('VERIFICATIONPATH') then return .WebDavMutationResult~new(.false,500,'UNVERIFIABLE_SINK','sink has no verification path',.nil)
  digestHex=.StoragePosixSha256Verifier~new~digestFile(sinkArg~verificationPath)
  if digestHex='' then return .WebDavMutationResult~new(.false,500,'VERIFY_FAILED','streamed object SHA-256 unavailable',.nil)
  digest='sha256:'||digestHex
  ref=.StorageRef~new(id,digest)
  obj=.StorageObject~new(ref,.StoragePath~name(p),total,mediaType)
  catalogue~put(obj)
  byteSources~register(ref,.StorageLocalFileByteSource~new(sinkArg~verificationPath))
  outcome=self~bindWrite(p,ref,existed,old,'dav-stream-'||id)
  if \outcome~ok then return outcome
  namespace~environment~advanceGeneration
  if existed then status=204; else status=201
  self~recordChange(p,status,'PUT_STREAM')
  return .WebDavMutationResult~new(.true,status,'PUT_STREAM','',ref)

::method bindWrite private
  expose namespace
  use arg p,ref,existed,old,changeId
  if existed then do
    e=old~entry; cs=.nil
    if e~writePolicy=.StorageWritePolicy~VERSIONED | e~writePolicy=.StorageWritePolicy~COPY_ON_WRITE | e~writePolicy=.StorageWritePolicy~TRACKED | e~writePolicy=.StorageWritePolicy~EPHEMERAL then cs=.StorageChangeSet~new(changeId,namespace~environment~environmentId,namespace~environment~generation)
    d=namespace~applyWrite(p,ref,cs)
    if \d~allowed then return .WebDavMutationResult~new(.false,403,'WRITE_DENIED',d~message,.nil)
  end
  else do
    policy=namespace~environment~defaultWritePolicy
    if policy=.StorageWritePolicy~READ_ONLY then return .WebDavMutationResult~new(.false,403,'WRITE_DENIED','namespace default is read-only',.nil)
    namespace~bind(p,ref,policy)
  end
  return .WebDavMutationResult~new(.true,200,'BOUND','',ref)
::method putBytes
  expose namespace catalogue content locks
  use arg pathArg, bytesArg, mediaType='application/octet-stream', ifMatch='', ifNoneMatch='', ifHeader=''
  p=.StoragePath~normalize(pathArg); bytes=bytesArg~string
  if \locks~mutationAllowed(p,ifHeader,'',self~etag(p)) then return .WebDavMutationResult~new(.false,423,'LOCKED','lock token required',.nil)
  old=namespace~resolve(p); existed=old~found
  if ifNoneMatch='*' & existed then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','resource already exists',.nil)
  if ifMatch<>'' then do
    if \existed then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','If-Match target absent',.nil)
    if .WebDavUtil~trimQuotes(ifMatch)<>.WebDavUtil~trimQuotes(.WebDavUtil~quoteEtag(old~entry~ref)) then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','ETag mismatch',.nil)
  end
  if \existed & \self~isCollection(.StoragePath~parent(p)) then return .WebDavMutationResult~new(.false,409,'CONFLICT','parent collection does not exist',.nil)
  id=content~nextId; digest=content~digest(bytes); ref=.StorageRef~new(id,digest)
  obj=.StorageObject~new(ref,.StoragePath~name(p),length(bytes),mediaType)
  catalogue~put(obj); content~put(id,bytes)
  outcome=self~bindWrite(p,ref,existed,old,'dav-'||id)
  if \outcome~ok then return outcome
  namespace~environment~advanceGeneration
  if existed then status=204; else status=201
  self~recordChange(p,status,'PUT')
  return .WebDavMutationResult~new(.true,status,'PUT','',ref)
::method deletePath
  expose namespace collections locks
  use arg pathArg, ifMatch='', ifHeader=''
  p=.StoragePath~normalize(pathArg)
  if \locks~mutationAllowed(p,ifHeader,'',self~etag(p)) then return .WebDavMutationResult~new(.false,423,'LOCKED','lock token required',.nil)
  if collections~has(p) then do
    if namespace~list(p)~items>0 | collections~children(p)~items>0 then return .WebDavMutationResult~new(.false,409,'COLLECTION_NOT_EMPTY','collection is not empty',.nil)
    if p='/' then return .WebDavMutationResult~new(.false,403,'ROOT_PROTECTED','root collection cannot be deleted',.nil)
    collections~remove(p); namespace~environment~advanceGeneration
    self~recordChange(p,404,'DELETE_COLLECTION')
    return .WebDavMutationResult~new(.true,204,'DELETE_COLLECTION','',.nil)
  end
  r=namespace~resolve(p)
  if \r~found then return .WebDavMutationResult~new(.false,404,'NOT_FOUND','resource absent',.nil)
  if ifMatch<>'' & .WebDavUtil~trimQuotes(ifMatch)<>.WebDavUtil~trimQuotes(.WebDavUtil~quoteEtag(r~entry~ref)) then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','ETag mismatch',.nil)
  cs=.nil; e=r~entry
  if e~writePolicy=.StorageWritePolicy~COPY_ON_WRITE | e~writePolicy=.StorageWritePolicy~TRACKED | e~writePolicy=.StorageWritePolicy~EPHEMERAL then cs=.StorageChangeSet~new('dav-del-'||e~ref~objectId,namespace~environment~environmentId,namespace~environment~generation)
  d=namespace~applyUnlink(p,cs)
  if \d~allowed then return .WebDavMutationResult~new(.false,403,'DELETE_DENIED',d~message,.nil)
  namespace~environment~advanceGeneration
  self~recordChange(p,404,'DELETE')
  return .WebDavMutationResult~new(.true,204,'DELETE','',.nil)
::method makeCollection
  expose namespace collections locks
  use arg pathArg, ifHeader=''
  p=.StoragePath~normalize(pathArg)
  if \locks~mutationAllowed(.StoragePath~parent(p),ifHeader,'',self~etag(.StoragePath~parent(p))) then return .WebDavMutationResult~new(.false,423,'LOCKED','parent lock token required',.nil)
  if self~exists(p) then return .WebDavMutationResult~new(.false,405,'ALREADY_EXISTS','resource already exists',.nil)
  parent=.StoragePath~parent(p)
  if \collections~has(parent) & parent<>'/' & namespace~list(parent)~items=0 then return .WebDavMutationResult~new(.false,409,'CONFLICT','parent collection absent',.nil)
  collections~add(p); namespace~environment~advanceGeneration
  self~recordChange(p,201,'MKCOL')
  return .WebDavMutationResult~new(.true,201,'MKCOL','',.nil)
::method listChildren
  expose namespace collections
  use arg pathArg
  p=.StoragePath~normalize(pathArg); a=.array~new; seen=.directory~new
  do e over namespace~list(p)
    if .StoragePath~isDirectChild(e~path,p) & \seen~hasIndex(e~path) then do; a~append(e~path); seen[e~path]=.true; end
  end
  do c over collections~children(p)
    if \seen~hasIndex(c) then do; a~append(c); seen[c]=.true; end
  end
  return a
::method walk
  use arg pathArg, maxItemsArg=4096
  root=.StoragePath~normalize(pathArg); out=.array~new; pending=.array~new; seen=.directory~new
  pending~append(root); head=1
  do while head<=pending~items
    p=.StoragePath~normalize(pending[head]); head+=1
    if seen~hasIndex(p) then iterate
    seen[p]=.true; out~append(p)
    if out~items>maxItemsArg then raise syntax 88.900 array('WebDAV traversal limit exceeded')
    if self~isCollection(p) then do c over self~listChildren(p)
      if \seen~hasIndex(.StoragePath~normalize(c)) then pending~append(c)
    end
  end
  return out
::method setDeadProperty
  expose collectionProperties
  use arg pathArg, namespaceArg, nameArg, valueArg, typeArg="STRING", authorityArg="webdav"
  p=.StoragePath~normalize(pathArg)
  if self~isCollection(p) then return collectionProperties~set(p,namespaceArg,nameArg,valueArg)
  o=self~objectAt(p); if o==.nil then return .false
  o~setEA(.StorageEA~new(namespaceArg,nameArg,valueArg,typeArg,'webdav-proppatch',authorityArg,'')); return .true
::method removeDeadProperty
  expose collectionProperties
  use arg pathArg, namespaceArg, nameArg
  p=.StoragePath~normalize(pathArg)
  if self~isCollection(p) then return collectionProperties~remove(p,namespaceArg,nameArg)
  o=self~objectAt(p); if o==.nil then return .false
  return o~eas~remove(namespaceArg~string||'.'||nameArg~string)
::method deadProperties
  expose collectionProperties
  use arg pathArg
  p=.StoragePath~normalize(pathArg); a=.array~new
  if self~isCollection(p) then return collectionProperties~all(p)
  o=self~objectAt(p); if o==.nil then return a
  do ea over o~eas~all
    if left(ea~namespace~lower,8)='storage.' then iterate
    a~append(.WebDavDeadProperty~new(ea~namespace,ea~name,ea~value))
  end
  return a
::method copyPath
  expose namespace collections collectionProperties locks
  use arg sourceArg, destinationArg, overwriteArg=.true, depthArg='infinity', ifHeader=''
  s=.StoragePath~normalize(sourceArg); d=.StoragePath~normalize(destinationArg)
  if \self~exists(s) then return .WebDavMutationResult~new(.false,404,'NOT_FOUND','source absent',.nil)
  if d='/' then return .WebDavMutationResult~new(.false,403,'ROOT_PROTECTED','destination root protected',.nil)
  if .WebDavUtil~startsWithPath(d,s) & self~isCollection(s) then return .WebDavMutationResult~new(.false,409,'DESCENDANT_DESTINATION','cannot copy collection into itself',.nil)
  if \self~isCollection(.StoragePath~parent(d)) then return .WebDavMutationResult~new(.false,409,'CONFLICT','destination parent absent',.nil)
  if \locks~mutationAllowed(d,ifHeader,'',self~etag(d)) then return .WebDavMutationResult~new(.false,423,'LOCKED','destination lock token required',.nil)
  existed=self~exists(d)
  if existed & \overwriteArg then return .WebDavMutationResult~new(.false,412,'OVERWRITE_FORBIDDEN','destination exists',.nil)
  if existed then do
    rr=self~removeTree(d,ifHeader)
    if \rr~ok then return rr
  end
  if self~isCollection(s) then do
    collections~add(d)
    if depthArg~string~lower<>'0' then do
      paths=self~walk(s)
      do i=2 to paths~items
        sp=paths[i]; suffix=sp~substr(length(s)+1); dp=.StoragePath~normalize(d||suffix)
        if self~isCollection(sp) then collections~add(dp)
        else do
          sr=namespace~resolve(sp); namespace~bind(dp,sr~entry~ref,sr~entry~writePolicy)
        end
      end
    end
    collectionProperties~moveTree(s,d,.true)
  end
  else do
    sr=namespace~resolve(s); namespace~bind(d,sr~entry~ref,sr~entry~writePolicy)
  end
  namespace~environment~advanceGeneration
  if existed then status=204; else status=201
  self~recordChange(d,status,'COPY')
  return .WebDavMutationResult~new(.true,status,'COPY','',.nil)
::method movePath
  expose namespace collectionProperties
  use arg sourceArg, destinationArg, overwriteArg=.true, ifHeader=''
  s=.StoragePath~normalize(sourceArg); d=.StoragePath~normalize(destinationArg)
  r=self~copyPath(s,d,overwriteArg,'infinity',ifHeader)
  if \r~ok then return r
  x=self~removeTree(s,ifHeader)
  if \x~ok then return x
  collectionProperties~moveTree(s,d,.false)
  namespace~environment~advanceGeneration
  self~recordChange(s,404,'MOVE_SOURCE')
  self~recordChange(d,r~status,'MOVE_DESTINATION')
  return .WebDavMutationResult~new(.true,r~status,'MOVE','',.nil)
::method removeTree private
  expose namespace collections
  use arg rootArg, ifHeader=''
  root=.StoragePath~normalize(rootArg)
  paths=self~walk(root); reverse=.array~new
  do p over paths; reverse~insert(p,1); end
  do p over reverse
    if self~isCollection(p) then do
      if p<>'/' then collections~remove(p)
    end
    else do
      rr=namespace~resolve(p)
      if rr~found then namespace~unlinkLocal(p)
    end
  end
  return .WebDavMutationResult~new(.true,204,'REMOVE_TREE','',.nil)
::method propertyMap
  expose locks
  use arg pathArg
  p=.StoragePath~normalize(pathArg); props=.directory~new
  props['displayname']=.StoragePath~name(p)
  props['supportedlock']='exclusive-write shared-write'
  props['lockdiscovery']=.WebDavXml~lockDiscoveryFragment(locks~applicable(p))
  if self~isCollection(p) then do
    props['resourcetype']='collection'; props['getcontentlength']='0'; props['getcontenttype']='httpd/unix-directory'; props['getetag']=''
    return props
  end
  o=self~objectAt(p); if o==.nil then return .nil
  props['resourcetype']=''; props['getcontentlength']=o~sizeBytes; props['getcontenttype']=o~mediaType; props['getetag']=self~etag(p); props['resource-id']='urn:storage:'||o~ref~objectId
  do ea over o~eas~all; props['ea:'||ea~namespace||':'||ea~name]=ea~value; end
  return props

::class WebDavMutationResult public
::attribute ok get
::attribute status get
::attribute code get
::attribute message get
::attribute ref get
::method init
  expose ok status code message ref
  use arg okArg, statusArg, codeArg='', messageArg='', refArg=.nil
  ok=(okArg==.true); status=statusArg+0; code=codeArg~string; message=messageArg~string; ref=refArg

::class WebDavPropertyPatch public
::attribute action get
::attribute namespace get
::attribute name get
::attribute value get
::method init
  expose action namespace name value
  use arg actionArg,namespaceArg,nameArg,valueArg=''
  action=actionArg~string~upper; namespace=namespaceArg~string; name=nameArg~string; value=valueArg~string

::class WebDavXml public
::method multistatus class
  use arg adapter, paths, requestedArg=.nil, namesOnly=.false
  xml='<?xml version="1.0" encoding="utf-8"?>'||'0A'x||'<D:multistatus xmlns:D="DAV:" xmlns:O="urn:oorexx:webdav:dead">'||'0A'x
  do p over paths
    props=adapter~propertyMap(p)
    if props==.nil then iterate
    xml=xml||'<D:response><D:href>'||.WebDavUtil~xmlEscape(.WebDavUtil~href(adapter~mountPath,p))||'</D:href><D:propstat><D:prop>'
    xml=xml||self~livePropertyXml(props,namesOnly)
    do dp over adapter~deadProperties(p)
      if namesOnly then xml=xml||'<O:'||self~safeName(dp~name)||'/>'
      else xml=xml||'<O:'||self~safeName(dp~name)||'>'||.WebDavUtil~xmlEscape(dp~value)||'</O:'||self~safeName(dp~name)||'>'
    end
    xml=xml||'</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>'||'0A'x
  end
  return xml||'</D:multistatus>'
::method livePropertyXml class private
  use arg props,namesOnly
  x=''
  if namesOnly then do
    x=x||'<D:resourcetype/><D:displayname/><D:getcontentlength/><D:getcontenttype/><D:getetag/><D:resource-id/><D:supportedlock/><D:lockdiscovery/>'
    return x
  end
  if props['resourcetype']='collection' then x=x||'<D:resourcetype><D:collection/></D:resourcetype>'
  else x=x||'<D:resourcetype/>'
  x=x||'<D:displayname>'||.WebDavUtil~xmlEscape(props['displayname'])||'</D:displayname>'
  x=x||'<D:getcontentlength>'||props['getcontentlength']||'</D:getcontentlength>'
  x=x||'<D:getcontenttype>'||.WebDavUtil~xmlEscape(props['getcontenttype'])||'</D:getcontenttype>'
  if props['getetag']<>'' then x=x||'<D:getetag>'||.WebDavUtil~xmlEscape(props['getetag'])||'</D:getetag>'
  if props['resource-id']<>.nil then x=x||'<D:resource-id><D:href>'||.WebDavUtil~xmlEscape(props['resource-id'])||'</D:href></D:resource-id>'
  x=x||'<D:supportedlock><D:lockentry><D:lockscope><D:exclusive/></D:lockscope><D:locktype><D:write/></D:locktype></D:lockentry><D:lockentry><D:lockscope><D:shared/></D:lockscope><D:locktype><D:write/></D:locktype></D:lockentry></D:supportedlock>'
  x=x||'<D:lockdiscovery>'||props['lockdiscovery']||'</D:lockdiscovery>'
  return x
::method lockDiscoveryFragment class
  use arg recordsArg
  x=''
  if recordsArg==.nil then return x
  do record over recordsArg
    if record~scope='shared' then scopeXml='<D:shared/>'
    else scopeXml='<D:exclusive/>'
    x=x||'<D:activelock><D:locktype><D:write/></D:locktype><D:lockscope>'||scopeXml||'</D:lockscope><D:depth>'||record~depth||'</D:depth><D:owner>'||.WebDavUtil~xmlEscape(record~owner)||'</D:owner><D:timeout>Second-'||record~timeoutSeconds||'</D:timeout><D:locktoken><D:href>'||record~token||'</D:href></D:locktoken></D:activelock>'
  end
  return x
::method lockDiscovery class
  use arg record
  if record==.nil then return ''
  a=.array~new; a~append(record)
  return '<?xml version="1.0" encoding="utf-8"?><D:prop xmlns:D="DAV:"><D:lockdiscovery>'||self~lockDiscoveryFragment(a)||'</D:lockdiscovery></D:prop>'
::method propPatchResponse class
  use arg adapter,path,patches
  href=.WebDavUtil~href(adapter~mountPath,path)
  xml='<?xml version="1.0" encoding="utf-8"?><D:multistatus xmlns:D="DAV:" xmlns:O="urn:oorexx:webdav:dead"><D:response><D:href>'||.WebDavUtil~xmlEscape(href)||'</D:href><D:propstat><D:prop>'
  do p over patches; xml=xml||'<O:'||self~safeName(p~name)||'/>'; end
  return xml||'</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response></D:multistatus>'
::method parsePropertyPatches class
  use arg bodyArg
  body=bodyArg~string; a=.array~new
  self~parsePatchAction(body,'set',a)
  self~parsePatchAction(body,'remove',a)
  return a
::method parsePatchAction class private
  use arg body,action,out
  low=body~lower; open='<'||action; close='</'||action||'>'
  /* Support D:set/D:remove as well as unprefixed forms. */
  p=low~pos('<d:'||action)
  if p=0 then p=low~pos(open)
  if p=0 then return
  q=low~pos('</d:'||action||'>',p)
  closeLen=length('</d:'||action||'>')
  if q=0 then do; q=low~pos(close,p); closeLen=length(close); end
  if q=0 then return
  segment=body~substr(p,q+closeLen-p)
  propStart=segment~lower~pos('<d:prop')
  if propStart=0 then propStart=segment~lower~pos('<prop')
  if propStart=0 then return
  gt=segment~pos('>',propStart); propEnd=segment~lower~pos('</d:prop>',gt)
  if propEnd=0 then propEnd=segment~lower~pos('</prop>',gt)
  if gt=0 | propEnd=0 then return
  inner=segment~substr(gt+1,propEnd-gt-1)
  pos=1
  do while pos<=inner~length
    lt=inner~pos('<',pos); if lt=0 then leave
    if inner~substr(lt+1,1)='/' then do; pos=lt+2; iterate; end
    gt=inner~pos('>',lt); if gt=0 then leave
    tag=inner~substr(lt+1,gt-lt-1)~strip
    if right(tag,1)='/' then do; tag=left(tag,length(tag)-1)~strip; self~appendPatch(action,tag,'',out); pos=gt+1; iterate; end
    space=tag~pos(' '); if space>0 then bare=tag~substr(1,space-1); else bare=tag
    colon=bare~pos(':'); if colon>0 then name=bare~substr(colon+1); else name=bare
    endtag='</'||bare||'>'
    ep=inner~lower~pos(endtag~lower,gt+1)
    if ep=0 then do; pos=gt+1; iterate; end
    value=.WebDavUtil~xmlUnescape(inner~substr(gt+1,ep-gt-1))
    self~appendPatch(action,tag,value,out)
    pos=ep+endtag~length
  end
::method appendPatch class private
  use arg action,tagArg,value,out
  tag=tagArg~string~strip
  space=tag~pos(' '); if space>0 then bare=tag~substr(1,space-1); else bare=tag
  colon=bare~pos(':'); if colon>0 then do; prefix=bare~substr(1,colon-1); name=bare~substr(colon+1); end
  else do; prefix=''; name=bare; end
  ns='urn:oorexx:webdav:dead'
  marker='xmlns:'||prefix||'='
  if prefix<>'' then do
    p=tag~lower~pos(marker~lower)
    if p>0 then do
      rest=tag~substr(p+marker~length)~strip
      quote=left(rest,1)
      if quote='"' | quote="'" then do
        rest=rest~substr(2); q=rest~pos(quote); if q>0 then ns=rest~substr(1,q-1)
      end
    end
  end
  out~append(.WebDavPropertyPatch~new(action,ns,name,value))
::method syncReport class
  use arg adapter,rootArg,resultArg
  root=.StoragePath~normalize(rootArg)
  xml='<?xml version="1.0" encoding="utf-8"?><D:multistatus xmlns:D="DAV:">'
  do c over resultArg~changes
    xml=xml||'<D:response><D:href>'||.WebDavUtil~xmlEscape(.WebDavUtil~href(adapter~mountPath,c~path))||'</D:href>'
    if c~status=404 then xml=xml||'<D:status>HTTP/1.1 404 Not Found</D:status>'
    else do
      props=adapter~propertyMap(c~path)
      if props==.nil then xml=xml||'<D:status>HTTP/1.1 404 Not Found</D:status>'
      else xml=xml||'<D:propstat><D:prop>'||self~livePropertyXml(props,.false)||'</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>'
    end
    xml=xml||'</D:response>'
  end
  xml=xml||'<D:sync-token>'||.WebDavUtil~xmlEscape(resultArg~token)||'</D:sync-token></D:multistatus>'
  return xml

::method safeName class private
  use arg nameArg
  s=nameArg~string
  do i=1 to s~length
    ch=s~substr(i,1)
    if \datatype(ch,'M') & \datatype(ch,'N') & ch<>'-' & ch<>'_' & ch<>'.' then s=s~changestr(ch,'_')
  end
  if s='' then s='property'
  return s

::requires 'WebDavState.cls'
::requires 'StorageFabric.cls'
::requires 'WebDavRepresentations.cls'
