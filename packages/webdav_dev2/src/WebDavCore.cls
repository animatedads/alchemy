/* ooRexx WebDAV Gateway v0.1-dev2 -- protocol/storage core. */

::class WebDavBuild public
::constant VERSION "0.1-dev2"
::constant API "webdav.gateway/0.1"

::class WebDavStatus public
::constant OK 200
::constant CREATED 201
::constant NO_CONTENT 204
::constant MULTI_STATUS 207
::constant BAD_REQUEST 400
::constant FORBIDDEN 403
::constant NOT_FOUND 404
::constant METHOD_NOT_ALLOWED 405
::constant CONFLICT 409
::constant PRECONDITION_FAILED 412
::constant LOCKED 423
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
::method parentExists class
  use arg namespace, path
  parent=.StoragePath~parent(path)
  if parent='/' then return .true
  if namespace~resolve(parent)~found then return .true
  return namespace~list(parent)~items>0

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
  bodies=.directory~new
  sequence=0
::method nextId
  expose sequence
  sequence+=1
  return 'webdav-'||sequence
::method put
  expose bodies
  use arg objectId, bytes
  bodies[objectId~string]=bytes~string
  return self
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
  /* Stable package-local content identity. Storage providers may replace this
   * with a cryptographic provider digest before durable commit. */
  s=bytes~string
  a=1; b=0
  do i=1 to length(s)
    a=(a+c2d(c2x(substr(s,i,1))))//65521
    b=(b+a)//65521
  end
  return 'adler32-'||b||'-'||a||'-'||length(s)

::class WebDavCollectionSet public
::method init
  expose rows
  rows=.directory~new
  rows['/']=.true
::method add
  expose rows
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  rows[p]=.true
  return p
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

::class WebDavStorageAdapter public
::attribute namespace get
::attribute catalogue get
::attribute collections get
::attribute representations get
::method init
  expose namespace catalogue content collections mountPath representations
  use arg namespaceArg, contentArg=.nil, collectionArg=.nil, mountArg='/dav', representationsArg=.nil
  if namespaceArg==.nil then raise syntax 88.900 array('WebDAV StorageNamespace is mandatory')
  namespace=namespaceArg; catalogue=namespace~catalogue
  if contentArg==.nil then content=.WebDavUnavailableContentStore~new; else content=contentArg
  if collectionArg==.nil then collections=.WebDavCollectionSet~new; else collections=collectionArg
  mountPath=mountArg~string
  if representationsArg==.nil then representations=.WebDavRepresentationRegistry~new; else representations=representationsArg
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
::method getRepresentation
  expose namespace content representations
  use arg pathArg, acceptArg=""
  r=namespace~resolve(pathArg)
  if \r~found then return .nil
  o=self~objectAt(pathArg)
  rr=representations~render(o,acceptArg)
  if rr<>.nil then return rr
  bytes=content~get(r~entry~ref~objectId)
  if bytes==.nil then return .nil
  return .WebDavRepresentationResult~new(bytes,o~mediaType)
::method getBytes
  use arg pathArg
  rr=self~getRepresentation(pathArg,"")
  if rr==.nil then return .nil
  return rr~body
