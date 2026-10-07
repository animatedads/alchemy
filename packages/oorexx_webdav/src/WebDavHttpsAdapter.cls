/* HTTPS front-controller adapter for ooRexx WebDAV Gateway v0.1-dev3. */
::class WebDavHttpsAdapter public
::method init
  expose storage mountPath
  use arg storageArg, mountArg='/dav'
  storage=storageArg; mountPath=mountArg~string
  if storage==.nil then raise syntax 88.900 array('WebDavStorageAdapter is mandatory')
::method install
  use arg server
  server~interceptor(self,'beforeRequest',''); return self
::method beforeRequest unguarded
  expose storage mountPath
  use arg request, context
  path=request~path
  if left(path,length(mountPath))<>mountPath then return .nil
  rest=substr(path,length(mountPath)+1); if rest='' then rest='/'
  if left(rest,1)<>'/' then return .nil
  method=request~method~upper
  select
    when method='OPTIONS' then return self~options
    when method='HEAD' then return self~getOrHead(request,rest,.true)
    when method='GET' then return self~getOrHead(request,rest,.false)
    when method='PROPFIND' then return self~propfind(request,rest)
    when method='PROPPATCH' then return self~proppatch(request,rest)
    when method='REPORT' then return self~report(request,rest)
    when method='PUT' then return self~put(request,rest)
    when method='DELETE' then return self~delete(request,rest)
    when method='MKCOL' then return self~mkcol(request,rest)
    when method='COPY' then return self~copy(request,rest)
    when method='MOVE' then return self~move(request,rest)
    when method='LOCK' then return self~lock(request,rest)
    when method='UNLOCK' then return self~unlock(request,rest)
    otherwise return .HttpResponse~text('WebDAV method not implemented',405)~header('Allow',self~allow)
  end
::method allow private
  return 'OPTIONS, HEAD, GET, PROPFIND, PROPPATCH, REPORT, PUT, DELETE, MKCOL, COPY, MOVE, LOCK, UNLOCK'
::method options private
  r=.HttpResponse~empty(204)
  r~header('DAV','1, 2, sync-collection')
  r~header('Allow',self~allow)
  r~header('MS-Author-Via','DAV'); return r
::method getOrHead private
  expose storage
  use arg request, path, headOnly
  if storage~isCollection(path) then return .HttpResponse~text('collection GET is not supported',405)

  rr=storage~getRepresentation(path,request~header('Accept',''))
  streaming=.false
  if rr==.nil then do
    if \storage~exists(path) then return .HttpResponse~text('Not Found',404)
    o=storage~objectAt(path)
    resolved=storage~namespace~resolve(path)
    if o<>.nil & resolved~found & storage~byteSources~has(resolved~entry~ref) then do
      streaming=.true; total=o~sizeBytes; contentType=o~mediaType; body=''
    end
    else return .HttpResponse~text('No acceptable representation',406)
  end
  else do
    total=rr~length; contentType=rr~contentType; body=rr~body
  end

  status=200; start=0; finish=total-1
  range=request~header('Range','')
  if range<>'' & self~ifRangeMatches(request,path) then do
    spec=self~parseRange(range,total)
    if spec==.nil then do
      r=.HttpResponse~empty(416); r~header('Content-Range','bytes */'||total); return r
    end
    start=spec[1]; finish=spec[2]
    if finish-start+1>8388608 then return .HttpResponse~text('requested DAV range exceeds bounded response limit',507)
    ranged=storage~readRange(path,start,finish-start+1,8388608)
    if ranged<>.nil then body=ranged
    else if rr<>.nil then body=body~substr(start+1,finish-start+1)
    else return .HttpResponse~text('Storage byte source unavailable',500)
    status=206
  end
  else if streaming & \headOnly then
    return .HttpResponse~text('full streaming GET requires HTTPS streaming response support; use Range',501)

  if headOnly then body=''
  r=.HttpResponse~new(status,body,contentType)
  if status=206 then do
    r~header('Content-Length',finish-start+1)
    r~header('Content-Range','bytes '||start||'-'||finish||'/'||total)
  end
  else r~header('Content-Length',total)
  r~header('Accept-Ranges','bytes')
  r~header('ETag',storage~etag(path)); return r

::method ifRangeMatches private
  expose storage
  use arg request,path
  ir=request~header('If-Range','')
  if ir='' then return .true
  return .WebDavUtil~trimQuotes(ir)=.WebDavUtil~trimQuotes(storage~etag(path))
