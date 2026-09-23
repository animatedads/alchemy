/* HTTPS front-controller adapter for ooRexx WebDAV Gateway v0.1-dev1. */
::class WebDavHttpsAdapter public
::method init
  expose storage mountPath
  use arg storageArg, mountArg='/dav'
  storage=storageArg; mountPath=mountArg~string
  if storage==.nil then raise syntax 88.900 array('WebDavStorageAdapter is mandatory')
::method install
  use arg server
  server~interceptor(self,'beforeRequest','')
  return self
::method beforeRequest unguarded
  expose storage mountPath
  use arg request, context
  path=request~path
  if left(path,length(mountPath))<>mountPath then return .nil
  rest=substr(path,length(mountPath)+1)
  if rest='' then rest='/'
  if left(rest,1)<>'/' then return .nil
  method=request~method~upper
  select
    when method='OPTIONS' then return self~options
    when method='HEAD' then return self~getOrHead(request,rest,.true)
    when method='GET' then return self~getOrHead(request,rest,.false)
    when method='PROPFIND' then return self~propfind(request,rest)
    when method='PUT' then return self~put(request,rest)
    when method='DELETE' then return self~delete(request,rest)
    when method='MKCOL' then return self~mkcol(request,rest)
    otherwise return .HttpResponse~text('WebDAV method not implemented',405)~header('Allow','OPTIONS, HEAD, GET, PROPFIND, PUT, DELETE, MKCOL')
  end
::method options private
  r=.HttpResponse~empty(204)
  r~header('DAV','1, 2')
  r~header('Allow','OPTIONS, HEAD, GET, PROPFIND, PUT, DELETE, MKCOL')
  r~header('MS-Author-Via','DAV')
  return r
::method getOrHead private
  expose storage
  use arg request, path, headOnly
  if storage~isCollection(path) then return .HttpResponse~text('collection GET is not supported',405)
  bytes=storage~getBytes(path)
  if bytes==.nil then return .HttpResponse~text('Not Found',404)
  o=storage~objectAt(path)
  if headOnly then body=''; else body=bytes
  r=.HttpResponse~new(200,body,o~mediaType)
  r~header('Content-Length',o~sizeBytes)
  r~header('ETag',storage~etag(path))
  return r
::method propfind private
  expose storage
  use arg request, path
  if \storage~exists(path) & \storage~isCollection(path) then return .HttpResponse~text('Not Found',404)
  depth=request~header('Depth','infinity')~lower
  if depth<>'0' & depth<>'1' then return .HttpResponse~text('Only Depth 0 and 1 are supported',403)
  paths=.array~new; paths~append(.StoragePath~normalize(path))
  if depth='1' & storage~isCollection(path) then do p over storage~listChildren(path); paths~append(p); end
  xml=.WebDavXml~multistatus(storage,paths)
  return .HttpResponse~new(207,xml,'application/xml; charset=utf-8')
::method put private
  expose storage
  use arg request, path
  ct=request~header('Content-Type','application/octet-stream')
  result=storage~putBytes(path,request~body,ct,request~header('If-Match',''),request~header('If-None-Match',''))
  if \result~ok then return .HttpResponse~text(result~message,result~status)
  r=.HttpResponse~empty(result~status)
  if result~ref<>.nil then r~header('ETag',.WebDavUtil~quoteEtag(result~ref))
  return r
::method delete private
  expose storage
  use arg request, path
  result=storage~deletePath(path,request~header('If-Match',''))
  if \result~ok then return .HttpResponse~text(result~message,result~status)
  return .HttpResponse~empty(result~status)
::method mkcol private
  expose storage
  use arg request, path
  if request~body<>'' then return .HttpResponse~text('MKCOL body is not supported',415)
  result=storage~makeCollection(path)
  if \result~ok then return .HttpResponse~text(result~message,result~status)
  return .HttpResponse~empty(result~status)

::requires 'WebDavCore.cls'
::requires 'https_server.cls'