::method putSequentialMedia
  expose namespace catalogue representations
  use arg pathArg, imageArg, canonicalTypeArg="application/vnd.oorexx.storage.sequential-media", ifMatch="", ifNoneMatch=""
  p=.StoragePath~normalize(pathArg)
  if imageArg==.nil then return .WebDavMutationResult~new(.false,400,'BAD_MEDIA','canonical media image is mandatory',.nil)
  old=namespace~resolve(p); existed=old~found
  if ifNoneMatch='*' & existed then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','resource already exists',.nil)
  if ifMatch<>'' then do
    if \existed then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','If-Match target absent',.nil)
    if .WebDavUtil~trimQuotes(ifMatch)<>.WebDavUtil~trimQuotes(.WebDavUtil~quoteEtag(old~entry~ref)) then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','ETag mismatch',.nil)
  end
  if \existed & \self~isCollection(.StoragePath~parent(p)) then return .WebDavMutationResult~new(.false,409,'CONFLICT','parent collection does not exist',.nil)
  digest=representations~canonicalDigest(imageArg)
  id='dav-media-'||digest
  ref=.StorageRef~new(id,digest)
  obj=.StorageObject~new(ref,.StoragePath~name(p),representations~canonicalSize(imageArg),canonicalTypeArg)
  representations~decorateStorageObject(obj,imageArg)
  catalogue~put(obj); representations~register(ref,imageArg)
  if existed then do
    e=old~entry; cs=.nil
    if e~writePolicy=.StorageWritePolicy~VERSIONED | e~writePolicy=.StorageWritePolicy~COPY_ON_WRITE | e~writePolicy=.StorageWritePolicy~TRACKED | e~writePolicy=.StorageWritePolicy~EPHEMERAL then cs=.StorageChangeSet~new('dav-media-'||digest,namespace~environment~environmentId,namespace~environment~generation)
    d=namespace~applyWrite(p,ref,cs)
    if \d~allowed then return .WebDavMutationResult~new(.false,403,'WRITE_DENIED',d~message,.nil)
  end
  else do
    policy=namespace~environment~defaultWritePolicy
    if policy=.StorageWritePolicy~READ_ONLY then return .WebDavMutationResult~new(.false,403,'WRITE_DENIED','namespace default is read-only',.nil)
    namespace~bind(p,ref,policy)
  end
  namespace~environment~advanceGeneration
  if existed then status=204; else status=201
  return .WebDavMutationResult~new(.true,status,'PUT_MEDIA','',ref)
::method setDeadProperty
  use arg pathArg, namespaceArg, nameArg, valueArg, typeArg="STRING", authorityArg="webdav"
  o=self~objectAt(pathArg)
  if o==.nil then return .false
  o~setEA(.StorageEA~new(namespaceArg,nameArg,valueArg,typeArg,'webdav-proppatch',authorityArg,''))
  return .true
::method putBytes
  expose namespace catalogue content
  use arg pathArg, bytesArg, mediaType='application/octet-stream', ifMatch='', ifNoneMatch=''
  p=.StoragePath~normalize(pathArg); bytes=bytesArg~string
  old=namespace~resolve(p); existed=old~found
  if ifNoneMatch='*' & existed then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','resource already exists',.nil)
  if ifMatch<>'' then do
    if \existed then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','If-Match target absent',.nil)
    if .WebDavUtil~trimQuotes(ifMatch)<>.WebDavUtil~trimQuotes(.WebDavUtil~quoteEtag(old~entry~ref)) then return .WebDavMutationResult~new(.false,412,'PRECONDITION_FAILED','ETag mismatch',.nil)
  end
  if \existed & \self~isCollection(.StoragePath~parent(p)) then return .WebDavMutationResult~new(.false,409,'CONFLICT','parent collection does not exist',.nil)
  id=content~nextId; digest=content~digest(bytes)
  ref=.StorageRef~new(id,digest)
  obj=.StorageObject~new(ref,.StoragePath~name(p),length(bytes),mediaType)
  catalogue~put(obj); content~put(id,bytes)
  if existed then do
    /* Preserve the route's authoritative write policy. DIRECT can commit
     * immediately. VERSIONED requires evidence, so create a one-mutation set. */
    e=old~entry
    cs=.nil
    if e~writePolicy=.StorageWritePolicy~VERSIONED | e~writePolicy=.StorageWritePolicy~COPY_ON_WRITE | e~writePolicy=.StorageWritePolicy~TRACKED | e~writePolicy=.StorageWritePolicy~EPHEMERAL then cs=.StorageChangeSet~new('dav-'||id,namespace~environment~environmentId,namespace~environment~generation)
    d=namespace~applyWrite(p,ref,cs)
    if \d~allowed then return .WebDavMutationResult~new(.false,403,'WRITE_DENIED',d~message,.nil)
  end
  else do
    policy=namespace~environment~defaultWritePolicy
    if policy=.StorageWritePolicy~READ_ONLY then return .WebDavMutationResult~new(.false,403,'WRITE_DENIED','namespace default is read-only',.nil)
    namespace~bind(p,ref,policy)
  end
  namespace~environment~advanceGeneration
  if existed then status=204; else status=201
  return .WebDavMutationResult~new(.true,status,'PUT','',ref)