::method parseRange private
  use arg headerArg,sizeArg
  h=headerArg~string~strip~lower; size=sizeArg+0
  if left(h,6)<>'bytes=' then return .nil
  s=h~substr(7)
  if s~pos(',')>0 then return .nil
  dash=s~pos('-'); if dash=0 then return .nil
  a=s~substr(1,dash-1)~strip; b=s~substr(dash+1)~strip
  if a='' then do
    if \datatype(b,'W') then return .nil
    n=b+0; if n<=0 then return .nil
    if n>size then n=size
    first=size-n; last=size-1
  end
  else do
    if \datatype(a,'W') then return .nil
    first=a+0; if first>=size then return .nil
    if b='' then last=size-1
    else do
      if \datatype(b,'W') then return .nil
      last=b+0; if last<first then return .nil
      if last>=size then last=size-1
    end
  end
  out=.array~new; out~append(first); out~append(last); return out
::method propfind private
  expose storage
  use arg request, path
  if \storage~exists(path) & \storage~isCollection(path) then return .HttpResponse~text('Not Found',404)
  depth=request~header('Depth','infinity')~lower
  if depth<>'0' & depth<>'1' & depth<>'infinity' then return .HttpResponse~text('Invalid Depth',400)
  paths=.array~new
  if depth='0' then paths~append(.StoragePath~normalize(path))
  else if depth='1' then do
    paths~append(.StoragePath~normalize(path))
    if storage~isCollection(path) then do p over storage~listChildren(path); paths~append(p); end
  end
  else paths=storage~walk(path,4096)
  namesOnly=(request~body~lower~pos('propname')>0)
  xml=.WebDavXml~multistatus(storage,paths,.nil,namesOnly)
  return .HttpResponse~new(207,xml,'application/xml; charset=utf-8')
::method proppatch private
  expose storage
  use arg request,path
  if \storage~exists(path) then return .HttpResponse~text('Not Found',404)
  if \storage~locks~mutationAllowed(path,request~header('If',''),'') then return .HttpResponse~text('Locked',423)
  patches=.WebDavXml~parsePropertyPatches(request~body)
  if patches~items=0 then return .HttpResponse~text('No property updates found',400)
  do p over patches
    if p~namespace='DAV:' then return .HttpResponse~text('DAV live properties are protected',403)
  end
  do p over patches
    if p~action='SET' then ok=storage~setDeadProperty(path,p~namespace,p~name,p~value)
    else ok=storage~removeDeadProperty(path,p~namespace,p~name)
    if \ok & p~action='SET' then return .HttpResponse~text('Property update failed',409)
  end
  storage~namespace~environment~advanceGeneration
  storage~recordChange(path,200,'PROPPATCH')
  return .HttpResponse~new(207,.WebDavXml~propPatchResponse(storage,path,patches),'application/xml; charset=utf-8')
::method report private
  expose storage
  use arg request,path
  if \storage~isCollection(path) then return .HttpResponse~text('sync-collection REPORT requires a collection',409)
  body=request~body~string
  if body~lower~pos('sync-collection')=0 then return .HttpResponse~text('unsupported REPORT body',400)
  token=.WebDavText~between(body,'<D:sync-token>','</D:sync-token>')
  if token='' then token=.WebDavText~between(body,'<sync-token>','</sync-token>')
  if token='' & body~lower~pos('<d:sync-token/>')=0 & body~lower~pos('<sync-token/>')=0 then token=''
  if token='' then do
    /* Initial sync enumerates current state and returns the journal token. */
    changes=.array~new
    seq=0
    do p over storage~walk(path,4096)
      seq+=1; changes~append(.WebDavSyncChange~new(seq,p,200,'INITIAL',storage~namespace~environment~generation))
    end
    outcome=.WebDavSyncResult~new(.true,'OK',storage~syncToken,changes)
  end
  else outcome=storage~syncChanges(token,path,4096)
  if \outcome~ok then do
    if outcome~code='TOKEN_EXPIRED' then return .HttpResponse~text('sync token expired',410)
    return .HttpResponse~text('invalid sync token',400)
  end
  xml=.WebDavXml~syncReport(storage,path,outcome)
  return .HttpResponse~new(207,xml,'application/xml; charset=utf-8')