::method deletePath
  expose namespace collections
  use arg pathArg, ifMatch=''
  p=.StoragePath~normalize(pathArg)
  if collections~has(p) then do
    if namespace~list(p)~items>0 | collections~children(p)~items>0 then return .WebDavMutationResult~new(.false,409,'COLLECTION_NOT_EMPTY','collection is not empty',.nil)
    if p='/' then return .WebDavMutationResult~new(.false,403,'ROOT_PROTECTED','root collection cannot be deleted',.nil)
    collections~remove(p); namespace~environment~advanceGeneration
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
  return .WebDavMutationResult~new(.true,204,'DELETE','',.nil)
::method makeCollection
  expose namespace collections
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  if self~exists(p) then return .WebDavMutationResult~new(.false,405,'ALREADY_EXISTS','resource already exists',.nil)
  parent=.StoragePath~parent(p)
  if \collections~has(parent) & parent<>'/' & namespace~list(parent)~items=0 then return .WebDavMutationResult~new(.false,409,'CONFLICT','parent collection absent',.nil)
  collections~add(p); namespace~environment~advanceGeneration
  return .WebDavMutationResult~new(.true,201,'MKCOL','',.nil)
::method listChildren
  expose namespace collections
  use arg pathArg
  p=.StoragePath~normalize(pathArg); a=.array~new
  seen=.directory~new
  do e over namespace~list(p)
    if \seen~hasIndex(e~path) then do; a~append(e~path); seen[e~path]=.true; end
  end
  do c over collections~children(p)
    if \seen~hasIndex(c) then do; a~append(c); seen[c]=.true; end
  end
  return a
::method propertyMap
  expose namespace
  use arg pathArg
  p=.StoragePath~normalize(pathArg); props=.directory~new
  props['displayname']=.StoragePath~name(p)
  if self~isCollection(p) then do
    props['resourcetype']='collection'; props['getcontentlength']='0'; props['getcontenttype']='httpd/unix-directory'; props['getetag']=''
    return props
  end
  o=self~objectAt(p)
  if o==.nil then return .nil
  props['resourcetype']=''; props['getcontentlength']=o~sizeBytes; props['getcontenttype']=o~mediaType; props['getetag']=self~etag(p); props['resource-id']='urn:storage:'||o~ref~objectId
  do ea over o~eas~all
    props['ea:'||ea~namespace||':'||ea~name]=ea~value
  end
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

::class WebDavXml public
::method multistatus class
  use arg adapter, paths
  xml='<?xml version="1.0" encoding="utf-8"?>'||'0A'x||'<D:multistatus xmlns:D="DAV:">'||'0A'x
  do p over paths
    props=adapter~propertyMap(p)
    if props==.nil then iterate
    xml=xml||'<D:response><D:href>'||.WebDavUtil~xmlEscape(.WebDavUtil~href(adapter~mountPath,p))||'</D:href><D:propstat><D:prop>'
    if props['resourcetype']='collection' then xml=xml||'<D:resourcetype><D:collection/></D:resourcetype>'
    else xml=xml||'<D:resourcetype/>'
    xml=xml||'<D:displayname>'||.WebDavUtil~xmlEscape(props['displayname'])||'</D:displayname>'
    xml=xml||'<D:getcontentlength>'||props['getcontentlength']||'</D:getcontentlength>'
    xml=xml||'<D:getcontenttype>'||.WebDavUtil~xmlEscape(props['getcontenttype'])||'</D:getcontenttype>'
    if props['getetag']<>'' then xml=xml||'<D:getetag>'||.WebDavUtil~xmlEscape(props['getetag'])||'</D:getetag>'
    if props['resource-id']<>.nil then xml=xml||'<D:resource-id><D:href>'||.WebDavUtil~xmlEscape(props['resource-id'])||'</D:href></D:resource-id>'
    xml=xml||'</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>'||'0A'x
  end
  return xml||'</D:multistatus>'

::requires 'StorageFabric.cls'
::requires 'WebDavRepresentations.cls'