::method put private
  expose storage
  use arg request, path
  ct=request~header('Content-Type','application/octet-stream')
  image=storage~representations~import('dav-upload',request~body,ct)
  if image<>.nil then outcome=storage~putSequentialMedia(path,image,'application/vnd.oorexx.storage.sequential-media',request~header('If-Match',''),request~header('If-None-Match',''),request~header('If',''))
  else outcome=storage~putBytes(path,request~body,ct,request~header('If-Match',''),request~header('If-None-Match',''),request~header('If',''))
  return self~mutationResponse(outcome)
::method delete private
  expose storage
  use arg request, path
  outcome=storage~deletePath(path,request~header('If-Match',''),request~header('If',''))
  return self~mutationResponse(outcome)
::method mkcol private
  expose storage
  use arg request, path
  if request~body<>'' then return .HttpResponse~text('MKCOL body is not supported',415)
  outcome=storage~makeCollection(path,request~header('If',''))
  return self~mutationResponse(outcome)
::method copy private
  expose storage mountPath
  use arg request,path
  d=.WebDavUtil~destinationPath(request~header('Destination',''),mountPath)
  if d='' then return .HttpResponse~text('Destination required',400)
  ow=request~header('Overwrite','T')~upper<>'F'
  outcome=storage~copyPath(path,d,ow,request~header('Depth','infinity'),request~header('If',''))
  return self~mutationResponse(outcome)
::method move private
  expose storage mountPath
  use arg request,path
  d=.WebDavUtil~destinationPath(request~header('Destination',''),mountPath)
  if d='' then return .HttpResponse~text('Destination required',400)
  ow=request~header('Overwrite','T')~upper<>'F'
  outcome=storage~movePath(path,d,ow,request~header('If',''))
  return self~mutationResponse(outcome)
::method lock private
  expose storage
  use arg request,path
  if \storage~exists(path) then return .HttpResponse~text('Not Found',404)
  depth=request~header('Depth','infinity')~lower
  if depth<>'0' & depth<>'infinity' then return .HttpResponse~text('Invalid Depth',400)
  timeout=self~timeoutSeconds(request~header('Timeout','Second-3600'))
  refresh=''
  if request~body='' then refresh=self~tokenFromIf(request~header('If',''))
  owner=self~ownerFromBody(request~body)
  scope=self~lockScopeFromBody(request~body)
  rec=storage~locks~lock(path,depth,owner,timeout,refresh,scope)
  if rec==.nil then return .HttpResponse~text('Locked',423)
  r=.HttpResponse~new(200,.WebDavXml~lockDiscovery(rec),'application/xml; charset=utf-8')
  r~header('Lock-Token','<'||rec~token||'>'); return r
::method unlock private
  expose storage
  use arg request,path
  token=request~header('Lock-Token','')~strip
  if left(token,1)='<' & right(token,1)='>' then token=token~substr(2,token~length-2)
  if token='' then return .HttpResponse~text('Lock-Token required',400)
  if \storage~locks~unlock(path,token) then return .HttpResponse~text('Lock token not found',409)
  return .HttpResponse~empty(204)
::method lockScopeFromBody private
  use arg bodyArg
  b=bodyArg~string~lower
  if b~pos('<d:shared')>0 | b~pos('<shared')>0 then return 'shared'
  return 'exclusive'

::method timeoutSeconds private
  use arg valueArg
  v=valueArg~string~strip
  if v~lower='infinite' then return 86400
  p=v~lower~pos('second-')
  if p=1 then do; n=v~substr(8); if datatype(n,'W') then do; n=n+0; if n<1 then return 1; if n>86400 then return 86400; return n; end; end
  return 3600
::method tokenFromIf private
  use arg valueArg
  v=valueArg~string; p=v~pos('opaquelocktoken:')
  if p=0 then return ''
  q=v~pos('>',p); if q=0 then q=v~pos(')',p); if q=0 then return v~substr(p)
  return v~substr(p,q-p)
::method ownerFromBody private
  use arg bodyArg
  b=bodyArg~string
  x=.WebDavText~between(b,'<D:owner>','</D:owner>')
  if x='' then x=.WebDavText~between(b,'<owner>','</owner>')
  return x
::method mutationResponse private
  use arg outcome
  if \outcome~ok then return .HttpResponse~text(outcome~message,outcome~status)
  r=.HttpResponse~empty(outcome~status)
  if outcome~ref<>.nil then r~header('ETag',.WebDavUtil~quoteEtag(outcome~ref))
  return r

::requires 'WebDavCore.cls'
::requires 'https_server.cls'
